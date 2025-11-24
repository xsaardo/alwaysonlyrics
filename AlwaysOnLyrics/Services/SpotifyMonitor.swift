import Foundation
import Combine
import AppKit
import CoreServices

class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: Track?
    @Published var spotifyRunning: Bool = false
    @Published var playbackPosition: Double = 0.0

    private var positionTimer: Timer?  // High-frequency local timer
    private var syncTimer: Timer?      // Periodic sync timer (every 3 seconds)
    private var lastSyncedPosition: Double = 0.0
    private var lastSyncTime: Date?

    init() {
        // No initialization needed
    }

    func startMonitoring() {
        // Query initial state using AppleScript (one-time on startup)
        checkInitialSpotifyState()

        // Listen for Spotify playback state changes (event-driven, no polling!)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    func stopMonitoring() {
        // Remove notification observer
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func checkInitialSpotifyState() {
        // Use AppleScript only once on startup to get current state
        guard let trackInfo = getSpotifyTrackInfoViaAppleScript() else {
            DispatchQueue.main.async {
                self.spotifyRunning = false
                self.currentTrack = nil
            }
            return
        }

        DispatchQueue.main.async {
            self.spotifyRunning = true
            self.currentTrack = trackInfo
        }
    }

    @objc private func handleSpotifyNotification(_ notification: Notification) {
        // Parse Spotify notification userInfo
        guard let userInfo = notification.userInfo as? [String: Any] else {
            return
        }

        // Extract track information from notification
        guard let trackName = userInfo["Name"] as? String,
              let playerStateString = userInfo["Player State"] as? String else {
            // Notification doesn't contain track info - could be a transition state
            // Don't mark Spotify as not running, just ignore this notification
            return
        }

        // Artist name is optional (podcasts/audiobooks may not have one)
        let artistName = userInfo["Artist"] as? String ?? ""

        // Extract additional info from notification
        let albumName = userInfo["Album"] as? String ?? "Unknown Album"
        let isPlaying = (playerStateString == "Playing")

        // Extract duration from notification (in milliseconds) and convert to seconds
        let durationSeconds: Int? = {
            if let durationMs = userInfo["Duration"] as? Int {
                return Int(Double(durationMs) / 1000.0)
            }
            return nil
        }()

        // Fetch artwork URL via AppleScript in background
        // (Artwork URL is never in the notification, but everything else is)
        DispatchQueue.global(qos: .userInitiated).async {
            let artworkURL = self.getArtworkURL()

            let trackInfo = Track(
                title: trackName,
                artist: artistName,
                album: albumName,
                duration: durationSeconds,
                artworkURL: artworkURL,
                isPlaying: isPlaying,
                playbackPosition: nil  // Will be populated by position tracking
            )

            DispatchQueue.main.async {
                self.spotifyRunning = true
                if self.currentTrack != trackInfo {
                    self.currentTrack = trackInfo
                }

                // Start or stop position tracking based on play state
                if isPlaying {
                    self.startPositionTracking()
                } else {
                    self.stopPositionTracking()
                }
            }
        }
    }

    /// Fetch artwork URL via AppleScript (only thing not in notification)
    private func getArtworkURL() -> String? {
        let script = """
        tell application "Spotify"
            if it is running then
                try
                    return artwork url of current track
                on error errMsg
                    return errMsg
                end try
            else
                return ""
            end if
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            return nil
        }

        guard let output = result.stringValue, !output.isEmpty else {
            return nil
        }

        return output
    }

    /// Get complete track info via AppleScript (used only for initial state on startup)
    private func getSpotifyTrackInfoViaAppleScript() -> Track? {
        let script = """
        tell application "Spotify"
            if it is running then
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set trackDuration to duration of current track
                    set artworkURL to artwork url of current track
                    set isPlaying to player state is playing

                    return trackName & "|" & artistName & "|" & albumName & "|" & trackDuration & "|" & artworkURL & "|" & isPlaying
                on error errMsg
                    return "ERROR:" & errMsg
                end try
            else
                return "NOT_RUNNING"
            end if
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            return nil
        }

        guard let output = result.stringValue else {
            return nil
        }

        if output.isEmpty {
            return nil
        }

        if output == "NOT_RUNNING" {
            return nil
        }

        if output.hasPrefix("ERROR:") {
            return nil
        }

        let components = output.components(separatedBy: "|")
        guard components.count == 6 else {
            return nil
        }

        let title = components[0]
        let artist = components[1]
        let album = components[2]

        // Duration is in milliseconds from Spotify, convert to seconds for LRCLIB
        let durationSeconds: Int? = {
            if let durationMs = Int(components[3]) {
                return Int(Double(durationMs) / 1000.0)
            }
            return nil
        }()

        let artworkURL = components[4].isEmpty ? nil : components[4]
        let isPlaying = components[5] == "true"

        return Track(title: title, artist: artist, album: album, duration: durationSeconds, artworkURL: artworkURL, isPlaying: isPlaying, playbackPosition: nil)
    }

    // MARK: - Playback Position Tracking

    /// Start tracking playback position with hybrid timer approach
    func startPositionTracking() {
        stopPositionTracking()  // Clean up existing timers

        // Sync immediately to get accurate starting position
        Task {
            await syncPlaybackPosition()
        }

        // Start local timer for smooth updates (15 Hz = every ~67ms)
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.067, repeats: true) { [weak self] _ in
            self?.updateLocalPosition()
        }

        // Start sync timer (every 3 seconds)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task {
                await self?.syncPlaybackPosition()
            }
        }
    }

    /// Stop tracking playback position
    func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil

        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Update local position estimate (called by high-frequency timer)
    @objc private func updateLocalPosition() {
        guard let lastSyncTime = lastSyncTime,
              currentTrack?.isPlaying == true else {
            return
        }

        // Calculate elapsed time since last sync
        let elapsed = Date().timeIntervalSince(lastSyncTime)

        // Estimate current position
        let estimatedPosition = lastSyncedPosition + elapsed

        DispatchQueue.main.async {
            self.playbackPosition = estimatedPosition
        }
    }

    /// Sync playback position with Spotify via AppleScript
    func syncPlaybackPosition() async {
        guard let position = getSpotifyPlaybackPosition() else {
            return
        }

        DispatchQueue.main.async {
            self.lastSyncedPosition = position
            self.lastSyncTime = Date()
            self.playbackPosition = position
        }
    }

    /// Get current playback position from Spotify via AppleScript
    private func getSpotifyPlaybackPosition() -> Double? {
        let script = """
        tell application "Spotify"
            if it is running then
                try
                    set pos to player position
                    return pos
                on error errMsg
                    return ""
                end try
            else
                return ""
            end if
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            return nil
        }

        // Check for error (empty string returned from AppleScript)
        if let stringValue = result.stringValue, stringValue.isEmpty {
            return nil
        }

        return result.doubleValue
    }

    deinit {
        stopMonitoring()
        stopPositionTracking()
    }
}


import Foundation
import Combine
import AppKit
import CoreServices

class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: Track?
    @Published var spotifyRunning: Bool = false

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
              let artistName = userInfo["Artist"] as? String,
              let playerStateString = userInfo["Player State"] as? String else {
            // Notification doesn't contain track info, Spotify might have stopped
            DispatchQueue.main.async {
                self.spotifyRunning = false
                self.currentTrack = nil
            }
            return
        }

        let isPlaying = (playerStateString == "Playing")
        let trackInfo = Track(title: trackName, artist: artistName, isPlaying: isPlaying)

        DispatchQueue.main.async {
            self.spotifyRunning = true

            // Only update if track changed
            if self.currentTrack != trackInfo {
                self.currentTrack = trackInfo
            }
        }
    }

    private func getSpotifyTrackInfoViaAppleScript() -> Track? {
        // AppleScript to get current Spotify track info (used only for initial state)
        // No System Events check needed - just try to talk to Spotify directly
        let script = """
        tell application "Spotify"
            if it is running then
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set isPlaying to player state is playing

                    return trackName & "|" & artistName & "|" & isPlaying
                on error errMsg
                    return "ERROR:" & errMsg
                end try
            else
                return "NOT_RUNNING"
            end if
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            print("DEBUG: Failed to create NSAppleScript")
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            print("DEBUG: AppleScript error: \(error)")
            return nil
        }

        guard let output = result.stringValue else {
            print("DEBUG: No string value in result")
            return nil
        }

        print("DEBUG: AppleScript returned: '\(output)'")

        if output.isEmpty {
            print("DEBUG: Empty result")
            return nil
        }

        if output == "NOT_RUNNING" {
            print("DEBUG: Spotify not running")
            return nil
        }

        if output.hasPrefix("ERROR:") {
            print("DEBUG: AppleScript error: \(output)")
            return nil
        }

        let components = output.components(separatedBy: "|")
        guard components.count == 3 else {
            print("DEBUG: Unexpected component count: \(components.count), components: \(components)")
            return nil
        }

        let title = components[0]
        let artist = components[1]
        let isPlaying = components[2] == "true"

        print("DEBUG: Parsed track - title: '\(title)', artist: '\(artist)', isPlaying: \(isPlaying)")

        return Track(title: title, artist: artist, isPlaying: isPlaying)
    }

    deinit {
        stopMonitoring()
    }
}

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

        // Debug: Print available keys to see what Spotify actually sends
        print("DEBUG: Spotify notification keys:", userInfo.keys)

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

        // Extract album and artwork (may not always be present in notifications)
        let albumName = userInfo["Album"] as? String ?? "Unknown Album"
        let artworkURL = userInfo["Artwork URL"] as? String

        print("DEBUG: Album from notification:", albumName)
        print("DEBUG: Artwork URL from notification:", artworkURL ?? "nil")

        let isPlaying = (playerStateString == "Playing")

        // If artwork URL not in notification, fetch it via AppleScript
        if artworkURL == nil {
            // Fetch full track info via AppleScript in background
            DispatchQueue.global(qos: .userInitiated).async {
                if let fullTrackInfo = self.getSpotifyTrackInfoViaAppleScript() {
                    DispatchQueue.main.async {
                        self.spotifyRunning = true
                        if self.currentTrack != fullTrackInfo {
                            self.currentTrack = fullTrackInfo
                        }
                    }
                } else {
                    // Fallback: use notification data without artwork
                    let trackInfo = Track(title: trackName, artist: artistName, album: albumName, artworkURL: nil, isPlaying: isPlaying)
                    DispatchQueue.main.async {
                        self.spotifyRunning = true
                        if self.currentTrack != trackInfo {
                            self.currentTrack = trackInfo
                        }
                    }
                }
            }
        } else {
            // We have artwork URL from notification
            let trackInfo = Track(title: trackName, artist: artistName, album: albumName, artworkURL: artworkURL, isPlaying: isPlaying)
            DispatchQueue.main.async {
                self.spotifyRunning = true
                if self.currentTrack != trackInfo {
                    self.currentTrack = trackInfo
                }
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
                    set albumName to album of current track
                    set artworkURL to artwork url of current track
                    set isPlaying to player state is playing

                    return trackName & "|" & artistName & "|" & albumName & "|" & artworkURL & "|" & isPlaying
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
        guard components.count == 5 else {
            return nil
        }

        let title = components[0]
        let artist = components[1]
        let album = components[2]
        let artworkURL = components[3].isEmpty ? nil : components[3]
        let isPlaying = components[4] == "true"

        return Track(title: title, artist: artist, album: album, artworkURL: artworkURL, isPlaying: isPlaying)
    }

    deinit {
        stopMonitoring()
    }
}

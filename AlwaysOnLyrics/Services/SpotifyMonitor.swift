import Foundation
import Combine

class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: Track?
    @Published var spotifyRunning: Bool = false

    private var timer: Timer?
    private let pollingInterval: TimeInterval

    init(pollingInterval: TimeInterval = Config.spotifyPollingInterval) {
        self.pollingInterval = pollingInterval
    }

    func startMonitoring() {
        // Initial check
        checkSpotify()

        // Start polling
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.checkSpotify()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkSpotify() {
        guard let trackInfo = getSpotifyTrackInfo() else {
            DispatchQueue.main.async {
                self.spotifyRunning = false
                self.currentTrack = nil
            }
            return
        }

        DispatchQueue.main.async {
            self.spotifyRunning = true

            // Only update if track changed
            if self.currentTrack != trackInfo {
                self.currentTrack = trackInfo
            }
        }
    }

    private func getSpotifyTrackInfo() -> Track? {
        let script = """
        tell application "System Events"
            set isRunning to (name of processes) contains "Spotify"
        end tell

        if isRunning then
            tell application "Spotify"
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set isPlaying to player state is playing
                    return trackName & "|" & artistName & "|" & isPlaying
                on error
                    return ""
                end try
            end tell
        else
            return ""
        end if
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            print("AppleScript error: \(error)")
            return nil
        }

        guard let output = result.stringValue, !output.isEmpty else {
            return nil
        }

        let components = output.components(separatedBy: "|")
        guard components.count == 3 else {
            return nil
        }

        let title = components[0]
        let artist = components[1]
        let isPlaying = components[2] == "true"

        return Track(title: title, artist: artist, isPlaying: isPlaying)
    }

    deinit {
        stopMonitoring()
    }
}

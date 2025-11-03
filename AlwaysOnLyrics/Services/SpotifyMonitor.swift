import Foundation
import Combine
import AppKit
import CoreServices

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
        // Use the helper script from Application Scripts directory
        // This bypasses the permission issues with NSAppleScript
        let scriptURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Scripts")
            .appendingPathComponent("com.xsaardo.AlwaysOnLyrics")
            .appendingPathComponent("GetSpotifyTrack.scpt")

        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            return nil
        }

        // Use NSUserAppleScriptTask for sandboxed execution
        guard let scriptTask = try? NSUserAppleScriptTask(url: scriptURL) else {
            return nil
        }

        // Create a semaphore to wait for async result
        let semaphore = DispatchSemaphore(value: 0)
        var resultString: String?
        var executionError: Error?

        scriptTask.execute(withAppleEvent: nil) { result, error in
            if let error = error {
                executionError = error
            } else if let result = result {
                resultString = result.stringValue
            }
            semaphore.signal()
        }

        // Wait for completion (with timeout)
        _ = semaphore.wait(timeout: .now() + 2.0)

        if executionError != nil {
            return nil
        }

        guard let output = resultString, !output.isEmpty else {
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

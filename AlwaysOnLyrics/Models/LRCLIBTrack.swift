import Foundation

/// Response model for LRCLIB API track data
struct LRCLIBTrack: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String
    let duration: Double // LRCLIB sometimes returns decimal durations
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?

    /// Duration rounded to nearest integer (for matching purposes)
    var durationInt: Int {
        return Int(duration.rounded())
    }

    /// Check if the track has any lyrics available
    var hasLyrics: Bool {
        return !(plainLyrics?.isEmpty ?? true) || !(syncedLyrics?.isEmpty ?? true) || instrumental
    }

    /// Get the best available lyrics (prefer plain for now)
    var lyrics: String? {
        if let plain = plainLyrics, !plain.isEmpty {
            return plain
        }
        if instrumental {
            return "This track is instrumental (no lyrics)"
        }
        return nil
    }
}

/// Error response from LRCLIB API
struct LRCLIBError: Codable, Error {
    let code: Int
    let name: String
    let message: String
}

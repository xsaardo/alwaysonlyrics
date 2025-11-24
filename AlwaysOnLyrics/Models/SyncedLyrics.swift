import Foundation

/// Container for synchronized lyrics with timestamp-based line access
struct SyncedLyrics {
    let lines: [LyricLine]

    /// Find the currently active lyric line at given playback position
    func currentLine(at position: Double) -> LyricLine? {
        // Find the last line whose timestamp <= position
        return lines
            .filter { $0.timestamp <= position }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Find the index of the current line
    func currentLineIndex(at position: Double) -> Int? {
        guard let current = currentLine(at: position) else { return nil }
        return lines.firstIndex(of: current)
    }

    /// Check if lyrics are available
    var isEmpty: Bool {
        return lines.isEmpty
    }

    /// Total number of lines
    var count: Int {
        return lines.count
    }
}

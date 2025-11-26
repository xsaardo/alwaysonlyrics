import Foundation

/// Parser for LRC (Lyric file) format
/// Converts timestamped lyrics like "[00:12.00]Some text" into LyricLine objects
class LRCParser {

    /// Parse LRC format string into SyncedLyrics
    /// - Parameter lrcString: LRC format lyrics with timestamps
    /// - Returns: SyncedLyrics object with parsed lines
    func parse(_ lrcString: String) -> SyncedLyrics {
        var lyricLines: [LyricLine] = []

        let lines = lrcString.components(separatedBy: .newlines)

        for line in lines {
            // Match pattern: [mm:ss.xx]text or [mm:ss]text
            guard let timestamp = extractTimestamp(from: line),
                  let text = extractText(from: line),
                  !text.isEmpty else {
                continue
            }

            lyricLines.append(LyricLine(timestamp: timestamp, text: text))
        }

        // Sort by timestamp (should already be sorted, but ensure it)
        lyricLines.sort { $0.timestamp < $1.timestamp }

        return SyncedLyrics(lines: lyricLines)
    }

    /// Extract timestamp from LRC line
    /// [00:12.00] -> 12.0 seconds
    /// [00:12] -> 12.0 seconds
    private func extractTimestamp(from line: String) -> Double? {
        // Pattern: [mm:ss.xx] or [mm:ss]
        let pattern = "\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        // Extract minutes and seconds
        guard let minutesRange = Range(match.range(at: 1), in: line),
              let secondsRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let minutes = Double(line[minutesRange]) ?? 0
        let seconds = Double(line[secondsRange]) ?? 0

        return minutes * 60 + seconds
    }

    /// Extract lyric text from LRC line
    /// [00:12.00]Some text -> "Some text"
    private func extractText(from line: String) -> String? {
        // Pattern: extract text after ]
        let pattern = "\\](.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let textRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        return String(line[textRange]).trimmingCharacters(in: .whitespaces)
    }
}

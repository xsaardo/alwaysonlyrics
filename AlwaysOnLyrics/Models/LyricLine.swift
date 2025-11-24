import Foundation

/// Represents a single line of synced lyrics with timestamp
struct LyricLine: Identifiable, Equatable {
    let id: UUID = UUID()
    let timestamp: Double  // Time in seconds
    let text: String

    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.text == rhs.text
    }
}

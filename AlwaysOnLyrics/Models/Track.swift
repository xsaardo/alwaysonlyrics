import Foundation

struct Track: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: Int? // Duration in seconds
    let artworkURL: String?
    let isPlaying: Bool
    let playbackPosition: Double? // Current position in seconds

    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
    }
}

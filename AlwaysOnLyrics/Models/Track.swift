import Foundation

struct Track: Equatable {
    let title: String
    let artist: String
    let isPlaying: Bool

    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.title == rhs.title && lhs.artist == rhs.artist
    }
}

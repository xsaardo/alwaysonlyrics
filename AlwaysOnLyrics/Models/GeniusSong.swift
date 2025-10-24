import Foundation

// MARK: - Genius API Response Models

struct GeniusSearchResponse: Codable {
    let response: GeniusResponse
}

struct GeniusResponse: Codable {
    let hits: [GeniusHit]
}

struct GeniusHit: Codable {
    let result: GeniusSong
}

struct GeniusSong: Codable {
    let id: Int
    let title: String
    let url: String
    let primaryArtist: GeniusArtist
    let songArtImageThumbnailUrl: String?
    let songArtImageUrl: String?
    let releaseDateForDisplay: String?

    enum CodingKeys: String, CodingKey {
        case id, title, url
        case primaryArtist = "primary_artist"
        case songArtImageThumbnailUrl = "song_art_image_thumbnail_url"
        case songArtImageUrl = "song_art_image_url"
        case releaseDateForDisplay = "release_date_for_display"
    }
}

struct GeniusArtist: Codable {
    let name: String
}

import Foundation

enum LyricsError: Error, LocalizedError {
    case invalidAccessToken
    case songNotFound(artist: String, title: String)
    case failedToFetchHTML
    case failedToExtractLyrics
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAccessToken:
            return "Genius API access token is invalid or missing"
        case .songNotFound(let artist, let title):
            return "Song \"\(title)\" by \(artist) not found on Genius"
        case .failedToFetchHTML:
            return "Failed to fetch lyrics page from Genius"
        case .failedToExtractLyrics:
            return "Failed to extract lyrics from page"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Main service for fetching lyrics
/// Refactored with dependency injection for testability
class LyricsService {
    private let accessToken: String
    private let apiClient: GeniusAPIClientProtocol
    private let htmlParser: HTMLParser

    /// Initialize with dependencies (supports dependency injection for testing)
    init(
        accessToken: String = Config.geniusAccessToken,
        apiClient: GeniusAPIClientProtocol? = nil,
        htmlParser: HTMLParser? = nil
    ) {
        self.accessToken = accessToken

        // Use provided dependencies or create default ones
        if let apiClient = apiClient {
            self.apiClient = apiClient
        } else {
            // Create default API client with the access token
            self.apiClient = GeniusAPIClient(accessToken: accessToken)
        }

        self.htmlParser = htmlParser ?? GeniusHTMLParser()
    }

    /// Fetch lyrics for a given track
    func fetchLyrics(artist: String, songTitle: String) async throws -> String {
        guard !accessToken.isEmpty && !accessToken.hasPrefix("ERROR_") else {
            throw LyricsError.invalidAccessToken
        }

        // Step 1: Search for the song
        let query = "\(songTitle) \(artist)"
        let songs = try await apiClient.searchSongs(query: query)

        guard let firstSong = songs.first else {
            throw LyricsError.songNotFound(artist: artist, title: songTitle)
        }

        // Step 2: Fetch HTML from the song's page
        let html = try await apiClient.fetchPageHTML(url: firstSong.url)

        // Step 3: Extract lyrics from HTML
        let extractedHTML = try htmlParser.extractLyrics(from: html)

        // Step 4: Clean HTML to plain text
        let cleanedLyrics = HTMLCleaner.cleanLyricsHTML(extractedHTML)

        return cleanedLyrics
    }
}

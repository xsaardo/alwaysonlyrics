import Foundation

/// Protocol for Genius API operations
protocol GeniusAPIClientProtocol {
    func searchSongs(query: String) async throws -> [GeniusSong]
    func fetchPageHTML(url: String) async throws -> String
}

/// Genius API client implementation
class GeniusAPIClient: GeniusAPIClientProtocol {
    private let accessToken: String
    private let httpClient: HTTPClient

    init(accessToken: String, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.accessToken = accessToken
        self.httpClient = httpClient
    }

    /// Search for songs using Genius API
    func searchSongs(query: String) async throws -> [GeniusSong] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.genius.com/search?q=\(encodedQuery)") else {
            throw LyricsError.networkError(NSError(domain: "Invalid URL", code: -1))
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Lyrics Fetcher and Cleaner", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await httpClient.data(for: request)
            let decodedResponse = try JSONDecoder().decode(GeniusSearchResponse.self, from: data)
            let songs = decodedResponse.response.hits.map { $0.result }
            return songs
        } catch {
            throw LyricsError.networkError(error)
        }
    }

    /// Fetch HTML content from Genius page
    func fetchPageHTML(url: String) async throws -> String {
        guard let url = URL(string: url) else {
            throw LyricsError.failedToFetchHTML
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; Lyrics Fetcher and Cleaner)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await httpClient.data(for: request)

            guard let html = String(data: data, encoding: .utf8) else {
                throw LyricsError.failedToFetchHTML
            }
            return html
        } catch {
            throw LyricsError.networkError(error)
        }
    }
}

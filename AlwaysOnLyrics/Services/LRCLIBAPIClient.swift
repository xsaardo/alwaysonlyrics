import Foundation

/// Protocol for LRCLIB API operations
protocol LRCLIBAPIClientProtocol {
    func getLyrics(artist: String, trackName: String, albumName: String, duration: Int?) async throws -> LRCLIBTrack
    func searchLyrics(artist: String, trackName: String) async throws -> [LRCLIBTrack]
}

/// Client for interacting with LRCLIB API
class LRCLIBAPIClient: LRCLIBAPIClientProtocol {
    private let httpClient: HTTPClient
    private let baseURL = "https://lrclib.net/api"
    private let userAgent = "AlwaysOnLyrics/1.0 (https://github.com/xsaardo/alwaysonlyrics)"

    init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// Get lyrics with exact track signature
    /// - Parameters:
    ///   - artist: Artist name
    ///   - trackName: Track title
    ///   - albumName: Album name
    ///   - duration: Track duration in seconds (optional but recommended)
    /// - Returns: LRCLIB track data with lyrics
    func getLyrics(artist: String, trackName: String, albumName: String, duration: Int?) async throws -> LRCLIBTrack {
        var components = URLComponents(string: "\(baseURL)/get")!

        var queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "album_name", value: albumName)
        ]

        // Include duration if available (improves accuracy)
        if let duration = duration {
            queryItems.append(URLQueryItem(name: "duration", value: "\(duration)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw LRCLIBAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await httpClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LRCLIBAPIError.invalidResponse
        }

        // Handle 404 - track not found
        if httpResponse.statusCode == 404 {
            throw LRCLIBAPIError.trackNotFound
        }

        // Handle other errors
        if httpResponse.statusCode != 200 {
            // Try to parse error response
            if let error = try? JSONDecoder().decode(LRCLIBError.self, from: data) {
                throw LRCLIBAPIError.apiError(error.message)
            }
            throw LRCLIBAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let track = try JSONDecoder().decode(LRCLIBTrack.self, from: data)
            return track
        } catch {
            throw LRCLIBAPIError.decodingError(error)
        }
    }

    /// Search for lyrics using keywords (fallback method)
    /// - Parameters:
    ///   - artist: Artist name
    ///   - trackName: Track title
    /// - Returns: Array of matching tracks (max 20 results)
    func searchLyrics(artist: String, trackName: String) async throws -> [LRCLIBTrack] {
        var components = URLComponents(string: "\(baseURL)/search")!

        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components.url else {
            throw LRCLIBAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await httpClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LRCLIBAPIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let error = try? JSONDecoder().decode(LRCLIBError.self, from: data) {
                throw LRCLIBAPIError.apiError(error.message)
            }
            throw LRCLIBAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let tracks = try JSONDecoder().decode([LRCLIBTrack].self, from: data)
            return tracks
        } catch {
            throw LRCLIBAPIError.decodingError(error)
        }
    }
}

/// Errors that can occur when interacting with LRCLIB API
enum LRCLIBAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case trackNotFound
    case httpError(statusCode: Int)
    case apiError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid LRCLIB API URL"
        case .invalidResponse:
            return "Invalid response from LRCLIB"
        case .trackNotFound:
            return "Lyrics not found for this track"
        case .httpError(let statusCode):
            return "LRCLIB API error: HTTP \(statusCode)"
        case .apiError(let message):
            return "LRCLIB API error: \(message)"
        case .decodingError(let error):
            return "Failed to decode LRCLIB response: \(error.localizedDescription)"
        }
    }
}

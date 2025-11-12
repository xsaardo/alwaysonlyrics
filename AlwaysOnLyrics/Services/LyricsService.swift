import Foundation

enum LyricsError: Error, LocalizedError {
    case trackNotFound(artist: String, title: String)
    case noLyricsAvailable
    case networkError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .trackNotFound(let artist, let title):
            return "Lyrics not found for \"\(title)\" by \(artist)"
        case .noLyricsAvailable:
            return "No lyrics available for this track"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "LRCLIB error: \(message)"
        }
    }
}

/// Main service for fetching lyrics from LRCLIB
class LyricsService {
    private let apiClient: LRCLIBAPIClientProtocol

    /// Initialize with dependencies (supports dependency injection for testing)
    init(apiClient: LRCLIBAPIClientProtocol? = nil) {
        self.apiClient = apiClient ?? LRCLIBAPIClient()
    }

    /// Fetch lyrics for a given track
    /// - Parameters:
    ///   - artist: Artist name
    ///   - songTitle: Track title
    ///   - album: Album name
    ///   - duration: Track duration in seconds (optional but recommended for accuracy)
    /// - Returns: Plain text lyrics
    func fetchLyrics(artist: String, songTitle: String, album: String, duration: Int?) async throws -> String {
        do {
            // Step 1: Try to get lyrics with exact signature
            let track = try await apiClient.getLyrics(
                artist: artist,
                trackName: songTitle,
                albumName: album,
                duration: duration
            )

            // Return lyrics if available
            if let lyrics = track.lyrics {
                return lyrics
            } else {
                throw LyricsError.noLyricsAvailable
            }

        } catch LRCLIBAPIError.trackNotFound {
            // Step 2: Fallback to search if exact match not found
            do {
                let searchResults = try await apiClient.searchLyrics(
                    artist: artist,
                    trackName: songTitle
                )

                // Use first result
                guard let firstResult = searchResults.first else {
                    throw LyricsError.trackNotFound(artist: artist, title: songTitle)
                }

                if let lyrics = firstResult.lyrics {
                    return lyrics
                } else {
                    throw LyricsError.noLyricsAvailable
                }

            } catch {
                // Search also failed
                throw LyricsError.trackNotFound(artist: artist, title: songTitle)
            }

        } catch let error as LRCLIBAPIError {
            throw LyricsError.apiError(error.localizedDescription)
        } catch {
            throw LyricsError.networkError(error)
        }
    }
}

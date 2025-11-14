import Foundation

enum LyricsError: Error, LocalizedError {
    case trackNotFound
    case noLyricsAvailable
    case instrumental
    case networkError
    case apiError

    var errorDescription: String? {
        switch self {
        case .trackNotFound:
            return "No lyrics available for this track"
        case .noLyricsAvailable:
            return "No lyrics available for this track"
        case .instrumental:
            return "This track is instrumental"
        case .networkError:
            return "Lyrics service temporarily unavailable"
        case .apiError:
            return "Lyrics service temporarily unavailable"
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

            // Check if track is instrumental
            if track.instrumental {
                throw LyricsError.instrumental
            }

            // Return lyrics if available
            if let lyrics = track.plainLyrics, !lyrics.isEmpty {
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
                    throw LyricsError.trackNotFound
                }
                
                // Check if track is instrumental
                if firstResult.instrumental {
                    throw LyricsError.instrumental
                }
                
                if let lyrics = firstResult.plainLyrics, !lyrics.isEmpty {
                    return lyrics
                } else {
                    throw LyricsError.noLyricsAvailable
                }
                
            } catch let lyricsError as LyricsError {
                // Re-throw our own errors (instrumental, noLyricsAvailable, etc.)
                throw lyricsError
            } catch LRCLIBAPIError.trackNotFound {
                throw LyricsError.trackNotFound
            } catch {
                // Other errors - search failed
                throw LyricsError.apiError
            }
        } catch let lyricsError as LyricsError {
            throw lyricsError
        } catch {
            throw LyricsError.apiError
        }
    }
}

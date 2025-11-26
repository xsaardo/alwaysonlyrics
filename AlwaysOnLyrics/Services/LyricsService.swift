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
    private let lrcParser = LRCParser()

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
        let track = try await fetchTrack(artist: artist, songTitle: songTitle, album: album, duration: duration)

        // Return lyrics if available
        if let lyrics = track.plainLyrics, !lyrics.isEmpty {
            return lyrics
        } else {
            throw LyricsError.noLyricsAvailable
        }
    }

    /// Fetch synced lyrics if available
    /// - Parameters:
    ///   - artist: Artist name
    ///   - songTitle: Track title
    ///   - album: Album name
    ///   - duration: Track duration in seconds (optional but recommended for accuracy)
    /// - Returns: SyncedLyrics object, or nil if synced lyrics not available
    func fetchSyncedLyrics(artist: String, songTitle: String, album: String, duration: Int?) async throws -> SyncedLyrics? {
        let track = try await fetchTrack(artist: artist, songTitle: songTitle, album: album, duration: duration)

        // Check if synced lyrics available
        guard let syncedLyricsString = track.syncedLyrics,
              !syncedLyricsString.isEmpty else {
            return nil
        }

        // Parse LRC format
        let syncedLyrics = lrcParser.parse(syncedLyricsString)

        return syncedLyrics.isEmpty ? nil : syncedLyrics
    }

    // MARK: - Private Helpers

    /// Fetch track data from LRCLIB API with common error handling
    /// - Parameters:
    ///   - artist: Artist name
    ///   - songTitle: Track title
    ///   - album: Album name
    ///   - duration: Track duration in seconds
    /// - Returns: LRCLIBTrack data
    /// - Throws: LyricsError for various failure cases
    private func fetchTrack(artist: String, songTitle: String, album: String, duration: Int?) async throws -> LRCLIBTrack {
        do {
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

            return track

        } catch LRCLIBAPIError.trackNotFound {
            throw LyricsError.trackNotFound
        } catch let lyricsError as LyricsError {
            throw lyricsError
        } catch {
            throw LyricsError.apiError
        }
    }
}

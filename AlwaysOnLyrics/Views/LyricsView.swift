import SwiftUI

/// Main SwiftUI view for displaying lyrics with song information
struct LyricsView: View {

    // MARK: - Observed Objects
    @ObservedObject var spotifyMonitor: SpotifyMonitor

    // MARK: - Services
    let lyricsService: LyricsService

    // MARK: - State
    @State private var currentTrack: Track?
    @State private var lyrics: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background with blur effect
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with song info
                headerView

                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal)

                // Content area
                contentView
            }
        }
        .onChange(of: spotifyMonitor.currentTrack) { newTrack in
            handleTrackChange(newTrack)
        }
        .onAppear {
            // Load current track if available
            if let track = spotifyMonitor.currentTrack {
                handleTrackChange(track)
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let track = currentTrack {
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            } else if !spotifyMonitor.spotifyRunning {
                Text("Spotify Not Running")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } else {
                Text("No Track Playing")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !spotifyMonitor.spotifyRunning {
                    // Spotify not running state
                    emptyStateView(
                        title: "Open Spotify to see lyrics",
                        icon: "music.note"
                    )
                } else if currentTrack == nil {
                    // No track playing state
                    emptyStateView(
                        title: "Play a song to see lyrics",
                        icon: "play.circle"
                    )
                } else if isLoading {
                    // Loading state
                    loadingView
                } else if let error = errorMessage {
                    // Error state
                    emptyStateView(
                        title: error,
                        icon: "exclamationmark.triangle"
                    )
                } else if lyrics.isEmpty {
                    // No lyrics found state
                    emptyStateView(
                        title: "Lyrics not available for this track",
                        icon: "doc.text"
                    )
                } else {
                    // Lyrics display
                    lyricsView
                }
            }
            .padding()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Fetching lyrics...")
                .font(.body)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Empty State View
    private func emptyStateView(title: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(title)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Lyrics View
    private var lyricsView: some View {
        Text(lyrics)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    // MARK: - Track Change Handler
    private func handleTrackChange(_ newTrack: Track?) {
        guard let track = newTrack else {
            // No track available, clear everything
            currentTrack = nil
            lyrics = ""
            errorMessage = nil
            return
        }

        // Check if this is a different song (not just play/pause state change)
        let isDifferentSong = currentTrack?.title != track.title ||
                             currentTrack?.artist != track.artist

        currentTrack = track

        if isDifferentSong {
            // New song: clear old lyrics and fetch new ones
            lyrics = ""
            errorMessage = nil
            Task {
                await fetchLyrics(for: track)
            }
        } else if lyrics.isEmpty && errorMessage == nil {
            // Same song but no lyrics loaded yet: fetch them
            Task {
                await fetchLyrics(for: track)
            }
        }
        // If same song and lyrics already loaded: keep them (don't refetch)
    }

    // MARK: - Fetch Lyrics
    private func fetchLyrics(for track: Track) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedLyrics = try await lyricsService.fetchLyrics(
                artist: track.artist,
                songTitle: track.title
            )

            await MainActor.run {
                self.lyrics = fetchedLyrics
                self.isLoading = false
            }
        } catch LyricsError.songNotFound {
            await MainActor.run {
                self.errorMessage = "Lyrics not available for this track"
                self.isLoading = false
            }
        } catch LyricsError.invalidAccessToken {
            await MainActor.run {
                self.errorMessage = "Invalid Genius API token"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch lyrics"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let monitor = SpotifyMonitor()
    let service = LyricsService()

    return LyricsView(spotifyMonitor: monitor, lyricsService: service)
        .frame(width: 400, height: 600)
}

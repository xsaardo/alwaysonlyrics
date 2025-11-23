import SwiftUI

/// Main SwiftUI view for displaying lyrics with song information
struct LyricsView: View {

    // MARK: - Observed Objects
    @ObservedObject var spotifyMonitor: SpotifyMonitor
    @ObservedObject var settings = AppSettings.shared

    // MARK: - Services
    let lyricsService: LyricsService

    // MARK: - State
    @State private var currentTrack: Track?
    @State private var lyrics: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentFetchTask: Task<Void, Never>?

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header with song info
            headerView
                .padding(.horizontal)

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal)

            // Content area
            contentView
        }
        .background(Color.black) // Single background for entire view
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
        HStack(spacing: 12) {
            if let track = currentTrack {
                // Album artwork
                albumArtworkView(for: track)

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .help(track.title)

                    Text("\(track.artist) • \(track.album)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help("\(track.artist) • \(track.album)")
                }
            } else if !spotifyMonitor.spotifyRunning {
                // Fallback icon when Spotify not running
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading) {
                    Text("Spotify Not Running")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            } else {
                // Fallback icon when no track playing
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading) {
                    Text("No Track Playing")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Album Artwork View
    private func albumArtworkView(for track: Track) -> some View {
        Group {
            if let artworkURLString = track.artworkURL,
               let artworkURL = URL(string: artworkURLString) {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    case .failure(let error):
                        placeholderArtwork
                    @unknown default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
    }

    // MARK: - Placeholder Artwork
    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)

            Image(systemName: "music.note")
                .font(.system(size: 28))
                .foregroundColor(.gray)
        }
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
            .id(contentIdentifier) // Force view recreation when content changes
        }
    }

    // MARK: - Content Identifier
    /// Unique identifier that changes whenever the displayed content changes
    /// This forces SwiftUI to completely recreate the view, preventing ghosting
    private var contentIdentifier: String {
        if !spotifyMonitor.spotifyRunning {
            return "no-spotify"
        } else if currentTrack == nil {
            return "no-track"
        } else if isLoading {
            return "loading-\(currentTrack?.title ?? "")"
        } else if let error = errorMessage {
            return "error-\(error)"
        } else if lyrics.isEmpty {
            return "no-lyrics-\(currentTrack?.title ?? "")"
        } else {
            return "lyrics-\(currentTrack?.title ?? "")-\(lyrics.prefix(50).hashValue)"
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            CustomSpinner()
                .frame(width: 40, height: 40)

            Text("Fetching lyrics...")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
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
            .font(.system(size: settings.fontSize))
            .foregroundColor(.white)
            .lineSpacing(settings.lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    // MARK: - Track Change Handler
    private func handleTrackChange(_ newTrack: Track?) {
        // Cancel any in-flight lyrics fetch
        currentFetchTask?.cancel()
        currentFetchTask = nil

        guard let track = newTrack else {
            // No track available, clear everything
            currentTrack = nil
            lyrics = ""
            errorMessage = nil
            return
        }

        // Check if this is a different song (not just play/pause state change)
        let isDifferentSong = currentTrack?.title != track.title ||
                             currentTrack?.artist != track.artist ||
                             currentTrack?.album != track.album

        currentTrack = track

        // Check if artist name is empty (podcasts/audiobooks don't have artists)
        if track.artist.trimmingCharacters(in: .whitespaces).isEmpty {
            lyrics = ""
            errorMessage = "Lyrics are not available for podcasts and audiobooks"
            return
        }

        if isDifferentSong {
            // New song: clear old lyrics and fetch new ones
            lyrics = ""
            errorMessage = nil
            currentFetchTask = Task {
                await fetchLyrics(for: track)
            }
        } else if lyrics.isEmpty && errorMessage == nil {
            // Same song but no lyrics loaded yet: fetch them
            currentFetchTask = Task {
                await fetchLyrics(for: track)
            }
        }
        // If same song and lyrics already loaded: keep them (don't refetch)
    }

    // MARK: - Helper Methods
    private func isCurrentTrack(_ track: Track) -> Bool {
        !Task.isCancelled &&
        currentTrack?.title == track.title &&
        currentTrack?.artist == track.artist &&
        currentTrack?.album == track.album
    }

    // MARK: - Fetch Lyrics
    private func fetchLyrics(for track: Track) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedLyrics = try await lyricsService.fetchLyrics(
                artist: track.artist,
                songTitle: track.title,
                album: track.album,
                duration: track.duration
            )

            // Check if task was cancelled or track changed before updating UI
            guard isCurrentTrack(track) else {
                return
            }

            await MainActor.run {
                self.lyrics = fetchedLyrics
                self.isLoading = false
            }
        } catch LyricsError.instrumental {
            // Track is instrumental
            guard isCurrentTrack(track) else {
                return
            }

            await MainActor.run {
                self.errorMessage = "This track is instrumental"
                self.isLoading = false
            }
        } catch LyricsError.trackNotFound {
            // Only show error if this is still the current track
            guard isCurrentTrack(track) else {
                return
            }

            await MainActor.run {
                self.errorMessage = "Lyrics not available for this track"
                self.isLoading = false
            }
        } catch LyricsError.noLyricsAvailable {
            guard isCurrentTrack(track) else {
                return
            }

            await MainActor.run {
                self.errorMessage = "No lyrics available for this track"
                self.isLoading = false
            }
        } catch {
            guard isCurrentTrack(track) else {
                return
            }

            await MainActor.run {
                self.errorMessage = "Failed to fetch lyrics: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Custom Spinner
struct CustomSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white, lineWidth: 4)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview
#Preview {
    let monitor = SpotifyMonitor()
    let service = LyricsService()

    return LyricsView(spotifyMonitor: monitor, lyricsService: service)
        .frame(width: 375, height: 650)
}

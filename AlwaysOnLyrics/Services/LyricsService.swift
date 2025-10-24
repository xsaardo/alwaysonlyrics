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

class LyricsService {
    private let accessToken: String

    init(accessToken: String = Config.geniusAccessToken) {
        self.accessToken = accessToken
    }

    /// Fetch lyrics for a given track
    func fetchLyrics(artist: String, songTitle: String) async throws -> String {
        guard !accessToken.isEmpty && accessToken != "YOUR_GENIUS_ACCESS_TOKEN_HERE" else {
            throw LyricsError.invalidAccessToken
        }

        // Step 1: Search for the song
        let songs = try await searchSong(artist: artist, songTitle: songTitle)

        guard let firstSong = songs.first else {
            throw LyricsError.songNotFound(artist: artist, title: songTitle)
        }

        // Step 2: Fetch HTML from the song's page
        let html = try await fetchPageHTML(url: firstSong.url)

        // Step 3: Extract lyrics from HTML
        let extractedHTML = try extractLyricsFromHTML(html)

        // Step 4: Clean HTML to plain text
        let cleanedLyrics = HTMLCleaner.cleanLyricsHTML(extractedHTML)

        return cleanedLyrics
    }

    /// Search for a song using Genius API
    private func searchSong(artist: String, songTitle: String) async throws -> [GeniusSong] {
        let query = "\(songTitle) \(artist)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.genius.com/search?q=\(encodedQuery)") else {
            throw LyricsError.networkError(NSError(domain: "Invalid URL", code: -1))
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Lyrics Fetcher and Cleaner", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(GeniusSearchResponse.self, from: data)
            return response.response.hits.map { $0.result }
        } catch {
            throw LyricsError.networkError(error)
        }
    }

    /// Fetch HTML content from Genius page
    private func fetchPageHTML(url: String) async throws -> String {
        guard let url = URL(string: url) else {
            throw LyricsError.failedToFetchHTML
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; Lyrics Fetcher and Cleaner)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                throw LyricsError.failedToFetchHTML
            }
            return html
        } catch {
            throw LyricsError.networkError(error)
        }
    }

    /// Extract lyrics from Genius page HTML
    /// This uses regex-based extraction similar to the JavaScript version
    private func extractLyricsFromHTML(_ html: String) throws -> String {
        // Find all divs with class starting with "Lyrics__Container"
        // Pattern to match: <div class="Lyrics__Container-...">...</div>
        let pattern = #"<div[^>]*class="[^"]*Lyrics__Container[^"]*"[^>]*>(.*?)</div>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            throw LyricsError.failedToExtractLyrics
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        var allContainers = ""

        for match in matches {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    var containerHTML = nsString.substring(with: range)

                    // Remove elements with data-exclude-from-selection="true"
                    containerHTML = removeExcludedElements(from: containerHTML)

                    allContainers += containerHTML + "\n\n"
                }
            }
        }

        guard !allContainers.isEmpty else {
            throw LyricsError.failedToExtractLyrics
        }

        return allContainers
    }

    /// Remove elements with data-exclude-from-selection="true"
    private func removeExcludedElements(from html: String) -> String {
        // Pattern to match elements with data-exclude-from-selection="true"
        let pattern = #"<[^>]*data-exclude-from-selection="true"[^>]*>.*?</[^>]+>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return html
        }

        let nsString = html as NSString
        let result = regex.stringByReplacingMatches(
            in: html,
            options: [],
            range: NSRange(location: 0, length: nsString.length),
            withTemplate: ""
        )

        return result
    }
}

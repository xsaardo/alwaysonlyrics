import Foundation
import SwiftSoup

/// Protocol for HTML parsing operations
protocol HTMLParser {
    func extractLyrics(from html: String) throws -> String
}

/// Genius-specific HTML parser for extracting lyrics using SwiftSoup
class GeniusHTMLParser: HTMLParser {

    func extractLyrics(from html: String) throws -> String {
        // Parse the HTML document
        let doc: Document
        do {
            doc = try SwiftSoup.parse(html)
        } catch {
            throw LyricsError.failedToExtractLyrics
        }

        // Find all divs with class containing "Lyrics__Container"
        // Using CSS selector: div[class*='Lyrics__Container']
        let containers: Elements
        do {
            containers = try doc.select("div[class*='Lyrics__Container']")
        } catch {
            throw LyricsError.failedToExtractLyrics
        }

        guard !containers.isEmpty() else {
            throw LyricsError.failedToExtractLyrics
        }

        var allContainers = ""

        for container in containers.array() {
            do {
                // Remove elements with data-exclude-from-selection="true"
                let excluded = try container.select("[data-exclude-from-selection='true']")
                try excluded.remove()

                // Get the HTML content of the container
                let containerHTML = try container.html()
                allContainers += containerHTML + "\n\n"
            } catch {
                // Continue with other containers
                continue
            }
        }

        guard !allContainers.isEmpty else {
            throw LyricsError.failedToExtractLyrics
        }

        return allContainers
    }
}

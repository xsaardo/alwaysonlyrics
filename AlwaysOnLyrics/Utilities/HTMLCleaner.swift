import Foundation
import SwiftSoup

struct HTMLCleaner {
    /// List of formatting tags to preserve
    private static let formattingTags = [
        "b", "strong", "i", "em", "u", "ins", "del", "s", "strike",
        "sup", "sub", "mark", "small", "big", "code", "kbd", "samp",
        "var", "abbr", "acronym", "cite", "dfn", "q", "blockquote",
        "pre", "tt", "br", "hr", "wbr"
    ]

    /// Removes all non-formatting HTML tags while preserving formatting tags and their content
    static func removeNonFormattingTags(_ html: String) -> String {
        // Regular expression to match HTML tags
        let pattern = "</?([a-zA-Z][a-zA-Z0-9]*)[^>]*>"

        var result = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

            // Process matches in reverse to maintain string indices
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: html),
                   let tagNameRange = Range(match.range(at: 1), in: html) {
                    let tagName = String(html[tagNameRange]).lowercased()

                    // Remove the tag if it's not a formatting tag
                    if !formattingTags.contains(tagName) {
                        result.replaceSubrange(matchRange, with: "")
                    }
                }
            }
        }

        return result
    }

    /// Clean HTML content and convert to plain text using SwiftSoup
    /// This is the new recommended method that properly handles HTML structure
    static func cleanLyricsHTML(_ html: String) -> String {
        do {
            // Remove newlines
            let removedNewlines = html.replacingOccurrences(of: "\n", with: "")
            
            // Parse the HTML fragment
            let doc = try SwiftSoup.parseBodyFragment(removedNewlines)
            
            // Replace <br> tags with newlines before extracting text
            let brTags = try doc.select("br")
            for br in brTags.array() {
                try br.replaceWith(TextNode("\n", ""))
            }

            // Get the text content (SwiftSoup automatically decodes HTML entities)
            let text = try doc.text(trimAndNormaliseWhitespace: false)

            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            // Fallback to regex-based cleaning if SwiftSoup fails
            return cleanLyricsHTMLLegacy(html)
        }
    }

    /// Legacy HTML cleaning method using regex (fallback)
    private static func cleanLyricsHTMLLegacy(_ html: String) -> String {
        var result = html

        // Replace <br> tags with actual line breaks FIRST
        result = result
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")

        // Remove ALL HTML tags (including formatting tags)
        // Pattern matches any HTML tag: <tag>, </tag>, <tag attr="value">
        let pattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Decode HTML entities
        result = decodeHTMLEntities(result)

        // Clean up multiple newlines (max 2 in a row)
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decode common HTML entities
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // First decode numeric entities like &#39; and &#x27;
        // Decimal entities: &#39;
        let decimalPattern = "&#(\\d+);"
        if let decimalRegex = try? NSRegularExpression(pattern: decimalPattern, options: []) {
            let matches = decimalRegex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: result),
                   let codeRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[codeRange]),
                   let scalar = UnicodeScalar(code) {
                    result.replaceSubrange(matchRange, with: String(Character(scalar)))
                }
            }
        }

        // Hex entities: &#x27;
        let hexPattern = "&#x([0-9a-fA-F]+);"
        if let hexRegex = try? NSRegularExpression(pattern: hexPattern, options: []) {
            let matches = hexRegex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: result),
                   let codeRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[codeRange], radix: 16),
                   let scalar = UnicodeScalar(code) {
                    result.replaceSubrange(matchRange, with: String(Character(scalar)))
                }
            }
        }

        // Named entities
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&ndash;": "–",
            "&mdash;": "—",
            "&hellip;": "…"
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }
}

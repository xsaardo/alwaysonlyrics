import Foundation

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

    /// Clean HTML content and convert to plain text
    static func cleanLyricsHTML(_ html: String) -> String {
        let cleanedContent = removeNonFormattingTags(html)

        // Replace <br> tags with actual line breaks and clean up whitespace
        return cleanedContent
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

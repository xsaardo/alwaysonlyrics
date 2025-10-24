import Foundation

struct Config {
    // MARK: - Genius API

    /// Loads Genius API access token from secure sources
    /// Priority order:
    /// 1. Environment variable: GENIUS_ACCESS_TOKEN
    /// 2. config.json file in project root
    /// 3. Fallback error message
    static var geniusAccessToken: String {
        // Try environment variable first
        if let envToken = ProcessInfo.processInfo.environment["GENIUS_ACCESS_TOKEN"],
           !envToken.isEmpty {
            return envToken
        }

        // Try loading from config.json file
        if let fileToken = loadTokenFromConfigFile() {
            return fileToken
        }

        // No token found - return error message
        return "ERROR_NO_TOKEN_CONFIGURED"
    }

    /// Load token from config.json file (gitignored)
    private static func loadTokenFromConfigFile() -> String? {
        // Get the bundle's resource path or executable path
        var configURL: URL?

        // Try to find config.json in the app bundle's Resources directory
        if let resourcePath = Bundle.main.resourcePath {
            configURL = URL(fileURLWithPath: resourcePath).appendingPathComponent("config.json")

            if FileManager.default.fileExists(atPath: configURL!.path) {
                return parseConfigFile(at: configURL!)
            }
        }

        // Try to find config.json next to the executable (for development)
        if let executablePath = Bundle.main.executablePath {
            let executableDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
            configURL = executableDir.appendingPathComponent("config.json")

            if FileManager.default.fileExists(atPath: configURL!.path) {
                return parseConfigFile(at: configURL!)
            }
        }

        // Try to find config.json in the project root (for development)
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("config.json")

        if FileManager.default.fileExists(atPath: projectRoot.path) {
            return parseConfigFile(at: projectRoot)
        }

        return nil
    }

    /// Parse config.json file and extract token
    private static func parseConfigFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["geniusAccessToken"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }

    // MARK: - Polling
    static let spotifyPollingInterval: TimeInterval = 1.5

    // MARK: - Window Defaults
    static let defaultWindowWidth: CGFloat = 400
    static let defaultWindowHeight: CGFloat = 600
}

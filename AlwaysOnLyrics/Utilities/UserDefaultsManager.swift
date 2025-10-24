import Foundation
import AppKit

/// Manages persistence of window state and app preferences using UserDefaults
class UserDefaultsManager {

    static let shared = UserDefaultsManager()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let windowX = "windowX"
        static let windowY = "windowY"
        static let windowWidth = "windowWidth"
        static let windowHeight = "windowHeight"
        static let windowVisible = "windowVisible"
    }

    private init() {}

    // MARK: - Window Position & Size

    /// Save window frame (position and size)
    func saveWindowFrame(_ frame: NSRect) {
        defaults.set(Double(frame.origin.x), forKey: Keys.windowX)
        defaults.set(Double(frame.origin.y), forKey: Keys.windowY)
        defaults.set(Double(frame.size.width), forKey: Keys.windowWidth)
        defaults.set(Double(frame.size.height), forKey: Keys.windowHeight)
    }

    /// Load saved window frame, or return default if not saved
    func loadWindowFrame() -> NSRect {
        let x = defaults.double(forKey: Keys.windowX)
        let y = defaults.double(forKey: Keys.windowY)
        let width = defaults.double(forKey: Keys.windowWidth)
        let height = defaults.double(forKey: Keys.windowHeight)

        // If no saved values, return default size centered on screen
        if width == 0 || height == 0 {
            return defaultWindowFrame()
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Get default window frame (centered on main screen)
    private func defaultWindowFrame() -> NSRect {
        let width = Config.defaultWindowWidth
        let height = Config.defaultWindowHeight

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - width / 2
            let y = screenFrame.midY - height / 2
            return NSRect(x: x, y: y, width: width, height: height)
        }

        // Fallback if no screen available
        return NSRect(x: 100, y: 100, width: width, height: height)
    }

    // MARK: - Window Visibility

    /// Save window visibility state
    func saveWindowVisible(_ visible: Bool) {
        defaults.set(visible, forKey: Keys.windowVisible)
    }

    /// Load window visibility state (defaults to false)
    func loadWindowVisible() -> Bool {
        return defaults.bool(forKey: Keys.windowVisible)
    }

    // MARK: - Reset

    /// Reset all saved preferences to defaults
    func resetToDefaults() {
        defaults.removeObject(forKey: Keys.windowX)
        defaults.removeObject(forKey: Keys.windowY)
        defaults.removeObject(forKey: Keys.windowWidth)
        defaults.removeObject(forKey: Keys.windowHeight)
        defaults.removeObject(forKey: Keys.windowVisible)
    }
}

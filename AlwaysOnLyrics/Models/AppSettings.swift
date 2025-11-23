import SwiftUI
import ServiceManagement
import AppKit

/// Manages application-wide user settings with UserDefaults persistence
class AppSettings: ObservableObject {

    // MARK: - Singleton
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Constants
    private enum Constants {
        static let defaultWindowWidth: CGFloat = 375
        static let defaultWindowHeight: CGFloat = 650
    }

    // MARK: - Window Behavior Settings

    var alwaysOnTop: Bool {
        get { _alwaysOnTop }
        set {
            _alwaysOnTop = newValue
            defaults.set(newValue, forKey: "alwaysOnTop")
            objectWillChange.send()  // Send after change so observers see new value
        }
    }
    private var _alwaysOnTop: Bool = true

    var windowOpacity: Double {
        get { _windowOpacity }
        set {
            _windowOpacity = newValue
            defaults.set(newValue, forKey: "windowOpacity")
            objectWillChange.send()  // Send after change so observers see new value
        }
    }
    private var _windowOpacity: Double = 0.95

    var rememberWindowPosition: Bool {
        get { _rememberWindowPosition }
        set {
            objectWillChange.send()
            _rememberWindowPosition = newValue
            defaults.set(newValue, forKey: "rememberWindowPosition")
        }
    }
    private var _rememberWindowPosition: Bool = true

    var rememberWindowSize: Bool {
        get { _rememberWindowSize }
        set {
            objectWillChange.send()
            _rememberWindowSize = newValue
            defaults.set(newValue, forKey: "rememberWindowSize")
        }
    }
    private var _rememberWindowSize: Bool = true

    var launchAtLogin: Bool {
        get { _launchAtLogin }
        set {
            objectWillChange.send()
            _launchAtLogin = newValue
            defaults.set(newValue, forKey: "launchAtLogin")
            if isInitialized {
                updateLaunchAtLogin()
            }
        }
    }
    private var _launchAtLogin: Bool = false

    private var isInitialized = false

    // MARK: - Appearance Settings

    var fontSize: Double {
        get { _fontSize }
        set {
            objectWillChange.send()
            _fontSize = newValue
            defaults.set(newValue, forKey: "fontSize")
        }
    }
    private var _fontSize: Double = 14.0

    var lineSpacing: Double {
        get { _lineSpacing }
        set {
            objectWillChange.send()
            _lineSpacing = newValue
            defaults.set(newValue, forKey: "lineSpacing")
        }
    }
    private var _lineSpacing: Double = 6.0

    // MARK: - Window Position/Size Storage

    var windowX: Double {
        get { defaults.double(forKey: "windowX") }
        set { defaults.set(newValue, forKey: "windowX") }
    }

    var windowY: Double {
        get { defaults.double(forKey: "windowY") }
        set { defaults.set(newValue, forKey: "windowY") }
    }

    var windowWidth: Double {
        get {
            let value = defaults.double(forKey: "windowWidth")
            return value > 0 ? value : 375.0
        }
        set { defaults.set(newValue, forKey: "windowWidth") }
    }

    var windowHeight: Double {
        get {
            let value = defaults.double(forKey: "windowHeight")
            return value > 0 ? value : 650.0
        }
        set { defaults.set(newValue, forKey: "windowHeight") }
    }

    var windowVisible: Bool {
        get {
            // Check if the key exists - if not, this is first launch
            if defaults.object(forKey: "windowVisible") == nil {
                // First launch - show window by default
                return true
            }
            return defaults.bool(forKey: "windowVisible")
        }
        set { defaults.set(newValue, forKey: "windowVisible") }
    }

    // MARK: - Initialization

    private init() {
        // Load values from UserDefaults directly into backing variables (avoids triggering setters/observers)
        if let saved = defaults.object(forKey: "alwaysOnTop") as? Bool {
            _alwaysOnTop = saved
        }
        if let saved = defaults.object(forKey: "windowOpacity") as? Double {
            _windowOpacity = saved
        }
        if let saved = defaults.object(forKey: "rememberWindowPosition") as? Bool {
            _rememberWindowPosition = saved
        }
        if let saved = defaults.object(forKey: "rememberWindowSize") as? Bool {
            _rememberWindowSize = saved
        }
        if let saved = defaults.object(forKey: "launchAtLogin") as? Bool {
            _launchAtLogin = saved
        }
        if let saved = defaults.object(forKey: "fontSize") as? Double {
            _fontSize = saved
        }
        if let saved = defaults.object(forKey: "lineSpacing") as? Double {
            _lineSpacing = saved
        }

        // Mark as initialized to allow side effects
        isInitialized = true
    }

    // MARK: - Helper Methods

    /// Updates macOS launch at login setting
    private func updateLaunchAtLogin() {
        #if !DEBUG
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error.localizedDescription)")
            }
        } else {
            // Fallback for older macOS versions
            setLaunchAtLoginLegacy(enabled: launchAtLogin)
        }
        #endif
    }

    /// Legacy method for launch at login on macOS < 13
    private func setLaunchAtLoginLegacy(enabled: Bool) {
        guard let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            print("Failed to get login items list")
            return
        }

        if enabled {
            if let appURL = Bundle.main.bundleURL as CFURL? {
                LSSharedFileListInsertItemURL(
                    loginItemsRef,
                    kLSSharedFileListItemBeforeFirst.takeRetainedValue(),
                    nil,
                    nil,
                    appURL,
                    nil,
                    nil
                )
            }
        } else {
            if let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)?.takeRetainedValue() as? [LSSharedFileListItem] {
                for item in loginItems {
                    if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL? {
                        if itemURL.path == Bundle.main.bundleURL.path {
                            LSSharedFileListItemRemove(loginItemsRef, item)
                        }
                    }
                }
            }
        }
    }

    /// Save current window position
    func saveWindowPosition(x: CGFloat, y: CGFloat) {
        guard rememberWindowPosition else { return }
        windowX = Double(x)
        windowY = Double(y)
    }

    /// Save current window size
    func saveWindowSize(width: CGFloat, height: CGFloat) {
        guard rememberWindowSize else { return }
        windowWidth = Double(width)
        windowHeight = Double(height)
    }

    /// Save window frame (position and size)
    func saveWindowFrame(_ frame: NSRect) {
        if rememberWindowPosition {
            windowX = Double(frame.origin.x)
            windowY = Double(frame.origin.y)
        }
        if rememberWindowSize {
            windowWidth = Double(frame.size.width)
            windowHeight = Double(frame.size.height)
        }
    }

    /// Load saved window frame, or return default if not saved
    func loadWindowFrame() -> NSRect {
        let x = windowX
        let y = windowY
        let width = windowWidth
        let height = windowHeight

        // If no saved values, return default size centered on screen
        if width == 0 || height == 0 {
            return defaultWindowFrame()
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Get default window frame (centered on main screen)
    private func defaultWindowFrame() -> NSRect {
        let width = Constants.defaultWindowWidth
        let height = Constants.defaultWindowHeight

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - width / 2
            let y = screenFrame.midY - height / 2
            return NSRect(x: x, y: y, width: width, height: height)
        }

        // Fallback if no screen available
        return NSRect(x: 100, y: 100, width: width, height: height)
    }

    /// Save window visibility state
    func saveWindowVisible(_ visible: Bool) {
        windowVisible = visible
    }

    /// Load window visibility state (defaults to true on first launch)
    func loadWindowVisible() -> Bool {
        return windowVisible
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        alwaysOnTop = true
        windowOpacity = 0.95
        rememberWindowPosition = true
        rememberWindowSize = true
        launchAtLogin = false
        fontSize = 14.0
        lineSpacing = 6.0
    }
}

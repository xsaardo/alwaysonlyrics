import AppKit
import SwiftUI

/// App delegate for menu bar application
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var lyricsWindow: LyricsWindow?
    private var preferencesWindow: NSWindow?
    private var spotifyMonitor: SpotifyMonitor!
    private var lyricsService: LyricsService!
    private var statusBarMenu: NSMenu!

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the default empty window created by WindowGroup
        if let window = NSApplication.shared.windows.first {
            window.close()
        }

        // Request automation permission explicitly
        requestAutomationPermission()

        // Initialize services
        setupServices()

        // Setup custom main menu (to override default preferences)
        setupMainMenu()

        // Setup menu bar icon
        setupMenuBar()

        // Create lyrics window
        setupLyricsWindow()

        // Register keyboard shortcuts
        setupKeyboardShortcuts()

        // Start monitoring Spotify
        spotifyMonitor.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring
        spotifyMonitor.stopMonitoring()

        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, willEncodeRestorableState coder: NSCoder) {
        // Don't save any restorable state
    }

    func application(_ application: NSApplication, didDecodeRestorableState coder: NSCoder) {
        // Don't restore any state
    }

    // MARK: - Automation Permission
    private func requestAutomationPermission() {
        // This will trigger the permission dialog if not already granted
        let script = """
        tell application "Spotify"
            if it is running then
                return "running"
            end if
        end tell
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
    }

    // MARK: - Services Setup
    private func setupServices() {
        spotifyMonitor = SpotifyMonitor()
        lyricsService = LyricsService()
    }

    // MARK: - Main Menu Setup
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (first menu with app name)
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        // Preferences menu item (Cmd+,)
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)

        appMenu.addItem(NSMenuItem.separator())

        // Quit menu item (Cmd+Q)
        let quitItem = NSMenuItem(
            title: "Quit AlwaysOnLyrics",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)

        mainMenu.addItem(appMenuItem)

        // File menu (for Close command)
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu

        // Toggle lyrics window menu item (Cmd+Shift+L)
        let toggleLyricsItem = NSMenuItem(
            title: "Toggle Lyrics Window",
            action: #selector(toggleLyricsWindow),
            keyEquivalent: "l"
        )
        toggleLyricsItem.keyEquivalentModifierMask = [.command, .shift]
        toggleLyricsItem.target = self
        fileMenu.addItem(toggleLyricsItem)

        fileMenu.addItem(NSMenuItem.separator())

        // Close window menu item (Cmd+W)
        let closeItem = NSMenuItem(
            title: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenu.addItem(closeItem)

        mainMenu.addItem(fileMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    // MARK: - Menu Bar Setup
    private func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set menu bar icon
        if let button = statusItem.button {
            // Use system music note icon as default
            let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Always On Lyrics")
            image?.isTemplate = true // Allow system to tint it appropriately
            button.image = image
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create menu
        statusBarMenu = NSMenu()

        // Toggle window menu item
        let toggleItem = NSMenuItem(
            title: "Toggle Lyrics Window",
            action: #selector(toggleLyricsWindow),
            keyEquivalent: "l"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        statusBarMenu.addItem(toggleItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Preferences menu item
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        statusBarMenu.addItem(preferencesItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        statusBarMenu.addItem(quitItem)

        // Don't set menu to status item - we'll show it manually on right-click
    }

    // MARK: - Lyrics Window Setup
    private func setupLyricsWindow() {
        lyricsWindow = LyricsWindow(
            spotifyMonitor: spotifyMonitor,
            lyricsService: lyricsService
        )

        // Prevent window from being deallocated when closed
        lyricsWindow?.isReleasedWhenClosed = false

        // Set window delegate to handle close events
        lyricsWindow?.delegate = self

        // Make sure window is visible
        if lyricsWindow?.isVisible == false {
            lyricsWindow?.show()
        }
    }

    // MARK: - Keyboard Shortcuts
    private func setupKeyboardShortcuts() {
        // Menu keyboard shortcuts should work automatically through NSMenu
        // But we need to ensure the responder chain is properly set up

        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenConfigurationDidChange(_ notification: Notification) {
        // Screen configuration changed - menu shortcuts stop working
        // Rebuild the entire menu to re-establish responder chain

        // Small delay to let system finish reconfiguration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }

            // Completely rebuild the menu - this reestablishes all shortcuts
            self.setupMainMenu()
        }
    }

    // MARK: - Actions
    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            statusItem.menu = statusBarMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Left-click: toggle window
            toggleLyricsWindow()
        }
    }

    @objc private func toggleLyricsWindow() {
        lyricsWindow?.toggleVisibility()
    }

    @objc private func openPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let preferencesView = PreferencesWindow()
            let hostingController = NSHostingController(rootView: preferencesView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable]
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)

            preferencesWindow = window
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Window Delegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Window is being closed, nothing special needed
        // (LyricsWindow already saves its state)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow window to close (will be hidden, not destroyed)
        return true
    }
}

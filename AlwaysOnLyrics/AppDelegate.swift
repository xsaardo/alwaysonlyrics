import AppKit
import SwiftUI

/// App delegate for menu bar application
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var lyricsWindow: LyricsWindow?
    private var spotifyMonitor: SpotifyMonitor!
    private var lyricsService: LyricsService!
    private var statusBarMenu: NSMenu!

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        setupServices()

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

    // MARK: - Services Setup
    private func setupServices() {
        spotifyMonitor = SpotifyMonitor()
        lyricsService = LyricsService()
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
            keyEquivalent: ""
        )
        statusBarMenu.addItem(toggleItem)

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

        // Set window delegate to handle close events
        lyricsWindow?.delegate = self

        // Make sure window is visible
        if lyricsWindow?.isVisible == false {
            lyricsWindow?.show()
        }
    }

    // MARK: - Keyboard Shortcuts
    private func setupKeyboardShortcuts() {
        // Register Cmd+Shift+L global hotkey
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Cmd+Shift+L
            if event.modifierFlags.contains([.command, .shift]) &&
               event.charactersIgnoringModifiers == "l" {
                self?.toggleLyricsWindow()
                return nil // Event handled
            }
            return event // Pass through
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

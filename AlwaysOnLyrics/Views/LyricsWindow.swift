import AppKit
import SwiftUI

/// Custom NSWindow subclass for always-on-top lyrics display
class LyricsWindow: NSWindow {

    // MARK: - Properties
    private let userDefaultsManager = UserDefaultsManager.shared

    // MARK: - Initialization
    init(spotifyMonitor: SpotifyMonitor, lyricsService: LyricsService) {
        // Load saved frame or use default
        let frame = userDefaultsManager.loadWindowFrame()

        // Initialize window with saved/default frame
        super.init(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        setupWindow()

        // Create and set SwiftUI content view
        let lyricsView = LyricsView(
            spotifyMonitor: spotifyMonitor,
            lyricsService: lyricsService
        )

        // Wrap SwiftUI view in NSHostingView
        let hostingView = NSHostingView(rootView: lyricsView)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView

        // DON'T setup visual effect background - it breaks SwiftUI rendering
        // setupVisualEffectBackground()

        // Restore visibility state
        let shouldBeVisible = userDefaultsManager.loadWindowVisible()
        if shouldBeVisible {
            self.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Window Setup
    private func setupWindow() {
        // Set window title
        self.title = "Lyrics"

        // Always-on-top behavior
        self.level = .floating

        // Allow window to be movable by background
        self.isMovableByWindowBackground = true

        // Appearance
        self.backgroundColor = .clear
        self.isOpaque = false

        // Maintain aspect ratio option
        self.titlebarAppearsTransparent = false

        // Prevent tab bar
        self.tabbingMode = .disallowed

        // Set minimum size
        self.minSize = NSSize(width: 300, height: 400)

        // Register for frame change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    // MARK: - Visual Effect Background
    private func setupVisualEffectBackground() {
        // Create visual effect view for dark blur
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active

        // Add as background
        if let contentView = self.contentView {
            visualEffectView.frame = contentView.bounds
            visualEffectView.autoresizingMask = [.width, .height]
            contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
        }
    }

    // MARK: - Window Lifecycle
    override func close() {
        // Save visibility state as hidden
        userDefaultsManager.saveWindowVisible(false)
        super.close()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Frame Persistence
    @objc private func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        userDefaultsManager.saveWindowFrame(self.frame)
    }

    // MARK: - Visibility Management
    func show() {
        self.makeKeyAndOrderFront(nil)
        userDefaultsManager.saveWindowVisible(true)
    }

    func hide() {
        self.orderOut(nil)
        userDefaultsManager.saveWindowVisible(false)
    }

    func toggleVisibility() {
        if self.isVisible {
            hide()
        } else {
            show()
        }
    }
}

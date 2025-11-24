import AppKit
import SwiftUI
import Combine

/// Custom NSWindow subclass for always-on-top lyrics display
class LyricsWindow: NSWindow {

    // MARK: - Properties
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(spotifyMonitor: SpotifyMonitor, lyricsService: LyricsService) {
        // Load saved frame or use default
        let frame = settings.loadWindowFrame()

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
        let shouldBeVisible = settings.loadWindowVisible()
        if shouldBeVisible {
            self.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Window Setup
    private func setupWindow() {
        // Set window title
        self.title = "Lyrics"

        // Always-on-top behavior (based on settings)
        updateWindowLevel()

        // Allow window to be movable by background
        self.isMovableByWindowBackground = true

        // Appearance
        self.backgroundColor = .clear
        self.isOpaque = false

        // Opacity (based on settings)
        updateWindowOpacity()

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

        // Register for screen change notifications (display switching)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Observe settings changes
        observeSettings()
    }

    // MARK: - Settings Observation

    private func observeSettings() {
        // Observe any settings changes (fires after value is updated)
        settings.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Update window properties based on current settings
                self.updateWindowLevel()
                self.updateWindowOpacity()
            }
            .store(in: &cancellables)
    }

    private func updateWindowLevel() {
        // When "always on top" is enabled, use floating level (stays on top)
        // When disabled, use normal level (regular window behavior)
        self.level = settings.alwaysOnTop ? .floating : .normal
    }

    private func updateWindowOpacity() {
        self.alphaValue = CGFloat(settings.windowOpacity)
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
        settings.saveWindowVisible(false)
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
        settings.saveWindowFrame(self.frame)
    }

    @objc private func screenConfigurationDidChange(_ notification: Notification) {
        // Screen configuration changed (display switching, resolution change, etc.)
        // Re-establish window state to ensure keyboard shortcuts keep working
        if self.isVisible {
            // Small delay to let the system finish display reconfiguration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }

                // Re-order window to re-establish responder chain
                self.orderFront(nil)

                // Update window level in case display change affected it
                self.updateWindowLevel()
            }
        }
    }

    // MARK: - Visibility Management
    func show() {
        self.makeKeyAndOrderFront(nil)
        settings.saveWindowVisible(true)
    }

    func hide() {
        self.orderOut(nil)
        settings.saveWindowVisible(false)
    }

    func toggleVisibility() {
        if self.isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Window Behavior Overrides

    override var canBecomeKey: Bool {
        return true  // Allow window to become key for keyboard shortcuts
    }

    override var canBecomeMain: Bool {
        return true  // Allow window to become main
    }
}

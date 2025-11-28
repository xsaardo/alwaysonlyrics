import SwiftUI

@main
struct AlwaysOnLyricsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Don't use Settings scene - it creates a default preferences window
        // that intercepts Cmd+, and causes display identifier warnings
        // Instead, AppDelegate manages all windows manually
        WindowGroup {
            EmptyView()
        }
        .commands {
            // Remove default preferences command
            CommandGroup(replacing: .appSettings) { }
        }
    }
}

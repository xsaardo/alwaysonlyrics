# Claude Code Development Notes

This document captures key learnings, patterns, and insights from developing AlwaysOnLyrics with Claude Code.

## Project Overview

**AlwaysOnLyrics** is a macOS menu bar application that displays synchronized lyrics for currently playing Spotify tracks. The app features:
- Real-time Spotify monitoring via AppleScript/ScriptingBridge
- Lyrics fetching from Genius API
- Always-on-top floating lyrics window
- SwiftUI-based interface
- App Store compatibility (hybrid monitoring approach)

---

## Key Technical Learnings

### 1. App Store Compatibility Challenge

**Problem**: Initial implementation used timer-based polling with AppleScript, which conflicts with App Sandbox requirements for Mac App Store submission.

**Solution**: Hybrid approach combining two methods:
- **Event-driven updates**: `NSDistributedNotificationCenter` for real-time track changes
- **Initial state query**: ScriptingBridge for startup state (fallback to AppleScript)
- **Sandbox considerations**: Removed System Events dependency, only target Spotify directly

**Key Files**:
- `AlwaysOnLyrics/Services/SpotifyMonitor.swift:78` - Hybrid monitoring implementation
- `AlwaysOnLyrics/AlwaysOnLyrics.entitlements` - Sandbox and Apple Events configuration

**Learnings**:
- App Sandbox requires explicit entitlements for AppleScript automation
- `NSDistributedNotificationCenter` provides instant updates without polling
- ScriptingBridge offers better type safety than NSAppleScript
- Bridging headers needed for Objective-C Spotify framework integration

---

### 2. Dependency Injection for Testability

**Problem**: Tightly coupled networking and HTML parsing logic made testing difficult and required real API calls.

**Solution**: Refactored into protocol-based architecture with dependency injection:

```swift
// Before: Everything coupled together
class LyricsService {
    func fetchLyrics(...) {
        // Network + parsing + cleaning all mixed
    }
}

// After: Separated concerns with DI
class LyricsService {
    private let apiClient: GeniusAPIClientProtocol
    private let htmlParser: HTMLParser

    init(apiClient: GeniusAPIClientProtocol? = nil,
         htmlParser: HTMLParser? = nil) {
        self.apiClient = apiClient ?? GeniusAPIClient(...)
        self.htmlParser = htmlParser ?? GeniusHTMLParser()
    }
}
```

**Created Components**:
1. **HTTPClient.swift** - Protocol for HTTP operations, easily mockable
2. **GeniusAPIClient.swift** - API client protocol and implementation
3. **LyricsHTMLParser.swift** - Pure parsing logic, no network dependencies
4. **LyricsService.swift** - Orchestrator using injected dependencies

**Benefits**:
- Each component testable in isolation
- Mock implementations for fast unit tests
- Backward compatible (existing code works unchanged)
- Clear separation of concerns

**Key Insight**: Use optional parameters with default implementations for DI - allows production code to use defaults while tests inject mocks.

---

### 3. HTML Parsing: Regex → SwiftSoup

**Problem**: Regex-based HTML parsing was fragile, hard to maintain, and error-prone.

**Solution**: Migrated to SwiftSoup (Swift port of jsoup) using CSS selectors.

```swift
// Before: Complex regex patterns
let pattern = #"<div[^>]*class="[^"]*Lyrics__Container[^"]*"[^>]*>(.*?)</div>"#
let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
// ... complex matching logic

// After: Clean CSS selectors
let doc = try SwiftSoup.parse(html)
let containers = try doc.select("div[class*='Lyrics__Container']")
for container in containers.array() {
    let text = try container.html()
}
```

**Benefits**:
- Much more readable and maintainable
- Proper HTML parser handles edge cases
- jQuery-like syntax familiar to web developers
- Built-in HTML entity decoding
- Easier to debug and modify

**Setup**: Added via Swift Package Manager - `https://github.com/scinfu/SwiftSoup`

---

### 4. State Management with Combine

**Pattern**: Used `@Published` properties with Combine for reactive updates:

```swift
class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false

    private var cancellables = Set<AnyCancellable>()
}
```

**SwiftUI Integration**:
```swift
struct LyricsView: View {
    @ObservedObject var spotifyMonitor: SpotifyMonitor

    var body: some View {
        // Automatically updates when currentTrack changes
    }
}
```

**Key Learning**: Combine + SwiftUI provides clean reactive architecture with minimal boilerplate.

---

### 5. Async/Await for Network Operations

**Pattern**: Used modern Swift concurrency for clean async code:

```swift
func fetchLyrics(artist: String, songTitle: String) async throws -> String {
    // Search for song
    let songs = try await apiClient.searchSong(artist: artist, songTitle: songTitle)
    guard let song = songs.first else {
        throw LyricsError.songNotFound
    }

    // Fetch HTML
    let html = try await apiClient.fetchHTML(url: song.url)

    // Parse lyrics
    return try htmlParser.extractLyrics(from: html)
}
```

**Benefits**:
- No callback hell
- Clear error propagation with `throws`
- Easy to test with async test functions
- Readable sequential logic

---

### 6. Configuration Management

**Pattern**: Centralized config with example file for secrets:

```swift
// Config.swift
struct Config {
    static let geniusAccessToken: String = {
        // Try to load from config.json
        if let token = loadFromFile() { return token }
        // Fallback to hardcoded (for development)
        return ""
    }()
}
```

**Setup**:
- `config.example.json` - Template in repo
- `config.json` - Actual secrets (gitignored)
- Graceful fallback to environment or defaults

**Key Learning**: Never commit secrets; provide example files and graceful fallbacks.

---

## Architecture Patterns

### Separation of Concerns

The app follows clear layer separation:

```
┌─────────────────────────────────────┐
│          Views (SwiftUI)            │  ← Presentation
├─────────────────────────────────────┤
│     ObservableObjects/ViewModels    │  ← State Management
├─────────────────────────────────────┤
│          Services Layer             │  ← Business Logic
│  - SpotifyMonitor                   │
│  - LyricsService                    │
├─────────────────────────────────────┤
│        Protocol Abstractions        │  ← Testability
│  - HTTPClient                       │
│  - GeniusAPIClientProtocol          │
│  - HTMLParser                       │
├─────────────────────────────────────┤
│       External Dependencies         │  ← Implementation
│  - URLSession                       │
│  - SwiftSoup                        │
│  - ScriptingBridge                  │
└─────────────────────────────────────┘
```

### File Organization

```
AlwaysOnLyrics/
├── AlwaysOnLyricsApp.swift      # Entry point
├── AppDelegate.swift             # Menu bar setup
├── Models/                       # Data structures
│   ├── Track.swift
│   └── GeniusSong.swift
├── Services/                     # Business logic
│   ├── SpotifyMonitor.swift
│   ├── LyricsService.swift
│   ├── HTTPClient.swift
│   ├── GeniusAPIClient.swift
│   └── LyricsHTMLParser.swift
├── Views/                        # SwiftUI views
│   ├── LyricsWindow.swift
│   └── LyricsView.swift
└── Utilities/                    # Helpers
    ├── HTMLCleaner.swift
    └── UserDefaultsManager.swift
```

---

## Development Workflow Best Practices

### 1. Incremental Refactoring

**Lesson**: Make changes incrementally with clear documentation:
- Create new abstractions alongside old code
- Use dependency injection with defaults for backward compatibility
- Test after each change
- Document in markdown files (REFACTORING_SUMMARY.md, SWIFTSOUP_MIGRATION.md)

### 2. Testing Without Tests

**Approach**: Created standalone test scripts for rapid iteration:
- `test_lyrics_service.swift` - Quick testing of LyricsService
- `run_lyrics_test.sh` - Shell script to compile and run tests
- Allowed testing without full Xcode test target setup

**Command**: `swift test_lyrics_service.swift` for instant feedback

### 3. Documentation-Driven Development

**Pattern**: Document before/during implementation:
- `SPECS.md` - Initial feature specifications
- `REFACTORING_SUMMARY.md` - Architecture changes
- `SWIFTSOUP_MIGRATION.md` - Migration guides
- `CLAUDE.md` - Development learnings (this file)

**Benefit**: Clear reference for future changes and context for Claude Code.

---

## Common Pitfalls & Solutions

### Pitfall 1: AppleScript Permissions

**Issue**: AppleScript fails silently if automation permissions not granted.

**Solution**:
- Clear DEBUG logging to guide users
- Graceful fallback to notification-only mode
- Documentation about System Preferences setup

### Pitfall 2: SwiftUI State Updates on Background Threads

**Issue**: Network callbacks updating @Published properties from background threads cause crashes.

**Solution**:
```swift
Task { @MainActor in
    self.currentTrack = newTrack  // Update on main thread
}
```

### Pitfall 3: Retain Cycles with Closures

**Issue**: Closures capturing `self` strongly can create retain cycles.

**Solution**:
```swift
NotificationCenter.default.addObserver(forName: ...) { [weak self] notification in
    self?.handleNotification(notification)
}
```

### Pitfall 4: HTML Structure Changes

**Issue**: Genius website HTML structure can change, breaking selectors.

**Solution**:
- Use flexible selectors (`div[class*='Lyrics__Container']` vs exact match)
- Add fallback parsing strategies
- Log parse failures for debugging

---

## Swift/macOS Specific Learnings

### 1. Menu Bar Apps

**Configuration**: `Info.plist` setting:
```xml
<key>LSUIElement</key>
<true/>
```
This hides the dock icon and makes it menu-bar-only.

### 2. Always-on-Top Windows

**Pattern**:
```swift
window.level = .floating  // Always on top
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

### 3. ScriptingBridge Setup

**Steps**:
1. Create bridging header (`Spotify.h`)
2. Generate with: `sdef /Applications/Spotify.app | sdp -fh --basename Spotify`
3. Add to Build Settings: Objective-C Bridging Header
4. Import in Swift: Bridge automatically handles it

### 4. Swift Package Manager in Xcode

**Adding Dependencies**:
1. Project settings → Target → Package Dependencies
2. Add package by URL
3. Select version (use "Up to Next Major")
4. Import in code: `import SwiftSoup`

---

## Performance Considerations

### 1. Polling vs Event-Driven

**Finding**: NSDistributedNotificationCenter is instant vs 1-2s polling delay.

**Trade-off**: Notifications don't provide initial state, so hybrid approach needed.

### 2. HTML Parsing Performance

**Finding**: SwiftSoup parsing is fast enough for real-time use (<100ms typical).

**Optimization**: No caching needed for MVP, but could add in future.

### 3. Memory Management

**Practice**: Properly cancelling Combine subscriptions:
```swift
private var cancellables = Set<AnyCancellable>()

deinit {
    cancellables.forEach { $0.cancel() }
}
```

---

## Testing Strategy

### Unit Testing Approach

**Components Ready for Testing**:
1. **GeniusHTMLParser** - Pure function, no dependencies
2. **HTTPClient implementations** - Mock URLSession
3. **GeniusAPIClient** - Mock HTTPClient
4. **LyricsService** - Mock both API client and parser

**Test Structure**:
```swift
func testLyricsExtraction() {
    let parser = GeniusHTMLParser()
    let mockHTML = "<div class='Lyrics__Container'>Test lyrics</div>"
    let result = try parser.extractLyrics(from: mockHTML)
    XCTAssertEqual(result, "Test lyrics")
}
```

### Integration Testing

**Approach**: Standalone Swift scripts for quick validation:
- Test against real Genius API
- Verify HTML parsing with live data
- Check Spotify integration manually

---

## Future Improvements

### Technical Debt
- [ ] Add comprehensive unit tests
- [ ] Implement lyrics caching (avoid repeated API calls)
- [ ] Error recovery mechanisms (retry logic)
- [ ] Metrics/telemetry for API success rates

### Features
- [ ] Manual lyrics search UI
- [ ] Multiple lyrics providers with fallback (Musixmatch, AZLyrics)
- [ ] Synced lyrics with auto-scrolling
- [ ] Customization (themes, fonts, opacity)
- [ ] Apple Music support

### App Store Preparation
- [ ] App signing and notarization
- [ ] Sandboxing verification
- [ ] Privacy policy
- [ ] App Store screenshots and description
- [ ] Beta testing via TestFlight

---

## Claude Code Slash Commands

Custom workflows created for this project:

- **`/commit`** - Review changes and create commit with proper message
- **`/code-review`** - Review unstaged changes with Swift best practices focus
- **`/feature`** - Full feature development workflow (requirements → spec → plan → todo → implementation)
- **`/frontend`** - UI/UX development workflow (design → spec → SwiftUI implementation)
- **`/cleanup`** - Identify and remove unnecessary code/files

**Location**: `.claude/commands/`

---

## Key Takeaways

1. **Start with working code, refactor incrementally** - Don't over-engineer upfront
2. **Protocol-based DI enables testability** - Abstract dependencies behind protocols
3. **Document as you go** - Future you (and Claude) will thank you
4. **SwiftUI + Combine = Clean reactive code** - Embrace modern Swift patterns
5. **App Store compatibility requires planning** - Sandbox restrictions impact architecture
6. **CSS selectors > Regex for HTML** - Use proper parsers, not string manipulation
7. **Async/await simplifies async code** - Embrace Swift concurrency
8. **Always have fallback strategies** - External dependencies (APIs, HTML) can break

---

## Resources

### Documentation Created
- `SPECS.md` - Original MVP specifications
- `REFACTORING_SUMMARY.md` - Dependency injection refactoring
- `SWIFTSOUP_MIGRATION.md` - HTML parsing migration guide
- `CLAUDE.md` - This file

### External Resources
- [SwiftSoup Documentation](https://github.com/scinfu/SwiftSoup)
- [Genius API Documentation](https://docs.genius.com/)
- [Apple ScriptingBridge Guide](https://developer.apple.com/documentation/scriptingbridge)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

*Document last updated: 2025-11-05*
*Project: AlwaysOnLyrics v1.0 (App Store Compatibility Branch)*
- when trying to verify if the project builds, defer to the user to run it from xcode
# Testing Plan for AlwaysOnLyrics

## Overview

This document outlines testing strategies and standards for AlwaysOnLyrics, a macOS menu bar application for displaying synchronized lyrics.

**Created:** 2025-11-23
**App Type:** macOS Menu Bar Application (AppKit + SwiftUI)
**Primary Functions:** Spotify monitoring, lyrics fetching, real-time display

---

## Testing Standards for macOS Apps

### Industry Standards

**Apple's Guidelines:**
- XCTest framework for unit and UI tests
- Test coverage should focus on business logic and critical paths
- UI tests for key user workflows
- Performance testing for responsiveness

**Common Practices:**
- **Unit tests:** 60-80% coverage for business logic
- **Integration tests:** Critical external integrations
- **UI tests:** Core user flows only (expensive to maintain)
- **Manual testing:** Edge cases and user experience

**Code Quality Metrics:**
- Maintain test coverage above 70% for core logic
- All public API methods should have tests
- Critical bug fixes should include regression tests

---

## Testing Pyramid for AlwaysOnLyrics

```
                    /\
                   /  \
                  /    \        Manual Testing (10%)
                 /------\       - Edge cases
                /        \      - Display switching
               /          \     - UX validation
              /------------\
             /              \   UI Tests (20%)
            /                \  - Settings changes
           /                  \ - Window interactions
          /--------------------\
         /                      \
        /      Integration (30%) \
       /        - API calls       \
      /         - AppleScript      \
     /          - Position tracking \
    /------------------------------\
   /                                \
  /        Unit Tests (40%)          \
 /         - LRC parser               \
/          - Data models               \
/          - Business logic            \
/____________________________________\
```

---

## Test Categories

### 1. Unit Tests (High Priority)

Test individual components in isolation with mocked dependencies.

#### **LRC Parser** (`LRCParser.swift`)
```swift
class LRCParserTests: XCTestCase {
    var parser: LRCParser!

    override func setUp() {
        parser = LRCParser()
    }

    func testParseValidLRC() {
        let lrc = """
        [00:12.00]First line
        [00:17.50]Second line
        """
        let result = parser.parse(lrc)
        XCTAssertEqual(result.lines.count, 2)
        XCTAssertEqual(result.lines[0].timestamp, 12.0)
        XCTAssertEqual(result.lines[0].text, "First line")
    }

    func testParseTimestampWithoutMilliseconds() {
        let lrc = "[01:30]Line without ms"
        let result = parser.parse(lrc)
        XCTAssertEqual(result.lines[0].timestamp, 90.0)
    }

    func testParseEmptyLines() {
        let lrc = "[00:12.00]\n[00:15.00]Text"
        let result = parser.parse(lrc)
        XCTAssertEqual(result.lines.count, 1) // Empty line ignored
    }

    func testParseMalformedInput() {
        let lrc = "Invalid text without timestamps"
        let result = parser.parse(lrc)
        XCTAssertTrue(result.lines.isEmpty)
    }

    func testParseLinesSortedByTimestamp() {
        let lrc = "[00:20.00]Second\n[00:10.00]First"
        let result = parser.parse(lrc)
        XCTAssertEqual(result.lines[0].text, "First")
    }
}
```

**Coverage Goals:**
- ✅ Valid LRC format
- ✅ Timestamps with/without milliseconds
- ✅ Empty lines
- ✅ Malformed input
- ✅ Sorting behavior
- ✅ Edge cases (very long timestamps, special characters)

---

#### **SyncedLyrics Model** (`SyncedLyrics.swift`)
```swift
class SyncedLyricsTests: XCTestCase {
    func testCurrentLineAtPosition() {
        let lines = [
            LyricLine(timestamp: 10.0, text: "Line 1"),
            LyricLine(timestamp: 20.0, text: "Line 2"),
            LyricLine(timestamp: 30.0, text: "Line 3")
        ]
        let lyrics = SyncedLyrics(lines: lines)

        XCTAssertEqual(lyrics.currentLine(at: 5.0)?.text, nil) // Before first line
        XCTAssertEqual(lyrics.currentLine(at: 15.0)?.text, "Line 1")
        XCTAssertEqual(lyrics.currentLine(at: 25.0)?.text, "Line 2")
        XCTAssertEqual(lyrics.currentLine(at: 100.0)?.text, "Line 3") // After last
    }

    func testCurrentLineIndex() {
        // Test index lookup is correct
    }

    func testEmptyLyrics() {
        let lyrics = SyncedLyrics(lines: [])
        XCTAssertNil(lyrics.currentLine(at: 10.0))
    }
}
```

---

#### **AppSettings** (`AppSettings.swift`)
```swift
class AppSettingsTests: XCTestCase {
    var settings: AppSettings!

    override func setUp() {
        // Use a test UserDefaults suite to avoid affecting real settings
        let defaults = UserDefaults(suiteName: "com.test.alwaysonlyrics")!
        defaults.removePersistentDomain(forName: "com.test.alwaysonlyrics")
        // Inject test defaults into AppSettings (requires refactoring)
    }

    func testDefaultValues() {
        XCTAssertTrue(settings.alwaysOnTop)
        XCTAssertEqual(settings.windowOpacity, 0.95)
        XCTAssertEqual(settings.fontSize, 14.0)
    }

    func testSettingsPersistence() {
        settings.fontSize = 18.0
        // Verify it's saved to UserDefaults
    }

    func testResetToDefaults() {
        settings.fontSize = 20.0
        settings.resetToDefaults()
        XCTAssertEqual(settings.fontSize, 14.0)
    }
}
```

---

### 2. Integration Tests (Medium Priority)

Test interactions between components with real or stubbed external dependencies.

#### **LyricsService** (`LyricsService.swift`)
```swift
class LyricsServiceTests: XCTestCase {
    var service: LyricsService!
    var mockAPIClient: MockLRCLIBAPIClient!

    override func setUp() {
        mockAPIClient = MockLRCLIBAPIClient()
        service = LyricsService(apiClient: mockAPIClient)
    }

    func testFetchSyncedLyrics_Success() async throws {
        // Mock API returns valid LRC data
        mockAPIClient.mockResponse = LRCLIBTrack(
            id: 1,
            trackName: "Test Song",
            artistName: "Test Artist",
            albumName: "Test Album",
            duration: 180.0,
            instrumental: false,
            plainLyrics: "Plain text",
            syncedLyrics: "[00:10.00]Test line"
        )

        let result = try await service.fetchSyncedLyrics(
            artist: "Test Artist",
            songTitle: "Test Song",
            album: "Test Album",
            duration: 180
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lines.count, 1)
    }

    func testFetchSyncedLyrics_Instrumental() async {
        mockAPIClient.mockResponse = LRCLIBTrack(
            /* instrumental: true */
        )

        do {
            _ = try await service.fetchSyncedLyrics(...)
            XCTFail("Should throw instrumental error")
        } catch LyricsError.instrumental {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func testFetchSyncedLyrics_NoSyncedAvailable() async throws {
        // Returns plain but no synced
        mockAPIClient.mockResponse = LRCLIBTrack(
            syncedLyrics: nil
        )

        let result = try await service.fetchSyncedLyrics(...)
        XCTAssertNil(result) // Should return nil, not error
    }

    func testFetchSyncedLyrics_NetworkError() async {
        mockAPIClient.shouldThrowError = true

        do {
            _ = try await service.fetchSyncedLyrics(...)
            XCTFail("Should throw error")
        } catch {
            // Expected
        }
    }
}

// Mock API Client for testing
class MockLRCLIBAPIClient: LRCLIBAPIClientProtocol {
    var mockResponse: LRCLIBTrack?
    var shouldThrowError = false

    func getLyrics(...) async throws -> LRCLIBTrack {
        if shouldThrowError {
            throw LRCLIBAPIError.networkError
        }
        return mockResponse!
    }

    func searchLyrics(...) async throws -> [LRCLIBTrack] {
        return []
    }
}
```

**Coverage Goals:**
- ✅ Successful fetch with synced lyrics
- ✅ Instrumental tracks
- ✅ No synced lyrics available (fallback)
- ✅ Network errors
- ✅ Track not found
- ✅ Malformed API response

---

#### **SpotifyMonitor Position Tracking**

These tests are harder to unit test due to AppleScript dependencies. Consider:

**Option 1: Extract AppleScript logic into protocol**
```swift
protocol SpotifyScriptingProtocol {
    func getCurrentPosition() -> Double?
    func getCurrentTrack() -> Track?
}

class SpotifyMonitor {
    private let scripting: SpotifyScriptingProtocol

    init(scripting: SpotifyScriptingProtocol = RealSpotifyScripting()) {
        self.scripting = scripting
    }
}

// Mock for testing
class MockSpotifyScripting: SpotifyScriptingProtocol {
    var mockPosition: Double = 0.0
    var mockTrack: Track?

    func getCurrentPosition() -> Double? { mockPosition }
    func getCurrentTrack() -> Track? { mockTrack }
}
```

**Tests:**
```swift
class SpotifyMonitorTests: XCTestCase {
    func testPositionTrackingUpdateFrequency() {
        // Verify timer fires at expected rate
    }

    func testPositionSyncCorrectsDrift() {
        // Simulate drift and verify sync corrects it
    }

    func testPauseStopsTracking() {
        // Verify timers stop when paused
    }
}
```

**Note:** Full testing requires either:
- Mocking AppleScript layer (recommended)
- Running integration tests with actual Spotify (slow, brittle)

---

### 3. UI Tests (Low-Medium Priority)

Test critical user flows end-to-end. UI tests are expensive to maintain, so focus on core workflows.

#### **Settings Changes**
```swift
class SettingsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        app = XCUIApplication()
        app.launch()
    }

    func testChangeFontSize() {
        // Open preferences
        app.menuItems["Preferences..."].click()

        // Change font size slider
        let slider = app.sliders["Font size"]
        slider.adjust(toNormalizedSliderPosition: 0.8)

        // Verify lyrics view updates (hard to test without Spotify running)
        // Alternative: verify setting is persisted
    }

    func testToggleSyncedLyrics() {
        app.menuItems["Preferences..."].click()
        app.checkBoxes["Show synced lyrics when available"].click()

        // Verify setting changed
        XCTAssertFalse(app.checkBoxes["Show synced lyrics when available"].isSelected)
    }
}
```

**Coverage Goals:**
- ✅ Open/close preferences window
- ✅ Change all settings
- ✅ Toggle lyrics window visibility
- ✅ Window resizing/moving persists

**Challenges:**
- Requires Spotify to be running for realistic tests
- Timing issues with async operations
- Hard to verify lyrics display without OCR

---

### 4. Manual Testing (High Priority)

Some scenarios are best tested manually due to complexity or external dependencies.

#### **Critical Manual Test Cases**

**A. Spotify Integration**
- [ ] App launches when Spotify is already playing
- [ ] App launches when Spotify is paused
- [ ] App launches when Spotify is not running
- [ ] Track changes while app is running
- [ ] Pause/resume updates position correctly
- [ ] Seeking in Spotify updates lyrics position
- [ ] Switching Spotify accounts

**B. Display Switching** (See SYNCED_LYRICS_PLAN.md)
- [ ] Move window between displays
- [ ] Connect/disconnect external monitors
- [ ] Change display resolution
- [ ] Keyboard shortcuts work after display change

**C. Synced Lyrics**
- [ ] Rapid-fire lyrics scroll smoothly
- [ ] Sparse lyrics don't drift
- [ ] Long tracks stay in sync (5+ minutes)
- [ ] Manual scrolling disables auto-scroll
- [ ] "Snap to Current" button works
- [ ] Paused tracks show correct line
- [ ] Opacity states are visually distinct

**D. Settings**
- [ ] All settings persist after app restart
- [ ] Changes apply immediately to open window
- [ ] Reset to defaults works
- [ ] Launch at login works (macOS 13+)

**E. Edge Cases**
- [ ] No internet connection (cached lyrics?)
- [ ] LRCLIB API down
- [ ] Podcasts/audiobooks (no lyrics)
- [ ] Instrumental tracks
- [ ] Very long track names (truncation)
- [ ] Special characters in lyrics (emoji, Unicode)

**F. Performance**
- [ ] CPU usage < 5% during playback
- [ ] Memory stable over long sessions (no leaks)
- [ ] UI remains responsive during lyrics fetch
- [ ] No jank during auto-scroll

---

## Testing Frameworks & Tools

### Built-in Apple Frameworks

**XCTest** - Apple's native testing framework
- Unit tests
- Performance tests
- UI tests
- Asynchronous testing support (async/await)

**Usage:**
```bash
# Run all tests
xcodebuild test -scheme AlwaysOnLyrics

# Run specific test
xcodebuild test -scheme AlwaysOnLyrics -only-testing:LRCParserTests/testParseValidLRC
```

---

### Third-Party Tools (Optional)

**Quick/Nimble** - BDD-style testing
```swift
import Quick
import Nimble

class LRCParserSpec: QuickSpec {
    override func spec() {
        describe("LRCParser") {
            context("when parsing valid LRC") {
                it("returns correct line count") {
                    let parser = LRCParser()
                    let result = parser.parse("[00:10.00]Test")
                    expect(result.lines.count).to(equal(1))
                }
            }
        }
    }
}
```

**SwiftLint** - Code quality and style
- Enforce consistent style
- Catch common mistakes
- Integrate with CI/CD

**Instruments** - Performance profiling
- Memory leaks
- CPU usage
- Time profiling

---

## What NOT to Test

### Over-Testing Anti-Patterns

**Don't test:**
- ❌ SwiftUI view rendering (trust Apple's framework)
- ❌ Third-party library internals (LRCLIB API response format)
- ❌ Apple framework behavior (UserDefaults, NSWindow)
- ❌ Generated code (SwiftUI previews)
- ❌ Trivial getters/setters
- ❌ Private implementation details

**Do test:**
- ✅ Business logic
- ✅ Data transformations
- ✅ Complex algorithms (LRC parsing)
- ✅ Integration points
- ✅ Critical user flows

---

## Test Organization

### Recommended Structure

```
AlwaysOnLyricsTests/
├── Unit/
│   ├── Models/
│   │   ├── LyricLineTests.swift
│   │   ├── SyncedLyricsTests.swift
│   │   └── TrackTests.swift
│   ├── Services/
│   │   ├── LRCParserTests.swift
│   │   ├── LyricsServiceTests.swift
│   │   └── SpotifyMonitorTests.swift
│   └── Utilities/
│       └── AppSettingsTests.swift
├── Integration/
│   ├── LyricsServiceIntegrationTests.swift
│   └── SpotifyMonitorIntegrationTests.swift
└── Mocks/
    ├── MockLRCLIBAPIClient.swift
    ├── MockSpotifyScripting.swift
    └── MockHTTPClient.swift

AlwaysOnLyricsUITests/
├── SettingsUITests.swift
├── WindowUITests.swift
└── LyricsDisplayUITests.swift
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -scheme AlwaysOnLyrics \
            -destination 'platform=macOS' \
            -only-testing:AlwaysOnLyricsTests/Unit

      - name: Run Integration Tests
        run: |
          xcodebuild test \
            -scheme AlwaysOnLyrics \
            -destination 'platform=macOS' \
            -only-testing:AlwaysOnLyricsTests/Integration

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
```

**Note:** UI tests are typically NOT run in CI due to:
- Slow execution time
- Flakiness
- Require GUI environment
- May need Spotify installed

---

## Coverage Goals

### Recommended Targets

| Component | Target Coverage | Priority |
|-----------|----------------|----------|
| LRCParser | 90%+ | High |
| SyncedLyrics | 85%+ | High |
| LyricsService | 80%+ | High |
| AppSettings | 70%+ | Medium |
| SpotifyMonitor | 60%+ | Medium (hard to test) |
| Views | 30%+ | Low (manual testing) |
| **Overall** | **70%+** | - |

---

## Test-Driven Development (TDD)

### When to Use TDD

**Good candidates for TDD:**
- ✅ LRC parser (clear inputs/outputs)
- ✅ Timestamp calculations
- ✅ Data model methods
- ✅ Bug fixes (write failing test first)

**Not suited for TDD:**
- ❌ UI layout and styling
- ❌ Exploratory features
- ❌ Rapid prototyping
- ❌ External integrations (require experimentation)

---

## Testing Checklist for New Features

Before merging a PR:

- [ ] Unit tests for business logic (coverage > 70%)
- [ ] Integration tests for external APIs
- [ ] Manual testing of UI changes
- [ ] Performance testing if applicable
- [ ] Regression testing of related features
- [ ] Test with Spotify playing/paused/not running
- [ ] Test on different macOS versions (if applicable)
- [ ] Update TESTING_PLAN.md if new test areas added

---

## Current State

### Existing Tests

Currently, AlwaysOnLyrics has **no automated tests**.

**Debt:**
- No unit tests
- No integration tests
- No UI tests
- Manual testing only

### Quick Wins (High ROI Tests)

If implementing tests, start here:

**Priority 1: LRC Parser**
- Small, pure functions
- No external dependencies
- High complexity, high risk
- Quick to write, fast to run

**Priority 2: SyncedLyrics Model**
- Clear test cases
- Core functionality
- Medium complexity

**Priority 3: LyricsService (with mocks)**
- Critical path
- Already has protocol abstraction
- Mock API client easy to implement

---

## Resources

### Apple Documentation
- [XCTest - Apple Developer](https://developer.apple.com/documentation/xctest)
- [Testing Your Apps in Xcode](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)
- [Writing Testable Code](https://developer.apple.com/documentation/xcode/writing-testable-code)

### Community Resources
- [Swift Testing Best Practices](https://www.swiftbysundell.com/articles/testing-swift-code/)
- [iOS Unit Testing by Example](https://www.vadimbulavin.com/unit-testing-best-practices-on-ios-with-swift/)

### Books
- *Test Driven Development: By Example* - Kent Beck
- *Working Effectively with Legacy Code* - Michael Feathers

---

## Next Steps

### Immediate Actions
1. Review this testing plan
2. Decide on coverage goals for v1.0
3. Create test target in Xcode (if implementing tests)
4. Start with LRC parser tests (highest ROI)

### Long-term
1. Add tests incrementally as features are developed
2. Set up CI/CD with test automation
3. Integrate code coverage reporting
4. Establish testing culture for new PRs

---

**Last Updated:** 2025-11-23
**Status:** Planning Phase
**Next Review:** After implementing first test suite

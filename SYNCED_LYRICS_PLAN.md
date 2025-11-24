# Synced Lyrics Feature - Implementation Plan

## Overview

Implement Spotify-style synchronized lyrics with auto-scrolling and visual highlighting. This feature will display timestamped lyrics that follow along with the currently playing track.

**Created:** 2025-11-22
**Status:** Planning

---

## User Experience Requirements

### Visual Design (Spotify-style)
- **Past lyrics**: Dimmed opacity (40%)
- **Current line**: Full brightness (100%) - highlighted
- **Future lyrics**: Medium brightness (70%)
- **Auto-scroll**: Keep current line centered in window
- **Smooth animations**: Fade transitions between states

### User Interaction
- Auto-scroll is **enabled by default** when track starts
- User manually scrolling → **pause auto-scroll**
- When auto-scroll paused → show **"Snap to Current" button**
- Clicking button → re-enable auto-scroll and jump to current line
- Setting to enable/disable synced lyrics globally

---

## Technical Approach: Hybrid Timer + Periodic Sync

### Position Tracking Strategy

We'll use **Option 4** from our brainstorming:
- Local timer for smooth UI updates (high frequency)
- Periodic AppleScript sync to correct drift (every 3 seconds)
- Event-driven resets on track changes

```swift
// High-level flow
1. Spotify notification → Track changed
2. Query initial position via AppleScript
3. Start local Timer (updates 10-20 Hz)
4. Every 3 seconds → Sync with Spotify via AppleScript
5. User scrolls → Pause auto-scroll (keep timer running)
6. Track pauses → Pause timer
7. Track resumes → Resume timer from synced position
```

### Why This Approach?

**Pros:**
- ✅ Smooth scrolling (local timer at high frequency)
- ✅ Stays accurate (periodic sync prevents drift)
- ✅ Handles user seeks (detected during sync)
- ✅ Efficient (minimal AppleScript overhead)
- ✅ Best user experience

**Cons:**
- More complex than pure polling
- Requires drift correction logic

---

## Architecture & Components

### 1. Data Models

#### LyricLine (new model)
```swift
// File: AlwaysOnLyrics/Models/LyricLine.swift

import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: UUID = UUID()
    let timestamp: Double  // Time in seconds
    let text: String

    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.text == rhs.text
    }
}
```

#### SyncedLyrics (new model)
```swift
// File: AlwaysOnLyrics/Models/SyncedLyrics.swift

import Foundation

struct SyncedLyrics {
    let lines: [LyricLine]

    /// Find the currently active lyric line at given playback position
    func currentLine(at position: Double) -> LyricLine? {
        // Find the last line whose timestamp <= position
        return lines
            .filter { $0.timestamp <= position }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Find the index of the current line
    func currentLineIndex(at position: Double) -> Int? {
        guard let current = currentLine(at: position) else { return nil }
        return lines.firstIndex(of: current)
    }

    /// Check if lyrics are available
    var isEmpty: Bool {
        return lines.isEmpty
    }
}
```

#### Track Model Updates
```swift
// File: AlwaysOnLyrics/Models/Track.swift

struct Track: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: Int? // Duration in seconds
    let artworkURL: String?
    let isPlaying: Bool
    let playbackPosition: Double? // NEW: Current position in seconds

    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.title == rhs.title &&
               lhs.artist == rhs.artist &&
               lhs.album == rhs.album
    }
}
```

---

### 2. LRC Parser

LRC (Lyric file) format example:
```
[00:12.00]First line of lyrics
[00:17.50]Second line of lyrics
[00:23.00]Third line of lyrics
[01:05.25]Another line here
```

**LRCParser Implementation:**

```swift
// File: AlwaysOnLyrics/Services/LRCParser.swift

import Foundation

class LRCParser {

    /// Parse LRC format string into SyncedLyrics
    /// - Parameter lrcString: LRC format lyrics with timestamps
    /// - Returns: SyncedLyrics object with parsed lines
    func parse(_ lrcString: String) -> SyncedLyrics {
        var lyricLines: [LyricLine] = []

        let lines = lrcString.components(separatedBy: .newlines)

        for line in lines {
            // Match pattern: [mm:ss.xx]text or [mm:ss]text
            guard let timestamp = extractTimestamp(from: line),
                  let text = extractText(from: line),
                  !text.isEmpty else {
                continue
            }

            lyricLines.append(LyricLine(timestamp: timestamp, text: text))
        }

        // Sort by timestamp (should already be sorted, but ensure it)
        lyricLines.sort { $0.timestamp < $1.timestamp }

        return SyncedLyrics(lines: lyricLines)
    }

    /// Extract timestamp from LRC line
    /// [00:12.00] -> 12.0 seconds
    private func extractTimestamp(from line: String) -> Double? {
        // Pattern: [mm:ss.xx] or [mm:ss]
        let pattern = "\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        // Extract minutes and seconds
        guard let minutesRange = Range(match.range(at: 1), in: line),
              let secondsRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let minutes = Double(line[minutesRange]) ?? 0
        let seconds = Double(line[secondsRange]) ?? 0

        return minutes * 60 + seconds
    }

    /// Extract lyric text from LRC line
    /// [00:12.00]Some text -> "Some text"
    private func extractText(from line: String) -> String? {
        // Pattern: extract text after ]
        let pattern = "\\](.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let textRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        return String(line[textRange]).trimmingCharacters(in: .whitespaces)
    }
}
```

---

### 3. SpotifyMonitor Updates

Add playback position tracking with hybrid timer approach.

```swift
// File: AlwaysOnLyrics/Services/SpotifyMonitor.swift

class SpotifyMonitor: ObservableObject {
    @Published var currentTrack: Track?
    @Published var spotifyRunning: Bool = false
    @Published var playbackPosition: Double = 0.0  // NEW

    private var positionTimer: Timer?  // High-frequency local timer
    private var syncTimer: Timer?      // Periodic sync timer (every 3 seconds)
    private var lastSyncedPosition: Double = 0.0
    private var lastSyncTime: Date?

    // MARK: - Position Tracking

    /// Start tracking playback position
    func startPositionTracking() {
        stopPositionTracking()  // Clean up existing timers

        // Sync immediately to get accurate starting position
        Task {
            await syncPlaybackPosition()
        }

        // Start local timer for smooth updates (15 Hz = every ~67ms)
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.067, repeats: true) { [weak self] _ in
            self?.updateLocalPosition()
        }

        // Start sync timer (every 3 seconds)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task {
                await self?.syncPlaybackPosition()
            }
        }
    }

    /// Stop tracking playback position
    func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil

        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Update local position estimate (called by high-frequency timer)
    @objc private func updateLocalPosition() {
        guard let lastSyncTime = lastSyncTime,
              currentTrack?.isPlaying == true else {
            return
        }

        // Calculate elapsed time since last sync
        let elapsed = Date().timeIntervalSince(lastSyncTime)

        // Estimate current position
        let estimatedPosition = lastSyncedPosition + elapsed

        DispatchQueue.main.async {
            self.playbackPosition = estimatedPosition
        }
    }

    /// Sync playback position with Spotify via AppleScript
    func syncPlaybackPosition() async {
        guard let position = getSpotifyPlaybackPosition() else {
            return
        }

        DispatchQueue.main.async {
            self.lastSyncedPosition = position
            self.lastSyncTime = Date()
            self.playbackPosition = position
        }
    }

    /// Get current playback position from Spotify via AppleScript
    private func getSpotifyPlaybackPosition() -> Double? {
        let script = """
        tell application "Spotify"
            if it is running then
                try
                    set pos to player position
                    return pos
                on error errMsg
                    return ""
                end try
            else
                return ""
            end if
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            return nil
        }

        guard let positionValue = result.doubleValue else {
            return nil
        }

        return positionValue
    }

    // MARK: - Existing notification handler updates

    @objc private func handleSpotifyNotification(_ notification: Notification) {
        // ... existing code ...

        // NEW: Handle play/pause state changes
        let isPlaying = (playerStateString == "Playing")

        if isPlaying {
            startPositionTracking()
        } else {
            stopPositionTracking()
        }

        // ... rest of existing code ...
    }
}
```

---

### 4. AppSettings Updates

Add setting to enable/disable synced lyrics.

```swift
// File: AlwaysOnLyrics/Models/AppSettings.swift

class AppSettings: ObservableObject {
    // ... existing properties ...

    // MARK: - Lyrics Settings

    var enableSyncedLyrics: Bool {
        get { _enableSyncedLyrics }
        set {
            objectWillChange.send()
            _enableSyncedLyrics = newValue
            defaults.set(newValue, forKey: "enableSyncedLyrics")
        }
    }
    private var _enableSyncedLyrics: Bool = true

    // MARK: - Initialization updates

    private init() {
        // ... existing initialization ...

        if let saved = defaults.object(forKey: "enableSyncedLyrics") as? Bool {
            _enableSyncedLyrics = saved
        }

        isInitialized = true
    }

    // MARK: - Reset to defaults updates

    func resetToDefaults() {
        // ... existing resets ...
        enableSyncedLyrics = true
    }
}
```

---

### 5. PreferencesWindow Updates

Add UI toggle for synced lyrics setting.

```swift
// File: AlwaysOnLyrics/Views/PreferencesWindow.swift

struct PreferencesWindow: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    windowBehaviorSection
                }

                Section {
                    appearanceSection
                }

                Section {
                    lyricsSection  // NEW
                }

                Section {
                    generalSection
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 520)  // Increased height for new section
    }

    // MARK: - Lyrics Section (NEW)

    private var lyricsSection: some View {
        Group {
            Text("Lyrics")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)

            Toggle("Show synced lyrics when available", isOn: $settings.enableSyncedLyrics)
                .help("Display time-synchronized lyrics that highlight and scroll automatically")

            Text("When disabled, plain text lyrics will be displayed")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
    }
}
```

---

### 6. LyricsService Updates

Update to fetch and return synced lyrics when available.

```swift
// File: AlwaysOnLyrics/Services/LyricsService.swift

class LyricsService {
    private let apiClient: LRCLIBAPIClientProtocol
    private let lrcParser = LRCParser()

    // ... existing init ...

    /// Fetch synced lyrics if available and enabled
    /// - Returns: SyncedLyrics object, or nil if not available
    func fetchSyncedLyrics(artist: String,
                          songTitle: String,
                          album: String,
                          duration: Int?) async throws -> SyncedLyrics? {
        do {
            let track = try await apiClient.getLyrics(
                artist: artist,
                trackName: songTitle,
                albumName: album,
                duration: duration
            )

            // Check if synced lyrics available
            guard let syncedLyricsString = track.syncedLyrics,
                  !syncedLyricsString.isEmpty else {
                return nil
            }

            // Parse LRC format
            let syncedLyrics = lrcParser.parse(syncedLyricsString)

            return syncedLyrics.isEmpty ? nil : syncedLyrics

        } catch {
            // If synced fetch fails, caller can fallback to plain
            return nil
        }
    }

    // Keep existing fetchLyrics method for plain text fallback
    func fetchLyrics(artist: String, songTitle: String, album: String, duration: Int?) async throws -> String {
        // ... existing implementation unchanged ...
    }
}
```

---

### 7. LyricsView Updates

Major updates to support synced lyrics display, auto-scroll, and user interaction.

```swift
// File: AlwaysOnLyrics/Views/LyricsView.swift

struct LyricsView: View {
    @ObservedObject var spotifyMonitor: SpotifyMonitor
    @ObservedObject var settings = AppSettings.shared

    let lyricsService: LyricsService

    // MARK: - State

    @State private var currentTrack: Track?
    @State private var lyrics: String = ""  // Plain text lyrics
    @State private var syncedLyrics: SyncedLyrics?  // NEW: Synced lyrics
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentFetchTask: Task<Void, Never>?

    // NEW: Auto-scroll state
    @State private var isAutoScrollEnabled: Bool = true
    @State private var lastAutoScrolledLineID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            headerView.padding(.horizontal)
            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal)

            ZStack(alignment: .bottom) {
                contentView

                // NEW: Snap-to-current button (only show when auto-scroll disabled)
                if !isAutoScrollEnabled && syncedLyrics != nil {
                    snapToCurrentButton
                }
            }
        }
        .background(Color.black)
        .onChange(of: spotifyMonitor.currentTrack) { newTrack in
            handleTrackChange(newTrack)
        }
        .onChange(of: settings.enableSyncedLyrics) { _ in
            // Re-fetch lyrics when setting changes
            if let track = currentTrack {
                handleTrackChange(track)
            }
        }
        .onAppear {
            if let track = spotifyMonitor.currentTrack {
                handleTrackChange(track)
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        Group {
            if syncedLyrics != nil && settings.enableSyncedLyrics {
                syncedLyricsView
            } else if !lyrics.isEmpty {
                plainLyricsView
            } else {
                // Existing empty states...
                emptyOrErrorStates
            }
        }
    }

    // MARK: - Synced Lyrics View (NEW)

    private var syncedLyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(syncedLyrics?.lines ?? []) { line in
                        LyricLineView(
                            line: line,
                            state: lineState(for: line),
                            fontSize: settings.fontSize
                        )
                        .id(line.id)
                        .onAppear {
                            // Detect if user manually scrolled
                            if isAutoScrollEnabled {
                                // Still in auto-scroll mode
                            } else {
                                // User has scrolled, don't auto-scroll
                            }
                        }
                    }
                }
                .padding()
            }
            .onChange(of: currentLineID) { newLineID in
                guard isAutoScrollEnabled, let newLineID = newLineID else { return }

                // Auto-scroll to current line
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(newLineID, anchor: .center)
                }
                lastAutoScrolledLineID = newLineID
            }
            .simultaneousGesture(
                // Detect user scroll gesture
                DragGesture().onChanged { _ in
                    isAutoScrollEnabled = false
                }
            )
        }
    }

    // MARK: - Plain Lyrics View (existing)

    private var plainLyricsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(lyrics)
                    .font(.system(size: settings.fontSize))
                    .foregroundColor(.white)
                    .lineSpacing(settings.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding()
        }
    }

    // MARK: - Snap to Current Button (NEW)

    private var snapToCurrentButton: some View {
        Button(action: {
            isAutoScrollEnabled = true
        }) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Snap to Current")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }

    // MARK: - Helper Methods

    /// Determine current line ID based on playback position
    private var currentLineID: UUID? {
        guard let lyrics = syncedLyrics else { return nil }
        let position = spotifyMonitor.playbackPosition
        return lyrics.currentLine(at: position)?.id
    }

    /// Determine visual state for a lyric line
    private func lineState(for line: LyricLine) -> LyricLineState {
        let position = spotifyMonitor.playbackPosition

        if line.timestamp > position {
            return .future
        } else if line.id == currentLineID {
            return .current
        } else {
            return .past
        }
    }

    // MARK: - Fetch Lyrics

    private func handleTrackChange(_ newTrack: Track?) {
        // Cancel existing fetch
        currentFetchTask?.cancel()
        currentFetchTask = nil

        // Reset auto-scroll when track changes
        isAutoScrollEnabled = true

        guard let track = newTrack else {
            currentTrack = nil
            lyrics = ""
            syncedLyrics = nil
            errorMessage = nil
            return
        }

        // ... existing track change logic ...

        currentFetchTask = Task {
            await fetchLyrics(for: track)
        }
    }

    private func fetchLyrics(for track: Track) async {
        isLoading = true
        errorMessage = nil

        // Try synced lyrics first (if enabled)
        if settings.enableSyncedLyrics {
            if let synced = try? await lyricsService.fetchSyncedLyrics(
                artist: track.artist,
                songTitle: track.title,
                album: track.album,
                duration: track.duration
            ) {
                guard isCurrentTrack(track) else { return }

                await MainActor.run {
                    self.syncedLyrics = synced
                    self.lyrics = ""  // Clear plain lyrics
                    self.isLoading = false
                }
                return
            }
        }

        // Fallback to plain lyrics
        do {
            let plainLyrics = try await lyricsService.fetchLyrics(
                artist: track.artist,
                songTitle: track.title,
                album: track.album,
                duration: track.duration
            )

            guard isCurrentTrack(track) else { return }

            await MainActor.run {
                self.lyrics = plainLyrics
                self.syncedLyrics = nil  // Clear synced lyrics
                self.isLoading = false
            }
        } catch {
            // ... existing error handling ...
        }
    }
}
```

---

### 8. LyricLineView Component (NEW)

Individual lyric line with opacity-based styling.

```swift
// File: AlwaysOnLyrics/Views/LyricLineView.swift

import SwiftUI

struct LyricLineView: View {
    let line: LyricLine
    let state: LyricLineState
    let fontSize: Double

    var body: some View {
        Text(line.text)
            .font(.system(size: fontSize))
            .foregroundColor(.white)
            .opacity(textOpacity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var textOpacity: Double {
        switch state {
        case .past:
            return 0.4   // Darker (past lyrics)
        case .current:
            return 1.0   // Brightest (current line)
        case .future:
            return 0.7   // Medium brightness (upcoming lyrics)
        }
    }
}

enum LyricLineState: Equatable {
    case past
    case current
    case future
}
```

---

## Implementation Steps

### Phase 1: Foundation
1. ✅ Create planning document (this file)
2. Create data models: `LyricLine.swift`, `SyncedLyrics.swift`
3. Create `LRCParser.swift` with timestamp parsing
4. Add unit tests for LRC parser

### Phase 2: Position Tracking
5. Add `playbackPosition` to `Track` model
6. Add AppleScript method to query playback position
7. Implement hybrid timer in `SpotifyMonitor`
8. Test position tracking accuracy

### Phase 3: Settings & Service
9. Add `enableSyncedLyrics` to `AppSettings`
10. Add UI toggle to `PreferencesWindow`
11. Update `LyricsService.fetchSyncedLyrics()` method
12. Test fetching synced lyrics from LRCLIB

### Phase 4: UI Implementation
13. Create `LyricLineView` component
14. Update `LyricsView` with ScrollViewReader
15. Implement auto-scroll logic
16. Add scroll gesture detection

### Phase 5: User Interaction
17. Add "Snap to Current" button
18. Implement auto-scroll pause on manual scroll
19. Test user interaction flows

### Phase 6: Polish & Testing
20. Fine-tune animation timings
21. Test with various tracks (synced/plain/instrumental)
22. Test edge cases (seeking, pausing, track changes)
23. Performance testing

---

## Technical Decisions

### Tunable Parameters (to adjust during POC)
- Timer update frequency: **15 Hz** (67ms interval) - can adjust
- Sync frequency: **3 seconds** - can adjust
- Scroll animation duration: **0.3 seconds** - can adjust
- Opacity values: past=0.4, current=1.0, future=0.7 - can adjust

### Edge Cases to Handle
- No synced lyrics available → fallback to plain lyrics
- LRCLIB returns instrumental track → show instrumental message
- User seeks in Spotify → next sync will correct position
- Track changes mid-scroll → reset auto-scroll
- User scrolls while paused → keep auto-scroll disabled

---

## Testing Strategy

### Song Characteristics to Test

When testing synced lyrics, we need to verify the feature works well across different types of songs:

#### 1. **Rapid-Fire Lyrics** (High Line Density)
Songs with very fast lyric changes (e.g., rap, fast-paced pop)

**Why test:**
- Stress test auto-scroll performance
- Verify UI can keep up with rapid line changes
- Ensure animations don't lag or stutter
- Test if highlights transition smoothly at high frequency

**What to look for:**
- Does auto-scroll jump too frequently?
- Are opacity transitions smooth or jarring?
- Does the UI remain responsive during rapid changes?
- Can the timer keep accurate sync during fast sections?

**Example characteristics:**
- Lines changing every 1-2 seconds or faster
- Multiple words per second

---

#### 2. **Minimal/Sparse Lyrics** (Low Line Density)
Songs with long instrumental sections or slow pacing

**Why test:**
- Verify position tracking doesn't drift during long gaps
- Test that current line stays highlighted for extended periods
- Ensure auto-scroll doesn't trigger unnecessarily

**What to look for:**
- Does the same line stay highlighted properly?
- Does position tracking stay accurate during instrumental breaks?
- Is there any drift after 30+ seconds with no lyric changes?

**Example characteristics:**
- Lines changing every 10-30 seconds
- Long instrumental intros/outros
- Ballads with slow pacing

---

#### 3. **Very Long Songs** (5+ minutes)
Extended tracks to test drift and accuracy over time

**Why test:**
- Position tracking drift becomes more apparent
- Verify 3-second sync keeps things accurate
- Test memory usage over extended playback

**What to look for:**
- Does sync drift by end of song?
- Are sync corrections noticeable/jarring?
- Memory usage stable throughout?

**Example characteristics:**
- 5-10+ minute songs
- Progressive rock, classical, extended remixes

---

#### 4. **Songs with Overlapping/Chorus Repetition**
Songs with repeated choruses or background vocals

**Why test:**
- Verify we handle duplicate lyric lines correctly
- Test that timestamps distinguish repeated sections
- Ensure auto-scroll doesn't get confused

**What to look for:**
- Do repeated sections highlight correctly each time?
- Does the parser handle duplicate text with different timestamps?

**Example characteristics:**
- Songs with repeated chorus
- Call-and-response sections
- Background vocals

---

#### 5. **Short Songs** (Under 2 minutes)
Quick tracks to test initialization and cleanup

**Why test:**
- Verify position tracking starts quickly
- Test cleanup when track ends soon
- Ensure no memory leaks on rapid track changes

**What to look for:**
- Does tracking start before song ends?
- Clean transition to next track?

**Example characteristics:**
- Punk, short pop songs, interludes

---

#### 6. **Songs with No Synced Lyrics Available**
Tracks where LRCLIB has plain but not synced lyrics

**Why test:**
- Verify graceful fallback to plain lyrics
- Test setting toggle behavior
- Ensure no errors or blank screens

**What to look for:**
- Does it fallback to plain lyrics?
- Is the transition smooth?
- No error messages shown?

---

#### 7. **Instrumental Tracks**
Songs with no lyrics at all

**Why test:**
- Verify instrumental detection works
- Ensure appropriate message shown

**What to look for:**
- Correct "instrumental" message
- No crashes or errors

---

#### 8. **Songs with Special Characters/Languages**
Non-English songs, songs with emoji, special symbols

**Why test:**
- Verify LRC parser handles Unicode correctly
- Test display rendering of various character sets
- Ensure no encoding issues

**What to look for:**
- Special characters display correctly
- No garbled text
- Proper text wrapping

**Example characteristics:**
- Spanish, Japanese, Korean, Arabic songs
- Songs with emoji in lyrics
- Accented characters

---

### User Interaction Test Cases

#### Auto-Scroll Behavior
- [ ] Auto-scroll starts enabled when track starts
- [ ] Scrolling manually disables auto-scroll
- [ ] "Snap to Current" button appears when disabled
- [ ] Clicking snap button re-enables and jumps to current line
- [ ] Auto-scroll resets when track changes
- [ ] Auto-scroll stays disabled across same track (if user scrolled)

#### Position Tracking Accuracy
- [ ] Position stays in sync over 5+ minute track
- [ ] Seeking forward in Spotify updates within 3 seconds
- [ ] Seeking backward in Spotify updates within 3 seconds
- [ ] Pausing in Spotify freezes the highlight
- [ ] Resuming in Spotify continues from correct position

#### Settings Integration
- [ ] Toggling setting off shows plain lyrics
- [ ] Toggling setting on re-fetches synced lyrics
- [ ] Setting persists across app restarts
- [ ] Changing mid-song updates display appropriately

#### Edge Cases
- [ ] Switching tracks rapidly doesn't cause crashes
- [ ] Closing lyrics window stops position tracking (cleanup)
- [ ] Opening lyrics window mid-song starts at correct position
- [ ] Network error during fetch shows appropriate message
- [ ] Malformed LRC data doesn't crash parser

---

## Testing Checklist

### Parser Testing
- [ ] LRC parser handles valid timestamps correctly `[00:12.34]`
- [ ] LRC parser handles timestamps without decimals `[00:12]`
- [ ] LRC parser handles malformed input gracefully
- [ ] Empty lines ignored
- [ ] Lines sorted by timestamp even if input unsorted

### Position Tracking
- [ ] Position tracking stays synced over 5+ minute track
- [ ] Position resets correctly on track change
- [ ] Sync corrections are smooth (not jarring)
- [ ] Timer stops when track pauses
- [ ] Timer resumes accurately when track plays

### UI/UX
- [ ] Auto-scroll follows current line smoothly
- [ ] Manual scroll disables auto-scroll
- [ ] Snap button re-enables auto-scroll and jumps to current line
- [ ] Opacity transitions are smooth (past → current → future)
- [ ] No flickering or stuttering

### Settings & Fallback
- [ ] Toggle setting works (switches between synced/plain)
- [ ] Fallback to plain lyrics when synced unavailable
- [ ] Synced lyrics preferred when both available
- [ ] Setting persists across app restarts

### Performance
- [ ] Performance is smooth (no lag or stuttering)
- [ ] CPU usage reasonable during playback
- [ ] Memory usage stable over time
- [ ] No memory leaks on track changes

---

## Future Enhancements (Post-MVP)

- Click on lyric line to seek to that timestamp
- Search within lyrics
- Export lyrics
- Custom color schemes for past/current/future
- Adjustable scroll offset (center vs top vs bottom)
- Keyboard shortcuts (space to toggle auto-scroll, etc.)

---

## References

- LRC Format: https://en.wikipedia.org/wiki/LRC_(file_format)
- LRCLIB API: Already integrated, returns `syncedLyrics` field
- Apple Timer documentation for position tracking
- ScrollViewReader SwiftUI documentation

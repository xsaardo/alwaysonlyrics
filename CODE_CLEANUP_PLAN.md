# Code Cleanup Plan - AlwaysOnLyrics

**Date:** 2025-11-23
**Status:** Identified
**Overall Code Health:** Good (mostly minor cleanup needed)

---

## Summary

The codebase is generally clean and well-organized. The following cleanup opportunities have been identified:

| Priority | Category | Count | Effort |
|----------|----------|-------|--------|
| High | Debug Print Statements | 2 | 5 min |
| High | Unused Methods | 1 | 5 min |
| Medium | Unused Methods | 1 | 5 min |
| Medium | Inconsistencies | 1 | 10 min |
| Medium | Code Duplication | 8+ instances | 30 min |
| Low | Documentation Gaps | ~10 items | 20 min |

**Total Estimated Effort:** ~75 minutes

---

## High Priority Items

### 1. Remove Debug Print Statements

**File:** `AlwaysOnLyrics/Models/AppSettings.swift`

**Issue:**
Two print statements used for error logging in production code.

**Locations:**
- Line 196: `print("Failed to update launch at login: \(error.localizedDescription)")`
- Line 212: `print("Failed to get login items list")`

**Action:**
Remove both print statements. If error logging is needed, use `os.log` or `NSLog` instead.

**Rationale:**
Print statements pollute console output and aren't appropriate for production apps. These errors are already handled gracefully (user won't notice if launch-at-login fails to register).

**Before:**
```swift
} catch {
    print("Failed to update launch at login: \(error.localizedDescription)")
}
```

**After:**
```swift
} catch {
    // Silently fail - launch at login is optional feature
}
```

---

### 2. Remove Unused Visual Effect Background Method

**File:** `AlwaysOnLyrics/Views/LyricsWindow.swift`

**Issue:**
`setupVisualEffectBackground()` method (lines 127-141) is defined but never called.

**Context:**
Explicitly commented out at line 40 with note: "DON'T setup visual effect background - it breaks SwiftUI rendering"

**Action:**
Delete the entire method since it's intentionally not used and breaks functionality.

**Rationale:**
Dead code increases maintenance burden and confuses developers.

**Code to Remove:**
```swift
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
```

---

## Medium Priority Items

### 3. Remove Unused Search Method

**File:** `AlwaysOnLyrics/Services/LRCLIBAPIClient.swift`

**Issue:**
`searchLyrics()` method is defined but never called anywhere in the codebase.

**Location:** Lines 77-116

**Action:**
Remove the method OR document why it's kept for future use.

**Decision Points:**
- **If planning to use:** Add comment explaining future use case
- **If not planning to use:** Remove entirely

**Rationale:**
Currently the app only uses `getLyrics()` with exact track match. Search functionality may be useful for future "manual search" feature but adds complexity now.

**Recommendation:** Remove for now. Can be added back from git history if needed.

---

### 4. Standardize objectWillChange Placement

**File:** `AlwaysOnLyrics/Models/AppSettings.swift`

**Issue:**
Inconsistent placement of `objectWillChange.send()` in property setters.

**Examples:**

**Inconsistent (send BEFORE assignment):**
```swift
var rememberWindowPosition: Bool {
    get { _rememberWindowPosition }
    set {
        objectWillChange.send()  // BEFORE
        _rememberWindowPosition = newValue
        defaults.set(newValue, forKey: "rememberWindowPosition")
    }
}
```

**Consistent (send AFTER assignment):**
```swift
var alwaysOnTop: Bool {
    get { _alwaysOnTop }
    set {
        _alwaysOnTop = newValue
        defaults.set(newValue, forKey: "alwaysOnTop")
        objectWillChange.send()  // AFTER - with comment explaining why
    }
}
```

**Action:**
Move `objectWillChange.send()` to AFTER assignment in all setters for consistency.

**Affected Properties:**
- `rememberWindowPosition` (line 44)
- `rememberWindowSize` (line 54)
- `launchAtLogin` (line 64)
- `fontSize` (line 81)
- `lineSpacing` (line 91)
- `enableSyncedLyrics` (line 103)

**Rationale:**
The comment in `alwaysOnTop` and `windowOpacity` explains: "Send after change so observers see new value". This should be consistent across all properties.

---

### 5. Reduce Code Duplication with Property Wrapper (Optional)

**File:** `AlwaysOnLyrics/Models/AppSettings.swift`

**Issue:**
The property pattern is repeated 8+ times with minimal variation.

**Current Pattern:**
```swift
var propertyName: Type {
    get { _propertyName }
    set {
        objectWillChange.send()
        _propertyName = newValue
        defaults.set(newValue, forKey: "keyName")
    }
}
private var _propertyName: Type = defaultValue
```

**Proposed Solution:**
Create a `@UserDefaultBacked` property wrapper to reduce boilerplate.

**Benefits:**
- Reduces ~70 lines of code
- Eliminates duplication
- Easier to maintain
- Less error-prone

**Drawbacks:**
- Adds complexity
- Requires refactoring and testing
- May need custom handling for special cases (e.g., `launchAtLogin` has side effects)

**Recommendation:**
Defer to future refactoring. Current code is readable and working. Property wrappers add abstraction that may not be worth it for 8 properties.

---

## Low Priority Items

### 6. Add Documentation Comments

**Missing Documentation:**

**Track.swift**
```swift
/// Represents a Spotify track with metadata and playback state
struct Track: Equatable {
    /// Track title
    let title: String
    /// Artist name
    let artist: String
    // ... etc
}
```

**LyricsError.swift**
```swift
/// Errors that can occur during lyrics fetching
enum LyricsError: Error, LocalizedError {
    /// Track was not found in lyrics database
    case trackNotFound
    // ... etc
}
```

**SpotifyMonitor.swift**
```swift
/// Current track being played, or nil if no track
@Published var currentTrack: Track?
/// Whether Spotify is currently running
@Published var spotifyRunning: Bool = false
/// Current playback position in seconds
@Published var playbackPosition: Double = 0.0
```

**Action:**
Add documentation comments to public APIs and data models.

**Rationale:**
Improves code readability and helps with Xcode autocomplete. Not critical since code is mostly self-documenting.

---

## What NOT to Clean Up

### Intentional Design Decisions

**1. Private backing properties in AppSettings**
```swift
private var _propertyName: Type = defaultValue
```
These are intentional to control when `objectWillChange` fires. Don't remove.

**2. Commented explanation at line 40 in LyricsWindow**
```swift
// DON'T setup visual effect background - it breaks SwiftUI rendering
```
This is valuable context. Keep the comment even after removing the method.

**3. Empty init() in SpotifyMonitor**
```swift
init() {
    // No initialization needed
}
```
This is explicit and communicates intent. Keep it.

**4. Error case duplication in LyricsError**
```swift
case trackNotFound
case noLyricsAvailable
```
These have different semantic meanings even if they show similar messages. Keep both.

---

## Cleanup Checklist

### High Priority (Do First)
- [ ] Remove 2 print statements in AppSettings.swift
- [ ] Remove `setupVisualEffectBackground()` method in LyricsWindow.swift

### Medium Priority
- [ ] Remove or document `searchLyrics()` in LRCLIBAPIClient.swift
- [ ] Standardize `objectWillChange.send()` placement in AppSettings.swift

### Low Priority (Nice to Have)
- [ ] Add documentation comments to Track.swift
- [ ] Add documentation comments to LyricsError enum
- [ ] Document @Published properties in SpotifyMonitor.swift

### Deferred
- [ ] Consider property wrapper refactoring (future refactoring task)

---

## Testing After Cleanup

**Verification Steps:**
1. Build succeeds without warnings
2. App launches successfully
3. Settings still persist correctly
4. Lyrics window displays properly
5. All existing functionality works

**Manual Test:**
- Open app
- Change each setting in preferences
- Restart app
- Verify settings persisted

---

**Next Steps:**
1. Review this plan
2. Start with high-priority items
3. Test after each cleanup
4. Commit cleanup separately from feature work

# Always On Lyrics - MVP Specifications

## Overview
A macOS menu bar application that displays lyrics for the currently playing Spotify track in an always-on-top window.

## Core Features

### 1. Spotify Integration
- **Method**: AppleScript polling
- **Polling Interval**: 1-2 seconds
- **Detection**: Track title, artist, and playback state
- **Trigger**: Fetch lyrics when track changes

### 2. Lyrics Fetching
- **Provider**: Genius API (free tier)
- **Implementation**: Port existing Node.js logic from `genius.js` and `lyrics-fetcher.js`
- **Search Strategy**: Query by "artist - track title"
- **Extraction Method**:
  - Search via Genius API
  - Scrape lyrics from Genius web page HTML
  - Parse using `div[class^="Lyrics__Container"]` selector
  - Clean HTML to plain text
- **Error Handling**: Display "Lyrics not found" message
- **No Caching**: Fetch on-demand for MVP

### 3. UI/UX

#### Menu Bar Icon
- Simple icon in macOS menu bar
- Click to toggle lyrics window visibility
- Quit option in dropdown menu

#### Lyrics Window
- **Always-on-top**: Floats above all other windows
- **Position**: User-movable
- **Size**: User-resizable (default: 400x600px)
- **Persistence**: Save position/size to UserDefaults
- **Background**: Dark semi-transparent blur effect
- **Layout**:
  ```
  ┌─────────────────────────┐
  │  Song Title             │
  │  Artist Name            │
  │─────────────────────────│
  │                         │
  │  Lyrics text here...    │
  │  Scrollable content     │
  │  Static (no auto-scroll)│
  │                         │
  │                         │
  └─────────────────────────┘
  ```

#### Styling
- Dark theme matching Spotify aesthetic
- Header: Song title (larger, bold) + Artist (smaller, secondary color)
- Lyrics: Left-aligned, comfortable line spacing
- Font: System default (San Francisco)
- Colors: White/gray text on dark background

### 4. Keyboard Shortcuts
- **Cmd+Shift+L**: Toggle window visibility

### 5. States

#### Playing State
- Window shows: Current song info + lyrics
- Auto-updates when track changes

#### Not Playing / Paused
- Window shows: Last song info + lyrics (no auto-hide)

#### No Lyrics Found
- Window shows: Song info + "Lyrics not available for this track"

#### Spotify Not Running
- Window shows: "Open Spotify to see lyrics"

## Technical Architecture

### Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum macOS**: 13.0 (Ventura)
- **HTTP Client**: URLSession (native)
- **HTML Parsing**: SwiftSoup (Swift port of jsoup/cheerio)
- **Dependencies**: SwiftSoup via Swift Package Manager

### Components

#### 1. App Delegate
- Initialize menu bar app (LSUIElement = YES)
- Create NSStatusItem
- Manage app lifecycle

#### 2. Spotify Monitor
- **Class**: `SpotifyMonitor`
- **Responsibilities**:
  - Poll Spotify via AppleScript
  - Detect track changes
  - Publish current track info
- **Technology**: NSAppleScript
- **Output**: Track struct (title, artist, isPlaying)

#### 3. Lyrics Service
- **Class**: `LyricsService`
- **Responsibilities**:
  - Fetch lyrics from Genius API (port from `lyrics-fetcher.js`)
  - Search for song (port from `genius.js::searchSong()`)
  - Fetch HTML page (port from `genius.js::fetchPageHTML()`)
  - Extract lyrics (port from `genius.js::extractLyricsFromHTML()`)
  - Clean HTML (port from `genius.js::cleanLyricsHTML()`)
- **Technology**: URLSession + async/await
- **HTML Parsing**: SwiftSoup
- **API Endpoint**: Genius API v1
- **Output**: Lyrics string or error

##### Porting Notes:
1. **Search**: `GET https://api.genius.com/search?q={query}` with Bearer token
2. **HTML Fetch**: Handle gzip/deflate/br encoding (URLSession does this automatically)
3. **Extraction**: Use SwiftSoup to select `div[class^="Lyrics__Container"]`
4. **Cleaning**: Remove non-formatting tags, convert `<br>` to newlines

#### 4. Lyrics Window
- **Class**: `LyricsWindow` (NSWindow)
- **Properties**:
  - Level: .floating (always-on-top)
  - Style: .titled, .closable, .resizable, .miniaturizable
  - Background: Visual effect view (dark blur)
- **Content**: SwiftUI view

#### 5. Lyrics View
- **SwiftUI View**: `LyricsView`
- **State**:
  - Current track info
  - Lyrics text
  - Loading state
- **Layout**:
  - VStack with header and ScrollView
  - Header: Song + Artist
  - Body: Lyrics text

### Data Flow
```
Timer (1-2s)
  → SpotifyMonitor.poll()
  → Detect track change
  → LyricsService.search(track, artist)
  → Genius API request
  → Parse JSON, get song URL
  → Fetch HTML from song URL
  → Extract lyrics using SwiftSoup
  → Clean HTML to plain text
  → Update LyricsView state
  → UI renders
```

### File Structure
```
AlwaysOnLyrics/
├── AlwaysOnLyricsApp.swift       # App entry point
├── AppDelegate.swift              # Menu bar setup
├── Models/
│   ├── Track.swift                # Track data model
│   └── GeniusSong.swift           # Genius API response models
├── Services/
│   ├── SpotifyMonitor.swift       # AppleScript integration
│   └── LyricsService.swift        # Genius API client (ported from JS)
├── Views/
│   ├── LyricsWindow.swift         # NSWindow wrapper
│   └── LyricsView.swift           # SwiftUI content view
├── Utilities/
│   ├── UserDefaultsManager.swift  # Window position persistence
│   └── HTMLCleaner.swift          # HTML cleaning utilities
└── Resources/
    ├── Assets.xcassets            # Menu bar icon
    └── Info.plist                 # LSUIElement configuration
```

## API Integration

### Genius API
- **Authentication**: Access token via Bearer header
- **Search Endpoint**: `GET /search?q={artist} {track}`
  - Returns array of hits with song metadata
  - Take first result (best match)
- **Lyrics Extraction**:
  - Get song URL from search result
  - Fetch HTML from URL
  - Parse with SwiftSoup
  - Select: `div[class^="Lyrics__Container"]`
  - Remove: `[data-exclude-from-selection="true"]`
  - Convert to plain text
- **Rate Limiting**: Handle 429 errors gracefully

### AppleScript Commands
```applescript
tell application "Spotify"
    if it is running then
        set trackName to name of current track
        set artistName to artist of current track
        set isPlaying to player state is playing
        return trackName & "|" & artistName & "|" & isPlaying
    end if
end tell
```

## Configuration

### Hardcoded for MVP
- Polling interval: 1.5 seconds
- Window default size: 400x600
- Genius API token: Stored in environment or config file
- Theme: Dark only

### UserDefaults Keys
- `windowX`: Float (window X position)
- `windowY`: Float (window Y position)
- `windowWidth`: Float (window width)
- `windowHeight`: Float (window height)
- `windowVisible`: Bool (window visibility state)

## Dependencies

### Swift Package Manager
- **SwiftSoup**: https://github.com/scinfu/SwiftSoup
  - HTML/XML parser (Swift port of jsoup)
  - Used for extracting lyrics from Genius pages

## Implementation Notes

### Porting JavaScript to Swift

#### 1. Search Function (`genius.js::searchSong`)
```swift
// Swift equivalent using URLSession
func searchSong(artist: String, songTitle: String, accessToken: String) async throws -> [GeniusSong] {
    let query = "\(songTitle) \(artist)"
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    let url = URL(string: "https://api.genius.com/search?q=\(encodedQuery!)")!

    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(GeniusSearchResponse.self, from: data)
    return response.response.hits.map { $0.result }
}
```

#### 2. HTML Fetching (`genius.js::fetchPageHTML`)
```swift
// URLSession handles decompression automatically
func fetchPageHTML(url: String) async throws -> String {
    let url = URL(string: url)!
    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

    let (data, _) = try await URLSession.shared.data(for: request)
    return String(data: data, encoding: .utf8)!
}
```

#### 3. Lyrics Extraction (`genius.js::extractLyricsFromHTML`)
```swift
// Using SwiftSoup instead of cheerio
func extractLyricsFromHTML(html: String) throws -> String {
    let doc = try SwiftSoup.parse(html)

    // Remove excluded elements
    try doc.select("div[class^=Lyrics__Container] [data-exclude-from-selection=true]").remove()

    // Get lyrics containers
    let containers = try doc.select("div[class^=Lyrics__Container]")

    var allHTML = ""
    for container in containers {
        allHTML += try container.html() + "\n\n"
    }

    return allHTML
}
```

#### 4. HTML Cleaning (`genius.js::cleanLyricsHTML`)
```swift
// Port regex-based cleaning or use SwiftSoup
func cleanLyricsHTML(html: String) -> String {
    // Parse and convert to plain text
    // Replace <br> with newlines
    // Strip other tags
    return cleaned
}
```

## Future Enhancements (Post-MVP)
- Auto-scrolling synced lyrics
- Multiple lyrics providers with fallback
- Lyrics caching (SQLite or file-based)
- Customization (themes, fonts, transparency)
- Click-through window mode
- Spotify API integration (for better reliability)
- Manual lyrics search
- Preferences window
- Apple Music support

## Development Phases

### Phase 1: Project Setup
1. Create Xcode project (menu bar app)
2. Add SwiftSoup dependency via SPM
3. Setup menu bar icon and menu
4. Implement window show/hide toggle
5. Save/restore window position

### Phase 2: Spotify Integration
1. Implement SpotifyMonitor with AppleScript
2. Create Track model
3. Setup polling timer
4. Test track change detection

### Phase 3: Lyrics Fetching
1. Port Genius API search logic to Swift
2. Port HTML fetching logic
3. Port lyrics extraction with SwiftSoup
4. Port HTML cleaning logic
5. Create Genius API models (Codable)
6. Handle errors and edge cases

### Phase 4: UI Polish
1. Design LyricsView layout
2. Implement loading states
3. Style to match Spotify aesthetic
4. Add keyboard shortcut

### Phase 5: Testing & Refinement
1. Test with various tracks
2. Handle edge cases (no internet, Spotify closed, etc.)
3. Performance optimization
4. Bug fixes

## Success Criteria
- ✅ App runs in menu bar
- ✅ Detects currently playing Spotify track
- ✅ Fetches and displays lyrics from Genius
- ✅ Window stays on top
- ✅ Window position persists
- ✅ Toggle via keyboard shortcut
- ✅ Clean, Spotify-like UI
- ✅ No crashes with normal usage

## Known Limitations
- Lyrics accuracy depends on Genius database
- No offline support
- No synced scrolling
- Spotify-only (no Apple Music, etc.)
- Requires Spotify desktop app
- May break if Genius changes their HTML structure

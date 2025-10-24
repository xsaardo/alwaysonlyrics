# Always On Lyrics - Setup Instructions

This guide will help you set up and build the Always On Lyrics macOS app in Xcode.

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later
- Spotify desktop app installed
- Genius API access token ([Get one here](https://genius.com/api-clients))

## Project Setup

### 1. Create Xcode Project

Since there's no `.xcodeproj` file yet, you'll need to create one in Xcode:

1. **Open Xcode**
2. **File → New → Project**
3. Select **macOS** → **App**
4. Configure project:
   - **Product Name**: `AlwaysOnLyrics`
   - **Team**: Select your team
   - **Organization Identifier**: `com.yourname` (or your preferred identifier)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Uncheck** "Use Core Data"
   - **Uncheck** "Include Tests"
5. **Save** in `/Users/cuongluong/Desktop/alwaysonlyrics/`
   - This will create `AlwaysOnLyrics.xcodeproj` in the directory

### 2. Add Source Files to Xcode

After creating the project, Xcode will generate some default files. You need to **delete** the generated files and **add** the existing ones:

#### Delete Generated Files:
- Delete `ContentView.swift` (if created)
- Keep `AlwaysOnLyricsApp.swift` but replace with the existing one

#### Add Existing Source Files:
1. In Xcode, select the `AlwaysOnLyrics` folder in the navigator
2. **Right-click** → **Add Files to "AlwaysOnLyrics"**
3. Navigate to the `AlwaysOnLyrics` folder and select:
   - `AppDelegate.swift`
   - `Config.swift`
   - `Models/` folder
   - `Services/` folder
   - `Utilities/` folder
   - `Views/` folder
4. **Important**: Check "Copy items if needed" is **unchecked** (files are already in the right place)
5. Make sure "Create groups" is selected

#### Replace Info.plist:
1. Delete the generated `Info.plist` in Xcode
2. Add the existing `Info.plist` from the `AlwaysOnLyrics` folder

### 3. Configure Build Settings

1. **Select the project** in Xcode navigator
2. **Select the "AlwaysOnLyrics" target**
3. **General tab**:
   - **Deployment Target**: macOS 13.0 or later
4. **Info tab**:
   - Verify `Info.plist` is selected as the custom plist
   - Or manually configure:
     - **Application is agent (UIElement)**: YES
     - **Privacy - AppleEvents Sending Usage Description**: "This app needs to access Spotify to detect currently playing tracks."

### 4. Configure Genius API Token (Secure)

The app loads the Genius API token from secure sources (never hardcoded). Choose one of these methods:

#### Option A: Environment Variable (Recommended for Development)

1. Get a Genius API access token from [https://genius.com/api-clients](https://genius.com/api-clients)
2. In Xcode, select **Product → Scheme → Edit Scheme** (or press ⌘<)
3. Select **Run** in the left sidebar
4. Select the **Arguments** tab
5. Under **Environment Variables**, click **+** and add:
   - **Name**: `GENIUS_ACCESS_TOKEN`
   - **Value**: Your actual Genius API token
6. Click **Close**

This keeps your token out of source code and version control.

#### Option B: Config File (Recommended for Production)

1. Copy `config.example.json` to `config.json`:
   ```bash
   cp config.example.json config.json
   ```
2. Edit `config.json` and replace the placeholder:
   ```json
   {
     "geniusAccessToken": "YOUR_ACTUAL_TOKEN_HERE"
   }
   ```
3. **Important**: The file `config.json` is already gitignored and won't be committed
4. In Xcode, add `config.json` to your project:
   - Right-click the project → **Add Files to "AlwaysOnLyrics"**
   - Select `config.json`
   - Check **"Copy items if needed"**
   - Make sure it's added to the **AlwaysOnLyrics target**

**Priority**: The app checks environment variables first, then falls back to `config.json`.

### 5. Build and Run

1. **Product → Build** (⌘B)
2. Fix any build errors if they occur
3. **Product → Run** (⌘R)

The app should:
- Appear in the menu bar with a music note icon
- Left-click the icon to toggle the lyrics window
- Right-click the icon for the menu (with "Quit" option)
- Use **Cmd+Shift+L** to toggle the window from anywhere

## Project Structure

Your project should have this structure:

```
alwaysonlyrics/
├── .gitignore                     # Git ignore rules (config.json ignored)
├── config.example.json            # Template for config.json
├── config.json                    # Your actual config (gitignored, create from example)
├── AlwaysOnLyrics.xcodeproj/     # Created by Xcode
├── AlwaysOnLyrics/
│   ├── AlwaysOnLyricsApp.swift   # App entry point
│   ├── AppDelegate.swift          # Menu bar setup
│   ├── Config.swift               # Secure token loading
│   ├── Info.plist                 # App configuration
│   ├── Models/
│   │   ├── Track.swift            # Track data model
│   │   └── GeniusSong.swift       # Genius API models
│   ├── Services/
│   │   ├── SpotifyMonitor.swift   # AppleScript integration
│   │   └── LyricsService.swift    # Genius API client
│   ├── Utilities/
│   │   ├── HTMLCleaner.swift      # HTML processing
│   │   └── UserDefaultsManager.swift # Window persistence
│   └── Views/
│       ├── LyricsView.swift       # SwiftUI content view
│       └── LyricsWindow.swift     # NSWindow wrapper
├── SPECS.md                       # Original specifications
├── SETUP.md                       # This file
├── genius.js                      # Reference implementation
└── lyrics-fetcher.js              # Reference implementation
```

## Troubleshooting

### Build Errors

**"Cannot find type 'X' in scope"**
- Make sure all source files are added to the Xcode target
- Check that imports are correct (AppKit, SwiftUI, Foundation)

**Info.plist errors**
- Verify the Info.plist is added to the project
- Check that LSUIElement is set to YES

### Runtime Issues

**App doesn't appear in menu bar**
- Check that `LSUIElement` is set to `true` in Info.plist
- Verify AppDelegate is properly connected in `AlwaysOnLyricsApp.swift`

**Spotify not detected**
- Grant AppleEvents permission when prompted
- Make sure Spotify desktop app is running
- Check System Settings → Privacy & Security → Automation

**No lyrics found**
- Verify your Genius API token is configured correctly:
  - Check environment variable `GENIUS_ACCESS_TOKEN` in Xcode scheme
  - Or verify `config.json` exists and has valid token
  - Token should start with a long alphanumeric string
- Check internet connection
- Try a popular song (better chance of having lyrics on Genius)
- Check Xcode console for error messages like "ERROR_NO_TOKEN_CONFIGURED"

**Window doesn't stay on top**
- This is expected behavior in some macOS versions
- The window should still be visible but may go behind other windows

### Permissions

The first time you run the app, macOS will prompt for permissions:

1. **AppleEvents/Automation**: Required to communicate with Spotify
   - **Allow** this permission
   - If denied, go to System Settings → Privacy & Security → Automation

## Features to Test

Once the app is running, test these features:

- ✅ Menu bar icon appears
- ✅ Left-click toggles lyrics window
- ✅ Right-click shows menu
- ✅ Cmd+Shift+L keyboard shortcut works
- ✅ Window stays on top of other windows
- ✅ Window can be moved and resized
- ✅ Window position persists after restart
- ✅ Play a song in Spotify and lyrics appear
- ✅ Change tracks and lyrics update
- ✅ Pause Spotify and lyrics remain visible
- ✅ Quit Spotify and see "Open Spotify to see lyrics"

## Next Steps

After verifying the MVP works:

1. Test with various songs and edge cases
2. Adjust UI styling if needed (colors, fonts, spacing)
3. Consider future enhancements from SPECS.md:
   - Auto-scrolling synced lyrics
   - Lyrics caching
   - Customization options
   - Apple Music support

## Support

If you encounter issues:

1. Check the console in Xcode for error messages
2. Verify all permissions are granted
3. Make sure Spotify and Genius API are accessible
4. Review the SPECS.md for expected behavior

## License

This is a personal project. Ensure you comply with Spotify and Genius API terms of service.

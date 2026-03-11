# AlwaysOnLyrics

A macOS menu bar app that displays synchronized lyrics for your currently playing Spotify track in an always-on-top floating window.

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Real-time Spotify detection** — instantly picks up track changes via system notifications
- **Synced lyrics** — time-synced lyrics that auto-scroll as the song progresses
- **Always-on-top window** — floats above all other apps so you never lose your place
- **Customizable appearance** — adjust font size, opacity, and line spacing
- **Automatic updates** — built-in Sparkle updater keeps the app current
- **Lightweight** — lives in the menu bar, no Dock icon

## Requirements

- macOS 13.0 (Ventura) or later
- Spotify desktop app

## Installation

Download the latest `.dmg` from [Releases](https://github.com/xsaardo/alwaysonlyrics/releases), open it, and drag **AlwaysOnLyrics** to your Applications folder.

## Usage

- **Menu bar icon** — click to toggle the lyrics window
- **⌘⇧L** — show/hide the lyrics window from anywhere
- **Preferences** — right-click the menu bar icon → Preferences to customize appearance
- **Check for Updates** — right-click the menu bar icon → Check for Updates...

## Building from Source

1. Clone the repo
2. Open `AlwaysOnLyrics.xcodeproj` in Xcode 14+
3. Select the `AlwaysOnLyrics` scheme and hit **⌘R**

No API keys required — lyrics are fetched from [LRCLIB](https://lrclib.net), a free and open lyrics API.

## How It Works

- **Spotify monitoring** — uses `NSDistributedNotificationCenter` for instant track change events, with ScriptingBridge for the initial playback state on launch
- **Lyrics** — fetched from LRCLIB, which provides time-synced LRC lyrics for most tracks
- **UI** — built with SwiftUI; the window uses `.floating` level to stay on top across all Spaces and full-screen apps

## Project Structure

```
AlwaysOnLyrics/
├── AlwaysOnLyricsApp.swift    # App entry point
├── AppDelegate.swift           # Menu bar + Sparkle setup
├── Models/                     # Track, LyricLine, SyncedLyrics, AppSettings
├── Services/                   # SpotifyMonitor, LyricsService, LRCLIB client, LRC parser
└── Views/                      # LyricsWindow, LyricsView, LyricLineView, PreferencesWindow
```

## License

MIT

#!/usr/bin/env swift

import Foundation
import AppKit

print("Testing Spotify track duration access...")
print(String(repeating: "=", count: 50))

// AppleScript to test duration access
let script = """
tell application "Spotify"
    if it is running then
        try
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to duration of current track
            set artworkURL to artwork url of current track
            set isPlaying to player state is playing

            return trackName & "|" & artistName & "|" & albumName & "|" & trackDuration & "|" & artworkURL & "|" & isPlaying
        on error errMsg
            return "ERROR:" & errMsg
        end try
    else
        return "NOT_RUNNING"
    end if
end tell
"""

guard let appleScript = NSAppleScript(source: script) else {
    print("❌ Failed to create AppleScript")
    exit(1)
}

var error: NSDictionary?
let result = appleScript.executeAndReturnError(&error)

if let error = error {
    print("❌ AppleScript error:")
    print(error)
    exit(1)
}

guard let output = result.stringValue else {
    print("❌ No output from AppleScript")
    exit(1)
}

if output == "NOT_RUNNING" {
    print("⚠️  Spotify is not running")
    print("Please start Spotify and play a track, then run this test again")
    exit(0)
}

if output.hasPrefix("ERROR:") {
    print("❌ Error from Spotify:")
    print(output)
    exit(1)
}

print("✅ Successfully retrieved track info from Spotify!")
print("")

let components = output.components(separatedBy: "|")
print("Raw output components count: \(components.count)")
print("")

if components.count >= 6 {
    print("Track Information:")
    print("  📀 Title: \(components[0])")
    print("  🎤 Artist: \(components[1])")
    print("  💿 Album: \(components[2])")
    print("  ⏱️  Duration (ms): \(components[3])")

    // Convert duration from milliseconds to seconds
    if let durationMs = Int(components[3]) {
        let durationSeconds = Double(durationMs) / 1000.0
        print("  ⏱️  Duration (seconds): \(durationSeconds)")
        print("  ⏱️  Duration (formatted): \(Int(durationSeconds / 60)):\(String(format: "%02d", Int(durationSeconds.truncatingRemainder(dividingBy: 60))))")
    }

    print("  🖼️  Artwork URL: \(components[4])")
    print("  ▶️  Is Playing: \(components[5])")
    print("")
    print("✅ SUCCESS: Duration is accessible from Spotify!")
    print("   Duration format: Milliseconds (needs conversion to seconds)")
} else {
    print("⚠️  Unexpected output format:")
    print(output)
    print("")
    print("Expected 6 components, got \(components.count)")
}

#!/usr/bin/env swift

import Foundation

/// Simplified response model for LRCLIB API testing
struct LRCLIBTestResponse: Codable {
    let id: Int
    let trackName: String
    let plainLyrics: String?
    let syncedLyrics: String?
}

print("Testing LRCLIB API Integration...")
print(String(repeating: "=", count: 50))
print("")

// Test 1: Basic API connectivity
print("Test 1: Basic LRCLIB API connectivity")
print(String(repeating: "-", count: 40))

let testURL = URL(string: "https://lrclib.net/api/get?track_name=22&artist_name=taylor+swift&album_name=Red&duration=233")!
var request = URLRequest(url: testURL)
request.setValue("AlwaysOnLyrics/1.0 (https://github.com/xsaardo/alwaysonlyrics)", forHTTPHeaderField: "User-Agent")

let semaphore = DispatchSemaphore(value: 0)
var testPassed = false

URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
    defer { semaphore.signal() }

    if let error = error {
        print("❌ FAILED: Network error - \(error.localizedDescription)")
        return
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        print("❌ FAILED: Invalid response")
        return
    }

    print("   Status Code: \(httpResponse.statusCode)")

    guard let data = data else {
        print("❌ FAILED: No data received")
        return
    }

    do {
        let response = try JSONDecoder().decode(LRCLIBTestResponse.self, from: data)
        print("   ✅ SUCCESS: API is accessible")
        print("   Track ID: \(response.id)")
        print("   Track Name: \(response.trackName)")
        print("   Has Plain Lyrics: \(response.plainLyrics != nil)")
        print("   Has Synced Lyrics: \(response.syncedLyrics != nil)")
        testPassed = true
    } catch {
        print("❌ FAILED: JSON parsing error - \(error)")
    }
}.resume()

semaphore.wait()

print("")
print(String(repeating: "=", count: 50))

if testPassed {
    print("✅ LRCLIB Integration Test PASSED")
    print("")
    print("Next Steps:")
    print("1. Open AlwaysOnLyrics.xcodeproj in Xcode")
    print("2. Remove SwiftSoup from Package Dependencies")
    print("3. Build the project (Cmd+B)")
    print("4. Run the app and test with a real Spotify track")
} else {
    print("❌ LRCLIB Integration Test FAILED")
    print("Please check your internet connection and try again")
}

exit(testPassed ? 0 : 1)

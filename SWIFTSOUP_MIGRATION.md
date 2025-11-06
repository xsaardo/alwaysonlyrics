# SwiftSoup Migration Guide

## What Changed

We've refactored the HTML parsing to use **SwiftSoup** instead of regex, making the code:
- ✅ More readable and maintainable
- ✅ More reliable (proper HTML parsing vs regex)
- ✅ Easier to debug
- ✅ Similar to Cheerio (jQuery-like selectors)

## Files Modified

1. **`AlwaysOnLyrics/Services/LyricsHTMLParser.swift`**
   - Now uses SwiftSoup CSS selectors: `div[class*='Lyrics__Container']`
   - Replaces complex regex patterns
   - Better error handling

2. **`AlwaysOnLyrics/Utilities/HTMLCleaner.swift`**
   - Uses SwiftSoup for HTML cleaning and text extraction
   - Automatically decodes HTML entities
   - Falls back to regex if SwiftSoup fails

## Setup Instructions

### Step 1: Add SwiftSoup Package to Xcode

**IMPORTANT: You need to do this step manually in Xcode**

1. Open `AlwaysOnLyrics.xcodeproj` in Xcode
2. Click on the **project** (blue AlwaysOnLyrics icon) in the Project Navigator
3. Select the **AlwaysOnLyrics target** (not the project)
4. Click on the **"Package Dependencies"** tab (or "General" > "Frameworks, Libraries, and Embedded Content")
5. Click the **"+"** button at the bottom
6. In the search field, paste: `https://github.com/scinfu/SwiftSoup`
7. Click **"Add Package"**
8. Select **"Up to Next Major Version"** with `2.0.0` or later
9. Click **"Add Package"** again to confirm

### Step 2: Build the Project

After adding the package:
1. In Xcode, press **Cmd+B** to build
2. Make sure there are no errors
3. You should see "Build Succeeded"

### Step 3: Test the App

1. Run the app (Cmd+R) and verify lyrics display correctly
2. Or run the test script:
   ```bash
   cd /Users/cuongluong/Desktop/alwaysonlyrics
   ./run_lyrics_test.sh
   ```

## What SwiftSoup Gives Us

### Before (Regex)
```swift
let pattern = #"<div[^>]*class="[^"]*Lyrics__Container[^"]*"[^>]*>(.*?)</div>"#
let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
// Complex regex matching...
```

### After (SwiftSoup)
```swift
let doc = try SwiftSoup.parse(html)
let containers = try doc.select("div[class*='Lyrics__Container']")
for container in containers.array() {
    let text = try container.html()
}
```

## Benefits

1. **Readability**: CSS selectors are much clearer than regex
2. **Reliability**: Proper HTML parser handles edge cases
3. **Maintainability**: Easy to modify selectors
4. **Familiarity**: jQuery/Cheerio-like syntax
5. **Features**: Built-in HTML entity decoding, DOM traversal, etc.

## Troubleshooting

### If Build Fails with "No such module 'SwiftSoup'"
- Make sure you added the package correctly in Step 1
- Try: Product > Clean Build Folder (Shift+Cmd+K)
- Restart Xcode

### If Lyrics Don't Display
- Check console output for DEBUG messages
- The code will fall back to regex if SwiftSoup fails
- Look for "SwiftSoup parse error" or "SwiftSoup select error"

## Next Steps

After adding SwiftSoup:
1. ✅ Build succeeds
2. ✅ App runs and displays lyrics
3. ✅ Test script works
4. 🎉 Enjoy cleaner, more maintainable code!

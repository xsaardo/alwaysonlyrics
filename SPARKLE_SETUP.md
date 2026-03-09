# Sparkle Auto-Updates Setup Guide

This guide explains how to use Sparkle for automatic updates in AlwaysOnLyrics.

## Overview

**Sparkle** is the industry-standard framework for automatic updates in macOS apps. It's used by apps like Transmission, Sequel Pro, and many others.

**What's Already Configured:**
- ✅ Sparkle 2.8.1 added via Swift Package Manager
- ✅ Info.plist configured with update settings
- ✅ AppDelegate initialized with Sparkle updater
- ✅ "Check for Updates" menu items added
- ✅ appcast.xml template created
- ✅ create-dmg.sh script updated for signature generation

---

## First-Time Setup: Generate Sparkle Keys

Before your first release, you need to generate EdDSA keys for signing updates.

### Step 1: Locate Sparkle Tools

When using Sparkle via Swift Package Manager (SPM), the tools are located in the SPM artifacts directory:

```bash
# Navigate to your project directory
cd /Users/cuongluong/Desktop/alwaysonlyrics

# Find the Sparkle tools (they're downloaded with SPM)
# The path is typically in your DerivedData or SourcePackages
ls ~/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/sparkle/Sparkle/bin/

# Or navigate from your project
ls build/SourcePackages/artifacts/sparkle/Sparkle/bin/
```

### Step 2: Generate Keys

**Option A: Using SPM-downloaded tools (recommended)**

```bash
# Set path to Sparkle tools (adjust path as needed based on your system)
SPARKLE_TOOLS=~/Library/Developer/Xcode/DerivedData/AlwaysOnLyrics-*/SourcePackages/artifacts/sparkle/Sparkle/bin

# Or if that doesn't work, try build folder:
# SPARKLE_TOOLS=./build/SourcePackages/artifacts/sparkle/Sparkle/bin

# Generate EdDSA key pair
$SPARKLE_TOOLS/generate_keys
```

**Option B: Download Sparkle distribution separately**

```bash
# Download latest Sparkle
curl -LO https://github.com/sparkle-project/Sparkle/releases/download/2.8.1/Sparkle-2.8.1.tar.xz
tar -xf Sparkle-2.8.1.tar.xz

# Generate keys
./Sparkle-2.8.1/bin/generate_keys
```

This will output:
```
A key has been generated and saved in your Keychain (AlwaysOnLyrics Update Signing Key).
Add the public key to the Info.plist file of your app:

<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>

Private key:
YOUR_PRIVATE_KEY_HERE
```

### Step 3: Save Private Key

**IMPORTANT:** Keep your private key secure!

```bash
# Save the private key to a file (already gitignored)
echo "YOUR_PRIVATE_KEY_HERE" > sparkle_private_key

# Secure the file permissions
chmod 600 sparkle_private_key
```

### Step 4: Update Info.plist

Open `AlwaysOnLyrics/Info.plist` and replace:

```xml
<key>SUPublicEDKey</key>
<string>SPARKLE_PUBLIC_KEY_PLACEHOLDER</string>
```

With:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

---

## Creating a Release with Auto-Update Support

### Step 1: Update Version Numbers

Before building, update the version in two places:

**1. Info.plist** (`AlwaysOnLyrics/Info.plist`):
```xml
<key>CFBundleShortVersionString</key>
<string>1.1</string>  <!-- User-facing version -->
<key>CFBundleVersion</key>
<string>2</string>     <!-- Build number, must be incremented -->
```

**2. create-dmg.sh**:
```bash
VERSION="1.1"
```

### Step 2: Build and Package

```bash
./create-dmg.sh
```

This will:
1. Clean previous builds
2. Build the Release version
3. Create a DMG file
4. Generate Sparkle signature (if private key exists)
5. Output update information for appcast.xml

**Output Example:**
```
✨ Success! DMG created:
   📍 Location: /Users/cuongluong/Desktop/alwaysonlyrics/AlwaysOnLyrics-1.1.dmg
   📊 Size: 5.2M (5452800 bytes)

📝 Sparkle Update Information:
   File: AlwaysOnLyrics-1.1.dmg
   Size: 5452800
   Signature: mc3cD7...base64_signature...==

Add this to your appcast.xml:
   <enclosure
       url="https://github.com/xsaardo/alwaysonlyrics/releases/download/v1.1/AlwaysOnLyrics-1.1.dmg"
       sparkle:version="11"
       sparkle:shortVersionString="1.1"
       length="5452800"
       type="application/octet-stream"
       sparkle:edSignature="mc3cD7...base64_signature...==" />
```

### Step 3: Update appcast.xml

Add a new `<item>` at the **top** of the channel (newest first):

```xml
<item>
    <title>Version 1.1</title>
    <link>https://github.com/xsaardo/alwaysonlyrics/releases/tag/v1.1</link>
    <sparkle:version>2</sparkle:version>
    <sparkle:shortVersionString>1.1</sparkle:shortVersionString>
    <description><![CDATA[
        <h2>What's New in 1.1</h2>
        <ul>
            <li>Fixed synced lyrics scrolling bug</li>
            <li>Improved window positioning on multi-monitor setups</li>
            <li>Added dark mode support</li>
        </ul>
    ]]></description>
    <pubDate>Mon, 15 Jan 2025 12:00:00 +0000</pubDate>
    <enclosure
        url="https://github.com/xsaardo/alwaysonlyrics/releases/download/v1.1/AlwaysOnLyrics-1.1.dmg"
        sparkle:version="2"
        sparkle:shortVersionString="1.1"
        length="5452800"
        type="application/octet-stream"
        sparkle:edSignature="YOUR_SIGNATURE_FROM_SCRIPT_OUTPUT" />
</item>
```

**Important:**
- `sparkle:version` should match `CFBundleVersion` from Info.plist
- `sparkle:shortVersionString` should match `CFBundleShortVersionString`
- `length` is the file size in bytes
- `sparkle:edSignature` is the signature from the build script output

### Step 4: Create GitHub Release

```bash
# Create git tag
git tag v1.1
git push origin v1.1

# Create GitHub release (via web UI or gh CLI)
gh release create v1.1 \
    --title "AlwaysOnLyrics v1.1" \
    --notes "Release notes here" \
    AlwaysOnLyrics-1.1.dmg
```

### Step 5: Commit and Push appcast.xml

```bash
git add appcast.xml
git commit -m "Update appcast for v1.1 release"
git push origin main
```

**Important:** appcast.xml must be accessible at:
```
https://raw.githubusercontent.com/xsaardo/alwaysonlyrics/main/appcast.xml
```

---

## Testing Auto-Updates

### Before First Public Release

1. Build v1.0 with correct keys
2. Install v1.0 on your Mac
3. Create a test v1.1 release
4. Update appcast.xml
5. In the app, click "Check for Updates..."
6. Verify the update dialog appears
7. Test the update installation

### Manual Testing Commands

Check if Sparkle can read your appcast:

```bash
curl https://raw.githubusercontent.com/xsaardo/alwaysonlyrics/main/appcast.xml
```

Verify signature (requires Sparkle CLI tools):

```bash
verify_signature AlwaysOnLyrics-1.1.dmg \
    --public-key "YOUR_PUBLIC_KEY" \
    --signature "SIGNATURE_FROM_APPCAST"
```

---

## Update Frequency Settings

In `Info.plist`, these keys control update behavior:

```xml
<!-- Enable automatic update checks -->
<key>SUEnableAutomaticChecks</key>
<true/>

<!-- Check interval in seconds (86400 = 24 hours) -->
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
```

**Options:**
- `3600` = 1 hour (good for testing)
- `86400` = 24 hours (default, recommended)
- `604800` = 7 days (less frequent)

---

## Security Best Practices

### Protect Your Private Key

1. **Never commit** `sparkle_private_key` to git (already in .gitignore)
2. **Backup** the private key securely (password manager, encrypted backup)
3. **Restrict access** to the key file:
   ```bash
   chmod 600 sparkle_private_key
   ```

### If Private Key is Compromised

If your private key is leaked:

1. Generate new keys immediately
2. Update `SUPublicEDKey` in Info.plist
3. Release emergency update with new public key
4. All users will need to manually update once

**Prevention:** Store private key in:
- Password manager (1Password, Bitwarden)
- Encrypted disk image
- CI/CD secrets (GitHub Actions)

---

## Troubleshooting

### "Update failed to install"

**Cause:** Signature verification failed
**Solution:**
1. Verify public key in Info.plist matches your key
2. Re-run create-dmg.sh to get correct signature
3. Ensure appcast.xml has exact signature from script output

### "No updates available" but new version exists

**Cause:** Version comparison issue
**Solution:**
1. Ensure `sparkle:version` is higher than previous (use build number)
2. Check `CFBundleVersion` increments with each release
3. Example: 1.0 = version 1, 1.1 = version 2, 2.0 = version 3

### App doesn't check for updates automatically

**Cause:** SUEnableAutomaticChecks not set
**Solution:**
```xml
<key>SUEnableAutomaticChecks</key>
<true/>
```

### Signature mismatch error

**Cause:** DMG was modified after signing
**Solution:**
1. Rebuild DMG from scratch
2. Don't edit DMG after create-dmg.sh runs
3. Upload the exact DMG file that was signed

---

## CI/CD Integration (GitHub Actions)

Example workflow for automated releases:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Sparkle
        run: brew install sparkle

      - name: Setup Sparkle key
        run: |
          echo "${{ secrets.SPARKLE_PRIVATE_KEY }}" > sparkle_private_key
          chmod 600 sparkle_private_key

      - name: Build DMG
        run: ./create-dmg.sh

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: AlwaysOnLyrics-*.dmg
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Update appcast
        run: |
          # Script to automatically update appcast.xml
          # Then commit and push
```

**Setup:**
1. Add `SPARKLE_PRIVATE_KEY` to GitHub Secrets
2. Trigger workflow by pushing git tag
3. Manually update appcast.xml after release

---

## Delta Updates (Advanced)

Sparkle supports **delta updates** (only download changes, not full app):

### Benefits:
- Smaller downloads (100KB vs 5MB)
- Faster updates
- Less bandwidth

### Setup:
1. Install BinaryDelta tools:
   ```bash
   brew install create-dmg binarydelta
   ```

2. Generate delta patches:
   ```bash
   generate_appcast /path/to/releases
   ```

3. Add to appcast:
   ```xml
   <sparkle:deltaFrom version="1" deltaTo version="2">
       <enclosure url="delta-1-to-2.delta"
                  sparkle:deltaFrom="1"
                  length="102400"
                  sparkle:edSignature="..." />
   </sparkle:deltaFrom>
   ```

---

## Sparkle Configuration Reference

All available Info.plist keys:

| Key | Type | Description |
|-----|------|-------------|
| `SUFeedURL` | String | URL to appcast.xml |
| `SUPublicEDKey` | String | Public EdDSA key for signature verification |
| `SUEnableAutomaticChecks` | Boolean | Enable automatic update checks |
| `SUScheduledCheckInterval` | Integer | Check interval in seconds |
| `SUAutomaticallyUpdate` | Boolean | Install updates automatically (no prompt) |
| `SUAllowsAutomaticUpdates` | Boolean | Allow user to enable automatic updates |
| `SUEnableSystemProfiling` | Boolean | Send anonymous system info |
| `SUShowReleaseNotes` | Boolean | Display release notes in update dialog |

**For AlwaysOnLyrics:**
- We use automatic checks but require user confirmation
- Release notes shown in update dialog
- No system profiling (respects privacy)

---

## Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [Appcast Format](https://sparkle-project.org/documentation/publishing/)
- [EdDSA Signatures](https://sparkle-project.org/documentation/security/)

---

## Quick Reference: Release Checklist

- [ ] Update version in `Info.plist` (both CFBundleShortVersionString and CFBundleVersion)
- [ ] Update version in `create-dmg.sh`
- [ ] Run `./create-dmg.sh`
- [ ] Copy signature and file size from output
- [ ] Update `appcast.xml` with new release entry
- [ ] Create Git tag: `git tag v1.x`
- [ ] Push tag: `git push origin v1.x`
- [ ] Create GitHub Release and upload DMG
- [ ] Commit and push `appcast.xml`
- [ ] Test update on older version of the app
- [ ] Verify appcast.xml is accessible via raw.githubusercontent.com

---

*Last updated: 2025-12-02*
*Sparkle version: 2.8.1*

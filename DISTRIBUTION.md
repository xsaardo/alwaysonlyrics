# Distribution Guide for AlwaysOnLyrics

This guide explains how to package and distribute AlwaysOnLyrics to users.

## Quick Start: Creating a DMG

### Basic Usage

Simply run the packaging script:

```bash
./create-dmg.sh
```

This will:
1. Build the Release version of the app
2. Package it into a DMG file
3. Create an Applications symlink for easy installation
4. Output: `AlwaysOnLyrics-1.0.dmg`

### Testing the DMG

Before distributing:

1. Mount the DMG:
   ```bash
   open AlwaysOnLyrics-1.0.dmg
   ```

2. Drag the app to Applications and test it

3. Verify permissions work (Spotify automation, etc.)

---

## Distribution Options

### Option 1: GitHub Releases (Simplest)

**Pros**: Free, easy, built-in version control
**Cons**: Users will see Gatekeeper warning (unless notarized)

**Steps**:
1. Create DMG: `./create-dmg.sh`
2. Go to GitHub → Releases → Create New Release
3. Tag version (e.g., `v1.0`)
4. Upload `AlwaysOnLyrics-1.0.dmg`
5. Add installation instructions (see below)
6. Publish release

**Installation Instructions Template**:
```markdown
## Installation

1. Download `AlwaysOnLyrics-1.0.dmg`
2. Open the DMG file
3. Drag AlwaysOnLyrics to the Applications folder
4. Launch from Applications
5. Grant Spotify automation permission when prompted

**Security Note**: Since this app is not notarized, you may need to:
- Right-click → Open (first launch only)
- Or go to System Preferences → Security & Privacy → Allow
```

### Option 2: Notarized Distribution (Recommended)

**Pros**: No Gatekeeper warnings, professional
**Cons**: Requires Apple Developer Program ($99/year)

**Prerequisites**:
- Apple Developer Program membership
- Developer ID Application certificate

**Steps**:

1. **Sign the app**:
   ```bash
   codesign --deep --force --verify --verbose \
     --sign "Developer ID Application: Your Name (TEAM_ID)" \
     build/Build/Products/Release/AlwaysOnLyrics.app
   ```

2. **Create DMG**:
   ```bash
   ./create-dmg.sh
   ```

3. **Notarize the DMG**:
   ```bash
   # Create app-specific password at appleid.apple.com
   xcrun notarytool submit AlwaysOnLyrics-1.0.dmg \
     --apple-id "your@email.com" \
     --team-id "TEAM_ID" \
     --password "app-specific-password" \
     --wait
   ```

4. **Staple notarization**:
   ```bash
   xcrun stapler staple AlwaysOnLyrics-1.0.dmg
   ```

5. **Verify**:
   ```bash
   spctl -a -t open --context context:primary-signature -v AlwaysOnLyrics-1.0.dmg
   ```

### Option 3: Mac App Store

See `CLAUDE.md` for Mac App Store requirements. Your app is already sandboxed and ready!

---

## Advanced: Custom DMG Appearance

To add a custom background image to your DMG:

1. **Create background image**:
   ```bash
   mkdir -p dmg_assets
   # Add your 600x400 PNG image as dmg_assets/background.png
   ```

2. **Run script** (it will auto-detect the background):
   ```bash
   ./create-dmg.sh
   ```

3. **Manual customization** (optional):
   - Mount the DMG
   - Open in Finder
   - Press Cmd+J for View Options
   - Drag to set icon positions
   - Set background image
   - Close and eject
   - Use `hdiutil convert` to make read-only

---

## Updating the Version

Before creating a new release:

1. Update version in `AlwaysOnLyrics/Info.plist`:
   ```xml
   <key>CFBundleShortVersionString</key>
   <string>1.1</string>
   <key>CFBundleVersion</key>
   <string>2</string>
   ```

2. Update version in `create-dmg.sh`:
   ```bash
   VERSION="1.1"
   ```

3. Run the script:
   ```bash
   ./create-dmg.sh
   ```

---

## Troubleshooting

### Issue: "App is damaged and can't be opened"

**Cause**: Gatekeeper quarantine attribute
**Solution**:
```bash
xattr -cr /Applications/AlwaysOnLyrics.app
```

### Issue: Build fails with code signing error

**Cause**: Unsigned build for distribution
**Solution**: Either:
- Sign with Developer ID (see Option 2 above)
- Or distribute as-is with installation instructions

### Issue: DMG creation fails

**Cause**: Old build artifacts
**Solution**:
```bash
rm -rf build dmg_temp *.dmg
./create-dmg.sh
```

---

## CI/CD Integration (Future)

To automate DMG creation with GitHub Actions:

```yaml
- name: Build and Package
  run: |
    ./create-dmg.sh

- name: Upload Release Asset
  uses: actions/upload-release-asset@v1
  with:
    upload_url: ${{ steps.create_release.outputs.upload_url }}
    asset_path: ./AlwaysOnLyrics-${{ github.ref_name }}.dmg
    asset_name: AlwaysOnLyrics-${{ github.ref_name }}.dmg
    asset_content_type: application/x-apple-diskimage
```

---

## Automatic Updates (Optional)

To add auto-update functionality:

1. **Install Sparkle framework**:
   - Add to Xcode via SPM: `https://github.com/sparkle-project/Sparkle`
   - Configure in AppDelegate

2. **Host appcast.xml** with version info

3. **Users get notifications** for new versions

See [Sparkle Documentation](https://sparkle-project.org/) for details.

---

## Checklist for First Release

- [ ] Test app thoroughly on clean macOS install
- [ ] Update version numbers in Info.plist
- [ ] Run `./create-dmg.sh` successfully
- [ ] Test DMG installation on another Mac
- [ ] Write release notes
- [ ] Create GitHub Release with DMG attached
- [ ] Update README with download link
- [ ] Test download link from GitHub

---

*Last updated: 2025-11-10*

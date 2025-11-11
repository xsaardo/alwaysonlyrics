#!/bin/bash

# AlwaysOnLyrics DMG Creation Script
# This script builds the app and packages it into a distributable DMG

set -e  # Exit on error

# Configuration
APP_NAME="AlwaysOnLyrics"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="build"
TEMP_DMG_DIR="dmg_temp"
BACKGROUND_DIR="dmg_assets"

echo "🚀 Building ${APP_NAME} v${VERSION}..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${TEMP_DMG_DIR}"
rm -f "${DMG_NAME}.dmg"

# Clean extended attributes that can cause signing issues
echo "🧹 Cleaning extended attributes..."
xattr -cr . 2>/dev/null || true

# Build the app
echo "🔨 Building Release version..."
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build

# Find the built app
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: Built app not found at ${APP_PATH}"
    exit 1
fi

echo "✅ Build successful: ${APP_PATH}"

# Create temporary directory for DMG contents
echo "📦 Preparing DMG contents..."
mkdir -p "${TEMP_DMG_DIR}"

# Copy the app
cp -R "${APP_PATH}" "${TEMP_DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${TEMP_DMG_DIR}/Applications"

# Optional: Add background image if it exists
if [ -f "${BACKGROUND_DIR}/background.png" ]; then
    mkdir -p "${TEMP_DMG_DIR}/.background"
    cp "${BACKGROUND_DIR}/background.png" "${TEMP_DMG_DIR}/.background/"
fi

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${TEMP_DMG_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}.dmg"

# Clean up
echo "🧹 Cleaning up..."
rm -rf "${TEMP_DMG_DIR}"

# Get DMG size
DMG_SIZE=$(du -h "${DMG_NAME}.dmg" | cut -f1)

echo ""
echo "✨ Success! DMG created:"
echo "   📍 Location: $(pwd)/${DMG_NAME}.dmg"
echo "   📊 Size: ${DMG_SIZE}"
echo ""
echo "Next steps:"
echo "  1. Test the DMG by mounting and installing"
echo "  2. If you have a Developer ID, sign and notarize for distribution"
echo "  3. Upload to GitHub Releases or your website"
echo ""

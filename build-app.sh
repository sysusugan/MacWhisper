#!/bin/bash
# =============================================================================
# RELEASE BUILD SCRIPT (ad-hoc signing)
#
# This script builds a release .app bundle and DMG with ad-hoc code signing
# (codesign --sign -). Ad-hoc signing generates a new signature every build,
# which means macOS TCC permissions (Accessibility, Input Monitoring, etc.)
# will be invalidated after each rebuild.
#
# For DEVELOPMENT builds that preserve TCC permissions across rebuilds,
# use the dev build script instead:
#
#   ./scripts/dev-build.sh          # build only
#   ./scripts/dev-build.sh --run    # build and launch
#
# The dev script uses a stable self-signed certificate ("PsstFree Dev") so
# permissions persist. Run ./scripts/setup-dev-cert.sh first to create it.
# =============================================================================
set -e

APP_NAME="Psst Free"
BUNDLE_NAME="PsstFree"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"
DMG_NAME="PsstFree-1.0.0"

echo "=== Building release binary ==="
swift build -c release

echo "=== Creating .app bundle ==="
rm -rf dist
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${BUNDLE_NAME}" "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}"

# Copy Info.plist
cp PsstFree/Info.plist "${APP_DIR}/Contents/Info.plist"

# Copy Resources (if any compiled resources exist)
if [ -d "${BUILD_DIR}/PsstFree_PsstFree.bundle" ]; then
    cp -R "${BUILD_DIR}/PsstFree_PsstFree.bundle" "${APP_DIR}/Contents/Resources/"
fi

# Sign with entitlements (ad-hoc for local distribution)
# IMPORTANT: Sign the executable directly with entitlements first,
# then sign the outer bundle. Using --deep alone may not embed
# entitlements correctly on the main executable with ad-hoc signing.
echo "=== Signing app ==="
codesign --force --sign - \
    --entitlements PsstFree/PsstFree.entitlements \
    "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}"

codesign --force --sign - \
    --entitlements PsstFree/PsstFree.entitlements \
    "${APP_DIR}"

# Verify entitlements are embedded
echo "=== Verifying entitlements ==="
codesign -d --entitlements - "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}" 2>&1 || true

echo "=== Creating DMG ==="
# Create a temporary DMG folder
DMG_TEMP="dist/dmg_temp"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_DIR}" "${DMG_TEMP}/"

# Create a symlink to Applications
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "dist/${DMG_NAME}.dmg"

# Cleanup
rm -rf "${DMG_TEMP}"

echo ""
echo "=== Done! ==="
echo "App:  dist/${APP_NAME}.app"
echo "DMG:  dist/${DMG_NAME}.dmg"
echo ""
echo "To install: open the DMG and drag to Applications."
echo "Note: Users will need to grant Accessibility + Microphone permissions on first launch."

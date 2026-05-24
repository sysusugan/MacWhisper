#!/bin/bash
set -e

APP_NAME="MacWhisper"
BUNDLE_NAME="MacWhisper"
BUILD_DIR=".build/debug"
APP_DIR="dist-dev/${APP_NAME}.app"
CERT_NAME="MacWhisper Dev"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RUN_AFTER_BUILD=false
RESET_TCC=false
for arg in "$@"; do
    case "$arg" in
        --run) RUN_AFTER_BUILD=true ;;
        --reset-tcc) RESET_TCC=true ;;
    esac
done

cd "$PROJECT_DIR"

# Step 1: Optionally reset stale TCC entries (only needed if signing identity changed)
if [ "$RESET_TCC" = true ]; then
    echo "=== Resetting TCC entries ==="
    "$SCRIPT_DIR/reset-tcc.sh"
else
    echo "=== Skipping TCC reset (use --reset-tcc if permissions are stale) ==="
fi

# Step 2: Check for signing identity
echo ""
echo "=== Checking signing identity ==="
if ! security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "ERROR: Signing identity '$CERT_NAME' not found."
    echo ""
    echo "Run this first to create it:"
    echo "  ./scripts/setup-dev-cert.sh"
    exit 1
fi
echo "  Found '$CERT_NAME' identity."

# Step 3: Build debug binary
echo ""
echo "=== Building debug binary ==="
swift build -c debug

# Step 4: Create .app bundle
echo ""
echo "=== Creating .app bundle ==="
rm -rf "dist-dev"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${BUNDLE_NAME}" "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}"

# Copy Info.plist
cp MacWhisper/Info.plist "${APP_DIR}/Contents/Info.plist"

# Copy Resources (if any compiled resources exist)
if [ -d "${BUILD_DIR}/MacWhisper_MacWhisper.bundle" ]; then
    cp -R "${BUILD_DIR}/MacWhisper_MacWhisper.bundle" "${APP_DIR}/Contents/Resources/"
fi
if [ -f "MacWhisper/Resources/MacWhisper.icns" ]; then
    cp "MacWhisper/Resources/MacWhisper.icns" "${APP_DIR}/Contents/Resources/"
fi

# Copy Sparkle.framework into Frameworks/
SPARKLE_FW=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    mkdir -p "${APP_DIR}/Contents/Frameworks"
    cp -R "$SPARKLE_FW" "${APP_DIR}/Contents/Frameworks/"
fi

# Step 4b: Fix rpath so the binary finds Sparkle.framework in Frameworks/
install_name_tool -add_rpath @executable_path/../Frameworks "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}" 2>/dev/null || true

# Step 5: Sign with dev certificate
echo ""
echo "=== Signing app with '$CERT_NAME' ==="
codesign --force --sign "$CERT_NAME" \
    --entitlements MacWhisper/MacWhisper.entitlements \
    "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}"

codesign --force --sign "$CERT_NAME" \
    --entitlements MacWhisper/MacWhisper.entitlements \
    "${APP_DIR}"

# Step 6: Verify signature
echo ""
echo "=== Verifying signature ==="
codesign --verify --verbose "${APP_DIR}"
echo "  Signature valid."

echo ""
echo "=== Verifying entitlements ==="
codesign -d --entitlements - "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}" 2>&1 || true

echo ""
echo "=== Done! ==="
echo "App: ${APP_DIR}"
echo ""
echo "Because this is signed with a stable identity, TCC permissions"
echo "(Accessibility, Input Monitoring) will persist across rebuilds."

# Step 7: Optionally launch
if [ "$RUN_AFTER_BUILD" = true ]; then
    echo ""
    echo "=== Killing old instance ==="
    pkill -x MacWhisper 2>/dev/null && sleep 0.5 || true
    echo "=== Launching app ==="
    open "${APP_DIR}"
fi

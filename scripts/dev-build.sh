#!/bin/bash
set -e

APP_NAME="Psst Free"
BUNDLE_NAME="PsstFree"
BUILD_DIR=".build/debug"
APP_DIR="dist-dev/${APP_NAME}.app"
CERT_NAME="PsstFree Dev"
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
cp PsstFree/Info.plist "${APP_DIR}/Contents/Info.plist"

# Copy Resources (if any compiled resources exist)
if [ -d "${BUILD_DIR}/PsstFree_PsstFree.bundle" ]; then
    cp -R "${BUILD_DIR}/PsstFree_PsstFree.bundle" "${APP_DIR}/Contents/Resources/"
fi

# Step 5: Sign with dev certificate
echo ""
echo "=== Signing app with '$CERT_NAME' ==="
codesign --force --sign "$CERT_NAME" \
    --entitlements PsstFree/PsstFree.entitlements \
    "${APP_DIR}/Contents/MacOS/${BUNDLE_NAME}"

codesign --force --sign "$CERT_NAME" \
    --entitlements PsstFree/PsstFree.entitlements \
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
    pkill -x PsstFree 2>/dev/null && sleep 0.5 || true
    echo "=== Launching app ==="
    open "${APP_DIR}"
fi

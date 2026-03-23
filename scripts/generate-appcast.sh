#!/bin/bash
# =============================================================================
# APPCAST GENERATOR
#
# Generates a Sparkle appcast.xml for auto-updates.
# Run after building a notarized DMG.
#
# Prerequisites:
#   - Sparkle's generate_appcast tool (installed via `brew install sparkle`)
#   - A Sparkle EdDSA key pair (generate with `generate_keys` from Sparkle)
#
# Usage:
#   ./scripts/generate-appcast.sh
#
# This reads DMGs from dist/ and generates website/appcast.xml
# Upload appcast.xml + DMG to your hosting.
# =============================================================================
set -e

DIST_DIR="dist"
OUTPUT_DIR="website"
APPCAST_FILE="${OUTPUT_DIR}/appcast.xml"

if ! command -v generate_appcast &> /dev/null; then
    echo "Error: generate_appcast not found."
    echo "Install Sparkle tools: brew install sparkle"
    echo "Or download from https://github.com/sparkle-project/Sparkle/releases"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Generating appcast from DMGs in ${DIST_DIR}/ ==="
generate_appcast "$DIST_DIR" --output "$APPCAST_FILE"

echo ""
echo "=== Appcast generated ==="
echo "File: ${APPCAST_FILE}"
echo ""
echo "Next steps:"
echo "  1. Upload the DMG to your download server"
echo "  2. Update the <enclosure url=\"...\"> in appcast.xml to match the download URL"
echo "  3. Upload appcast.xml to match SUFeedURL in Info.plist"
echo "     Current SUFeedURL: https://psstfree.com/appcast.xml"

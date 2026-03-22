#!/bin/bash

# Development helper: Reset TCC (Transparency, Consent, and Control) database
# entries for Psst Free to prevent stale permission prompts after rebuilds.
#
# Usage:
#   ./scripts/reset-tcc.sh         # Reset Accessibility, Input Monitoring, ScreenCapture
#   ./scripts/reset-tcc.sh --all   # Reset ALL TCC categories for the bundle ID
#
# NOTE: This may require running with sudo or as an admin user depending on
# your macOS version and SIP configuration. If you get "not modified" results,
# try: sudo ./scripts/reset-tcc.sh

BUNDLE_ID="com.psst.free"

echo "Resetting TCC entries for ${BUNDLE_ID}..."

if [ "$1" = "--all" ]; then
    echo "  -> Resetting ALL TCC categories..."
    tccutil reset All "${BUNDLE_ID}"
else
    echo "  -> Resetting Accessibility permission..."
    tccutil reset Accessibility "${BUNDLE_ID}"

    echo "  -> Resetting ListenEvent (Input Monitoring) permission..."
    tccutil reset ListenEvent "${BUNDLE_ID}"

    echo "  -> Resetting ScreenCapture permission..."
    tccutil reset ScreenCapture "${BUNDLE_ID}"
fi

echo ""
echo "Done. TCC entries for ${BUNDLE_ID} have been reset."
echo "The app will prompt for permissions again on next launch."

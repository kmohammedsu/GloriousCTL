#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build/GloriousCTL.app}"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
ARCHIVE="$ROOT/build/GloriousCTL-$VERSION.zip"

codesign --verify --deep --strict --verbose=2 "$APP"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
elif [ -n "${APPLE_API_KEY_PATH:-}" ] && [ -n "${APPLE_API_KEY_ID:-}" ] && [ -n "${APPLE_API_ISSUER_ID:-}" ]; then
    xcrun notarytool submit "$ARCHIVE" \
        --key "$APPLE_API_KEY_PATH" \
        --key-id "$APPLE_API_KEY_ID" \
        --issuer "$APPLE_API_ISSUER_ID" \
        --wait
else
    echo "Set NOTARY_KEYCHAIN_PROFILE or the APPLE_API_KEY_PATH, APPLE_API_KEY_ID, and APPLE_API_ISSUER_ID variables."
    exit 1
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"

echo "==> Notarized $APP"
echo "==> Release archive $ARCHIVE"

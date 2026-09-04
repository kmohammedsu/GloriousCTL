#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
VERSION="${GLORIOUSCTL_VERSION:-1.0.0}"
APP="$ROOT/build/GloriousCTL.app"
SWIFT_FLAGS=(--disable-sandbox)
ARCH_FLAGS=()

if [ "$CONFIG" = "release" ]; then
    read -r -a ARCHITECTURES <<< "${GLORIOUSCTL_ARCHS:-arm64 x86_64}"
    for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
        ARCH_FLAGS+=(--arch "$ARCHITECTURE")
    done
fi

echo "==> Testing"
swift test --package-path "$ROOT" "${SWIFT_FLAGS[@]}"

echo "==> Compiling ($CONFIG)"
swift build --package-path "$ROOT" "${SWIFT_FLAGS[@]}" "${ARCH_FLAGS[@]}" -c "$CONFIG" --product GloriousCTL
swift build --package-path "$ROOT" "${SWIFT_FLAGS[@]}" "${ARCH_FLAGS[@]}" -c "$CONFIG" --product gloriousctl-probe
BIN="$(swift build --package-path "$ROOT" "${SWIFT_FLAGS[@]}" "${ARCH_FLAGS[@]}" -c "$CONFIG" --show-bin-path)"

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GloriousCTL" "$APP/Contents/MacOS/GloriousCTL"
cp "$BIN/gloriousctl-probe" "$APP/Contents/MacOS/gloriousctl-probe"
if [ -d "$BIN/GloriousCTL_GloriousCTL.bundle" ]; then
    cp -R "$BIN/GloriousCTL_GloriousCTL.bundle" "$APP/Contents/Resources/"
fi
cp "$ROOT/Sources/GloriousCTL/Resources/GloriousCTL.icns" \
   "$APP/Contents/Resources/GloriousCTL.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                  <string>GloriousCTL</string>
    <key>CFBundleDisplayName</key>           <string>GloriousCTL</string>
    <key>CFBundleIdentifier</key>            <string>io.github.kmohammedsu.gloriousctl</string>
    <key>CFBundleDevelopmentRegion</key>     <string>en</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleVersion</key>               <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>    <string>$VERSION</string>
    <key>CFBundleExecutable</key>            <string>GloriousCTL</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleIconFile</key>               <string>GloriousCTL</string>
    <key>LSMinimumSystemVersion</key>        <string>13.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSPrincipalClass</key>              <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>     <string>public.app-category.utilities</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>GloriousCTL performs macOS actions, opens selected items, and runs Shortcuts assigned to mouse gestures and action rings.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>GloriousCTL needs Input Monitoring to read and write your mouse's onboard settings, because the mouse exposes them on an interface that also declares a keyboard usage.</string>
</dict>
</plist>
PLIST

echo "==> Signing"
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
                | awk -F '"' '/Developer ID Application/{print $2; exit}')"
    if [ -z "$IDENTITY" ] && [ "$CONFIG" != "release" ]; then
        IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
                    | awk -F '"' '/Apple Development/{print $2; exit}')"
    fi
fi
if [ -z "$IDENTITY" ]; then
    IDENTITY="-"
    echo "    no signing identity found; falling back to ad-hoc."
    echo "    Input Monitoring will need re-granting after each rebuild."
else
    echo "    using identity $IDENTITY"
fi

SIGN_FLAGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" = "-" ]; then
    SIGN_FLAGS+=(--timestamp=none)
else
    SIGN_FLAGS+=(--options runtime --timestamp)
fi

codesign "${SIGN_FLAGS[@]}" "$APP/Contents/MacOS/gloriousctl-probe"
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --deep --strict --verbose=1 "$APP" 2>&1 | sed 's/^/    /'

if [ "${GLORIOUSCTL_INSTALL:-1}" = "1" ]; then
    if [ -w /Applications ] || [ -w /Applications/GloriousCTL.app ]; then
        INSTALL="/Applications/GloriousCTL.app"
    else
        INSTALL="$HOME/Applications/GloriousCTL.app"
    fi
    echo "==> Installing to $INSTALL"
    mkdir -p "$HOME/Applications"
    if [ -d "$INSTALL" ]; then
        ditto "$APP" "$INSTALL"
    else
        cp -R "$APP" "$INSTALL"
    fi
    codesign --verify --deep --strict "$INSTALL" && echo "    signature verified"
    echo "==> Installed $INSTALL"
else
    echo "==> Skipped installation"
fi

echo "==> Built $APP"

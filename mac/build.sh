#!/bin/zsh
# Builds "AZ Zikr.app" into mac/dist/ (and installs it to /Applications with --install).
set -e
cd "$(dirname "$0")"
swift build -c release
.build/release/AZZikr --make-icon Resources/icon-1024.png
APP="dist/AZ Zikr.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AZZikr "$APP/Contents/MacOS/AZZikr"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R ../web "$APP/Contents/Resources/web"   # shared UI (same files the Windows build uses)

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
echo "Built: $APP"

if [[ "$1" == "--install" ]]; then
  pkill -x AZZikr 2>/dev/null || true
  rm -rf "/Applications/AZ Zikr.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/AZ Zikr.app"
fi

# ./build.sh --dmg → dist/AZ-Zikr-<version>.dmg (drag-to-Applications), the file you send people.
if [[ "$1" == "--dmg" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
  STAGE="$(mktemp -d)/AZ Zikr"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  cp "Resources/اقرأني - أول مرة.txt" "$STAGE/" 2>/dev/null || true
  DMG="dist/AZ-Zikr-$VERSION.dmg"
  rm -f "$DMG"
  hdiutil create -volname "AZ Zikr" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  echo "DMG: $DMG"
fi

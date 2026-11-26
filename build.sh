#!/bin/zsh
# Builds "Fairy Journal.app" and puts it in ~/Applications.
set -e
cd "$(dirname "$0")"
APP="build/Fairy Journal.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" \
  "$APP/Contents/Resources"

swiftc -O -swift-version 5 main.swift \
  -o "$APP/Contents/MacOS/FairyJournal"
cp web/index.html web/PINKFAIRY-LICENSE.txt \
  "$APP/Contents/Resources/"

# icon
mkdir -p build/px build/AppIcon.iconset
swiftc -swift-version 5 icon.swift -o build/icon
build/icon build/px
I=build/AppIcon.iconset
for n in 16 32 128 256 512; do
  cp build/px/px_$n.png $I/icon_${n}x${n}.png
  cp build/px/px_$((n*2)).png $I/icon_${n}x${n}@2x.png
done
iconutil -c icns $I -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Fairy Journal</string>
  <key>CFBundleDisplayName</key><string>Fairy Journal</string>
  <key>CFBundleIdentifier</key>
  <string>local.fairyjournal</string>
  <key>CFBundleExecutable</key><string>FairyJournal</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force -s - "$APP"
rm -rf ~/Applications/"Fairy Journal.app"
cp -R "$APP" ~/Applications/
echo "installed: ~/Applications/Fairy Journal.app"

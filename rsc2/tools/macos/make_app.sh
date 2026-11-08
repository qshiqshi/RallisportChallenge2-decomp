#!/bin/sh
# A double-clickable app for this build: the bundle's executable is a small
# script that starts rsc2 in its build directory (where game/ is linked), so
# the launcher window, settings and game behave exactly as from run.sh.
# The output of a run goes to ~/Library/Logs/rsc2.log.
# The icon: work/AppIcon.png (any square artwork, kept out of git) put into
# the macOS icon shape, else the one make_icon.swift draws.
#   rsc2/tools/macos/make_app.sh [/Applications]
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$(cd "$HERE/../../build" && pwd)"
DEST="${1:-/Applications}"
APP="$DEST/RalliSport Challenge 2.app"
[ -x "$BUILD/rsc2" ] || { echo "no $BUILD/rsc2 -- build first" >&2; exit 1; }
[ -e "$BUILD/game/default.xbe" ] || echo "note: $BUILD/game/default.xbe is missing" >&2
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>RalliSport Challenge 2</string>
    <key>CFBundleDisplayName</key><string>RalliSport Challenge 2</string>
    <key>CFBundleIdentifier</key><string>local.rsc2.recomp</string>
    <key>CFBundleExecutable</key><string>rsc2-start</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.4</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.racing-games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
cat > "$APP/Contents/MacOS/rsc2-start" <<START
#!/bin/sh
cd "$BUILD" || exit 1
mkdir -p "\$HOME/Library/Logs"
exec ./rsc2 "\$@" >> "\$HOME/Library/Logs/rsc2.log" 2>&1
START
chmod +x "$APP/Contents/MacOS/rsc2-start"

# The icon, as an .icns with every size macOS asks for.
TMP="$(mktemp -d)"
ART="$HERE/../../../work/AppIcon.png"
if [ -f "$ART" ]; then
    swiftc -O -o "$TMP/icon_mask" "$HERE/icon_mask.swift" 2>/dev/null
    "$TMP/icon_mask" "$ART" "$TMP/icon.png"
else
    swiftc -O -o "$TMP/make_icon" "$HERE/make_icon.swift" 2>/dev/null
    "$TMP/make_icon" "$TMP/icon.png"
fi
mkdir -p "$TMP/AppIcon.iconset" "$APP/Contents/Resources"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
echo "$APP"

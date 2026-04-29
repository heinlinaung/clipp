#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Clipp"
BUNDLE_ID="com.kakashi.clipp"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building release binary"
swift build -c release --arch arm64 --arch x86_64

BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
    echo "Release binary not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

VERSION="${CLIPP_VERSION:-0.1.0}"
BUILD="${CLIPP_BUILD:-1}"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo "==> Generating icon"
ICON_SRC="$(mktemp -d)/icon.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

# Render a simple square icon with the app initial via /usr/bin/sips + a generated PNG.
# We use a small Python one-liner to create a 1024x1024 PNG with a colored background and a "C".
/usr/bin/python3 - "$ICON_SRC" <<'PY'
import sys, struct, zlib, os

# Build a minimal 1024x1024 PNG: dark teal background with a white rounded square + "C"-ish glyph.
# We avoid Pillow (not always installed) by hand-writing pixels.
SIZE = 1024
bg = (0x12, 0x1B, 0x24, 0xFF)         # dark slate
fg = (0x6E, 0xC5, 0xE9, 0xFF)         # accent cyan
white = (0xF5, 0xF7, 0xFA, 0xFF)

def in_round_rect(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1: return False
    # corner test
    cx = max(x0 + r, min(x, x1 - r))
    cy = max(y0 + r, min(y, y1 - r))
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r

# Big rounded square in accent
sq = (96, 96, SIZE - 96, SIZE - 96, 180)
# Inner stroke / "C" shape: ring with mouth opening on the right
cx, cy = SIZE // 2, SIZE // 2
outer_r = 340
inner_r = 230

rows = bytearray()
for y in range(SIZE):
    rows.append(0)  # filter
    for x in range(SIZE):
        px = bg
        if in_round_rect(x, y, *sq):
            px = fg
            dx, dy = x - cx, y - cy
            d2 = dx*dx + dy*dy
            if d2 <= outer_r*outer_r:
                if d2 >= inner_r*inner_r:
                    # mouth: cut a wedge on the right
                    if not (dx > 0 and abs(dy) < 130):
                        px = white
                else:
                    px = fg
        rows += bytes(px)

def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(bytes(rows), 9))
png += chunk(b'IEND', b'')

with open(sys.argv[1], 'wb') as f:
    f.write(png)
PY

for SZ in 16 32 64 128 256 512 1024; do
    DOUBLE=$((SZ * 2))
    /usr/bin/sips -z "$SZ" "$SZ" "$ICON_SRC" --out "$ICONSET/icon_${SZ}x${SZ}.png" >/dev/null
    if [[ "$DOUBLE" -le 1024 ]]; then
        /usr/bin/sips -z "$DOUBLE" "$DOUBLE" "$ICON_SRC" --out "$ICONSET/icon_${SZ}x${SZ}@2x.png" >/dev/null
    fi
done

/usr/bin/iconutil -c icns -o "$RESOURCES/AppIcon.icns" "$ICONSET"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist"

echo "==> Ad-hoc signing"
/usr/bin/codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
du -sh "$APP" | awk '{print "    size:", $1}'

#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RES="$PROJECT_DIR/Resources"
SRC="${1:-$RES/AppIcon.png}"
ICONSET="$RES/AppIcon.iconset"
ICNS="$RES/AppIcon.icns"
TMP=$(mktemp -d)
PYTHON="${PYTHON:-python3}"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

if [ ! -f "$SRC" ]; then
  echo "Source image not found: $SRC" >&2
  exit 1
fi

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "python3 is required to fix icon corners" >&2
  exit 1
fi

mkdir -p "$RES"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

W=$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')
H=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/ {print $2}')
SIDE=$W
[ "$H" -lt "$SIDE" ] && SIDE=$H

cp "$SRC" "$TMP/source"
sips -c "$SIDE" "$SIDE" "$TMP/source" --out "$TMP/square" >/dev/null
sips -z 1024 1024 "$TMP/square" --out "$TMP/master" >/dev/null
sips -s format png "$TMP/master" --out "$TMP/master.png" >/dev/null

"$PYTHON" "$PROJECT_DIR/scripts/fix-icon-corners.py" "$TMP/master.png" "$RES/AppIcon.png"

make_icon() {
  local px=$1 name=$2
  sips -z "$px" "$px" "$RES/AppIcon.png" --out "$TMP/out.png" >/dev/null
  sips -s format png "$TMP/out.png" --out "$ICONSET/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Generated $ICNS"

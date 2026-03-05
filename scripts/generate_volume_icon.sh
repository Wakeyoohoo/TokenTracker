#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$PROJECT_ROOT/packaging"
ICONSET_DIR="$OUT_DIR/TokenTrackerVolumeIcon.iconset"
BASE_PNG="$OUT_DIR/TokenTrackerVolumeIcon_1024.png"
ICNS_PATH="$OUT_DIR/TokenTrackerVolumeIcon.icns"

mkdir -p "$OUT_DIR"

cat > /tmp/generate_tokentracker_volume_icon.swift <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let canvas = NSRect(origin: .zero, size: size)

// Rounded background
let bgPath = NSBezierPath(roundedRect: canvas, xRadius: 220, yRadius: 220)
NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.18, alpha: 1.0).setFill()
bgPath.fill()

// Main gradient layer
let mainGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.96, alpha: 1.0),
    NSColor(calibratedRed: 0.16, green: 0.80, blue: 0.62, alpha: 1.0)
])!
let innerRect = canvas.insetBy(dx: 56, dy: 56)
mainGradient.draw(in: NSBezierPath(roundedRect: innerRect, xRadius: 180, yRadius: 180), angle: -35)

// Token ring
let ringRect = NSRect(x: 212, y: 210, width: 600, height: 600)
let ringPath = NSBezierPath(ovalIn: ringRect)
ringPath.lineWidth = 56
NSColor(calibratedWhite: 1.0, alpha: 0.93).setStroke()
ringPath.stroke()

// Tracker bars
let barColor = NSColor(calibratedWhite: 1.0, alpha: 0.95)
barColor.setFill()
let barW: CGFloat = 86
let gap: CGFloat = 72
let startX: CGFloat = 332
let baseY: CGFloat = 342
let heights: [CGFloat] = [190, 286, 146]

for (idx, height) in heights.enumerated() {
    let x = startX + CGFloat(idx) * (barW + gap)
    let rect = NSRect(x: x, y: baseY, width: barW, height: height)
    NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24).fill()
}

// Top token dot
let dotRect = NSRect(x: 606, y: 594, width: 86, height: 86)
NSBezierPath(ovalIn: dotRect).fill()

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon image\n", stderr)
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
SWIFT

swift /tmp/generate_tokentracker_volume_icon.swift "$BASE_PNG"

# Ensure the base file is exactly 1024x1024 pixels.
TMP_BASE_PNG="$OUT_DIR/.TokenTrackerVolumeIcon_1024.tmp.png"
sips -z 1024 1024 "$BASE_PNG" --out "$TMP_BASE_PNG" >/dev/null
mv -f "$TMP_BASE_PNG" "$BASE_PNG"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$BASE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

echo "Generated:"
ls -lh "$BASE_PNG" "$ICNS_PATH"

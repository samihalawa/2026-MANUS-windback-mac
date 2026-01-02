#!/bin/bash

# Create an iconset directory
mkdir -p enhanced_icon.iconset

# Generate all required icon sizes for macOS
sips -z 16 16 enhanced_icon.png --out enhanced_icon.iconset/icon_16x16.png
sips -z 32 32 enhanced_icon.png --out enhanced_icon.iconset/icon_16x16@2x.png
sips -z 32 32 enhanced_icon.png --out enhanced_icon.iconset/icon_32x32.png
sips -z 64 64 enhanced_icon.png --out enhanced_icon.iconset/icon_32x32@2x.png
sips -z 128 128 enhanced_icon.png --out enhanced_icon.iconset/icon_128x128.png
sips -z 256 256 enhanced_icon.png --out enhanced_icon.iconset/icon_128x128@2x.png
sips -z 256 256 enhanced_icon.png --out enhanced_icon.iconset/icon_256x256.png
sips -z 512 512 enhanced_icon.png --out enhanced_icon.iconset/icon_256x256@2x.png
sips -z 512 512 enhanced_icon.png --out enhanced_icon.iconset/icon_512x512.png
sips -z 1024 1024 enhanced_icon.png --out enhanced_icon.iconset/icon_512x512@2x.png

# Also create the plain sizes needed for the app
sips -z 16 16 enhanced_icon.png --out enhanced_icon.iconset/icon_16x16.png
sips -z 32 32 enhanced_icon.png --out enhanced_icon.iconset/icon_32x32.png
sips -z 64 64 enhanced_icon.png --out enhanced_icon.iconset/icon_64x64.png
sips -z 128 128 enhanced_icon.png --out enhanced_icon.iconset/icon_128x128.png
sips -z 256 256 enhanced_icon.png --out enhanced_icon.iconset/icon_256x256.png
sips -z 512 512 enhanced_icon.png --out enhanced_icon.iconset/icon_512x512.png
sips -z 1024 1024 enhanced_icon.png --out enhanced_icon.iconset/icon_1024x1024.png

# Optional: Convert to icns format
iconutil -c icns enhanced_icon.iconset

echo "All icon sizes generated successfully" 
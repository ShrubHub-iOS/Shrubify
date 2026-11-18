#!/usr/bin/env bash
set -euo pipefail
SHRUBIFY_SHADER_OBJECT_DIR=$1
SHRUBIFY_SHADER_BUNDLE=$2
mkdir -p "$SHRUBIFY_SHADER_OBJECT_DIR" "$SHRUBIFY_SHADER_BUNDLE"
SHRUBIFY_SHADER_AIR="$SHRUBIFY_SHADER_OBJECT_DIR/KaraokeBackgroundShader.air"
if ! xcrun -sdk iphoneos metal -target air64-apple-ios17.4 -c Sources/EeveeSpotify/Karaoke/KaraokeBackgroundShader.metal -o "$SHRUBIFY_SHADER_AIR"; then
  # Xcode 26 ships the Metal compiler as a separately installed component.
  xcodebuild -downloadComponent MetalToolchain
  xcrun -sdk iphoneos metal -target air64-apple-ios17.4 -c Sources/EeveeSpotify/Karaoke/KaraokeBackgroundShader.metal -o "$SHRUBIFY_SHADER_AIR"
fi
xcrun -sdk iphoneos metallib "$SHRUBIFY_SHADER_AIR" -o "$SHRUBIFY_SHADER_BUNDLE/KaraokeBackgroundShader.metallib"
test -s "$SHRUBIFY_SHADER_BUNDLE/KaraokeBackgroundShader.metallib"

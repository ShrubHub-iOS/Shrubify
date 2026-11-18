#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SHRUBIFY_LYRICS_TEST_DIR=$(mktemp -d)
trap 'rm -rf "$SHRUBIFY_LYRICS_TEST_DIR"' EXIT
swiftc Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsDto.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsWordDto.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsLineDto.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsBackgroundVocalDto.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsContributor.swift \
  Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsAdapter.swift \
  Sources/EeveeSpotify/Karaoke/KaraokeAnimationCurve.swift \
  Tests/RestoredLyrics/main.swift -o "$SHRUBIFY_LYRICS_TEST_DIR/restored-lyrics"
"$SHRUBIFY_LYRICS_TEST_DIR/restored-lyrics"

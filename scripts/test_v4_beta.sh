#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc Sources/EeveeSpotify/Shrubify3/ShrubifyBetaSupport.swift \
  Sources/EeveeSpotify/Lyrics/Models/Settings/KaraokeOptions.swift \
  Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsStore.swift \
  Sources/EeveeSpotify/Lyrics/Models/Settings/LyricsSource.swift \
  Sources/EeveeSpotify/Lyrics/Models/Settings/LyricsFallbacks.swift \
  Sources/EeveeSpotify/Karaoke/KaraokePlaybackTracker.swift \
  Tests/V4Beta/main.swift -o "$TEST_BUILD/v4-beta-tests"
"$TEST_BUILD/v4-beta-tests"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -swift-version 5 -module-cache-path "$TEST_BUILD/module-cache" \
  Sources/EeveeSpotify/Lyrics/Models/LyricsRequestContext.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsRequestCoordinator.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsSearchQuery.swift \
  Sources/EeveeSpotify/Lyrics/Models/KaraokeLyricsStore.swift \
  Sources/EeveeSpotify/Lyrics/Models/Settings/LyricsSource.swift \
  Sources/EeveeSpotify/Lyrics/Models/Settings/LyricsFallbackChain.swift \
  Sources/EeveeSpotify/Karaoke/KaraokePlaybackTracker.swift \
  Tests/LyricsCoordinator/main.swift -o "$TEST_BUILD/coordinator-tests"
"$TEST_BUILD/coordinator-tests"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -swift-version 5 -module-cache-path "$TEST_BUILD/module-cache" \
  Sources/EeveeSpotify/Lyrics/Models/LyricsTextParser.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsRequestContext.swift \
  Sources/EeveeSpotify/Shrubify3/ReplayPlaybackBoundary.swift \
  Sources/EeveeSpotify/Shared/Helpers/URLSessionHelper.swift \
  Sources/EeveeSpotify/Shared/Models/Extensions/URL+Extension.swift \
  Sources/EeveeSpotify/Premium/Helpers/ServerSidedFeaturePolicy.swift \
  Tests/ReleaseSupport/main.swift -o "$TEST_BUILD/release-tests"
"$TEST_BUILD/release-tests"

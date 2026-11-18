#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc Sources/EeveeSpotify/Lyrics/Models/LyricsActivationPolicy.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsResultPolicy.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsCacheSignature.swift \
  Sources/EeveeSpotify/Lyrics/Models/LyricsRequestBudget.swift \
  Tests/PRIntegration/main.swift -o "$TEST_BUILD/integration-tests"
"$TEST_BUILD/integration-tests"
swiftc Sources/EeveeSpotify/Shared/Helpers/DebugLogSanitizer.swift \
  Tests/DebugLogRedaction/main.swift -o "$TEST_BUILD/redaction-tests"
"$TEST_BUILD/redaction-tests"

swiftc Sources/EeveeSpotify/Appearance/PlayerLayout.swift \
  Sources/EeveeSpotify/Appearance/NavigationCapsuleLayout.swift \
  Tests/PlayerLayout/main.swift -o "$TEST_BUILD/player-layout-tests"
"$TEST_BUILD/player-layout-tests"

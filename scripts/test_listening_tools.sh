#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc Sources/EeveeSpotify/Playback/SleepTimerCountdown.swift \
  Tests/ListeningTools/main.swift -o "$TEST_BUILD/listening-tools"
"$TEST_BUILD/listening-tools"

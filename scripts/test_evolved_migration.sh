#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD=$(mktemp -d)
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc Sources/EeveeSpotify/Evolved/ShrubifyEvolvedMigration.swift \
  Tests/EvolvedMigration/main.swift -o "$TEST_BUILD/migration-tests"
"$TEST_BUILD/migration-tests"

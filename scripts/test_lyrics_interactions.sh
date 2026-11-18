#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SHRUBIFY_INTERACTION_ROOT=$(mktemp -d)
SHRUBIFY_INTERACTION_DEVICE=''
trap 'if [[ -n "$SHRUBIFY_INTERACTION_DEVICE" ]]; then xcrun simctl shutdown "$SHRUBIFY_INTERACTION_DEVICE" >/dev/null 2>&1 || true; xcrun simctl delete "$SHRUBIFY_INTERACTION_DEVICE" >/dev/null 2>&1 || true; fi; rm -rf "$SHRUBIFY_INTERACTION_ROOT"' EXIT
mkdir -p Outputs/lyrics-interactions
python3 scripts/make_lyrics_interaction_project.py "$SHRUBIFY_INTERACTION_ROOT"
xcrun simctl list runtimes -j > "$SHRUBIFY_INTERACTION_ROOT/runtimes.json"
SHRUBIFY_INTERACTION_RUNTIME=$(python3 - "$SHRUBIFY_INTERACTION_ROOT/runtimes.json" <<'PY'
import json,sys
runtimes=[r for r in json.load(open(sys.argv[1]))['runtimes'] if r.get('isAvailable') and r['name'].startswith('iOS 26')]
assert runtimes, 'iOS 26 simulator runtime required for production glass interaction tests'
print(sorted(runtimes,key=lambda r:tuple(int(v) for v in r['version'].split('.')))[-1]['identifier'])
PY
)
SHRUBIFY_INTERACTION_DEVICE=$(xcrun simctl create ShrubifyLyricsInteractions com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M2 "$SHRUBIFY_INTERACTION_RUNTIME")
xcrun simctl boot "$SHRUBIFY_INTERACTION_DEVICE"
xcodebuild -project "$SHRUBIFY_INTERACTION_ROOT/LyricsInteractions.xcodeproj" -scheme LyricsInteractions \
  -destination "platform=iOS Simulator,id=$SHRUBIFY_INTERACTION_DEVICE" \
  -derivedDataPath "$SHRUBIFY_INTERACTION_ROOT/DerivedData" \
  -resultBundlePath Outputs/lyrics-interactions/Interactions.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test > Outputs/lyrics-interactions/xcodebuild.log 2>&1 || {
    tail -100 Outputs/lyrics-interactions/xcodebuild.log
    exit 1
  }
xcrun xcresulttool get test-results summary --path Outputs/lyrics-interactions/Interactions.xcresult --format json > Outputs/lyrics-interactions/summary.json
cat Outputs/lyrics-interactions/summary.json

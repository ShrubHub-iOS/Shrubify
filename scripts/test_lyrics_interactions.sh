#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SHRUBIFY_INTERACTION_ROOT=$(mktemp -d)
SHRUBIFY_INTERACTION_DEVICE=''
trap 'if [[ -n "$SHRUBIFY_INTERACTION_DEVICE" ]]; then xcrun simctl shutdown "$SHRUBIFY_INTERACTION_DEVICE" >/dev/null 2>&1 || true; xcrun simctl delete "$SHRUBIFY_INTERACTION_DEVICE" >/dev/null 2>&1 || true; fi; rm -rf "$SHRUBIFY_INTERACTION_ROOT"' EXIT
mkdir -p Outputs/lyrics-interactions
python3 scripts/make_lyrics_interaction_project.py "$SHRUBIFY_INTERACTION_ROOT"
xcrun simctl list runtimes -j > Outputs/lyrics-interactions/runtimes.json
# Select a compatible *type*, never take ownership of an installed device.
# Only the UDID returned by our own successful create is eligible for cleanup.
xcrun simctl list devicetypes -j > Outputs/lyrics-interactions/device-types.json
selection=$(python3 - <<'PYSELECT'
import json
from pathlib import Path
root = Path('Outputs/lyrics-interactions')
runtimes = json.loads((root / 'runtimes.json').read_text())['runtimes']
types = json.loads((root / 'device-types.json').read_text())['devicetypes']
runtime = next((r for r in runtimes if r.get('isAvailable') and r['identifier'].endswith('iOS-26-1')), None)
if not runtime: raise SystemExit('Install the iOS 26.1 simulator runtime')
supported = {d['identifier'] for d in runtime.get('supportedDeviceTypes', [])}
ipads = [d for d in types if d['name'].startswith('iPad') and (not supported or d['identifier'] in supported)]
if not ipads: raise SystemExit('No compatible iPad simulator type')
device = next((d for d in ipads if d['name'] == 'iPad Air 11-inch (M2)'), ipads[0])
print(runtime['identifier'], device['identifier'])
PYSELECT
)
read -r runtime device_type <<< "$selection"
created=$(xcrun simctl create "Shrubify-Interactions-${SHRUBIFY_INTERACTION_ROOT##*/}" "$device_type" "$runtime")
SHRUBIFY_INTERACTION_DEVICE="$created"
xcrun simctl boot "$SHRUBIFY_INTERACTION_DEVICE"
xcrun simctl bootstatus "$SHRUBIFY_INTERACTION_DEVICE" -b
xcodebuild -project "$SHRUBIFY_INTERACTION_ROOT/LyricsInteractions.xcodeproj" -scheme LyricsInteractions \
  -destination "platform=iOS Simulator,id=$SHRUBIFY_INTERACTION_DEVICE" \
  -derivedDataPath "$SHRUBIFY_INTERACTION_ROOT/DerivedData" \
  -resultBundlePath Outputs/lyrics-interactions/Interactions.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > Outputs/lyrics-interactions/xcodebuild.log 2>&1 || {
    tail -100 Outputs/lyrics-interactions/xcodebuild.log
    exit 1
  }
xcrun xcresulttool get test-results summary --path Outputs/lyrics-interactions/Interactions.xcresult --format json > Outputs/lyrics-interactions/summary.json
cat Outputs/lyrics-interactions/summary.json

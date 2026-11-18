#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SHRUBIFY_INTERACTION_ROOT=$(mktemp -d)
SHRUBIFY_INTERACTION_DEVICE=''
trap 'if [[ -n "$SHRUBIFY_INTERACTION_DEVICE" ]]; then xcrun simctl shutdown "$SHRUBIFY_INTERACTION_DEVICE" >/dev/null 2>&1 || true; xcrun simctl delete "$SHRUBIFY_INTERACTION_DEVICE" >/dev/null 2>&1 || true; fi; rm -rf "$SHRUBIFY_INTERACTION_ROOT"' EXIT
mkdir -p Outputs/lyrics-interactions
python3 scripts/make_lyrics_interaction_project.py "$SHRUBIFY_INTERACTION_ROOT"
xcrun simctl list runtimes -j > Outputs/lyrics-interactions/runtimes.json
xcrun simctl list devices available -j > Outputs/lyrics-interactions/devices.json
SHRUBIFY_INTERACTION_DEVICE=$(python3 - <<'PYSELECT'
import json
from pathlib import Path
root=Path('Outputs/lyrics-interactions')
runtimes=json.loads((root/'runtimes.json').read_text())['runtimes']
devices=json.loads((root/'devices.json').read_text())['devices']
for runtime in runtimes:
    if not runtime.get('isAvailable') or runtime['version'] != '26.1': continue
    candidates=[d for d in devices.get(runtime['identifier'],[]) if d.get('isAvailable') and d['name'].startswith('iPad')]
    if candidates:
        chosen=next((d for d in candidates if d['name']=='iPad Air 11-inch (M2)'),candidates[0])
        (root/'selected-device.json').write_text(json.dumps({'runtime':runtime,'device':chosen},indent=2))
        print(chosen['udid']); break
else: raise SystemExit('No preconfigured compatible iPad for the selected Xcode iOS 26.1 runtime')
PYSELECT
)
xcrun simctl boot "$SHRUBIFY_INTERACTION_DEVICE" || true
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

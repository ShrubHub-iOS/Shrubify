#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SHRUBIFY_SMOKE_ROOT=$(mktemp -d)
SHRUBIFY_SMOKE_DEVICE=''
trap 'if [[ -n "$SHRUBIFY_SMOKE_DEVICE" ]]; then xcrun simctl shutdown "$SHRUBIFY_SMOKE_DEVICE" >/dev/null 2>&1 || true; xcrun simctl delete "$SHRUBIFY_SMOKE_DEVICE" >/dev/null 2>&1 || true; fi; rm -rf "$SHRUBIFY_SMOKE_ROOT"' EXIT
mkdir -p Outputs/ui-smoke "$SHRUBIFY_SMOKE_ROOT/ShrubifyUISmoke.app"
xcrun simctl list runtimes -j > "$SHRUBIFY_SMOKE_ROOT/runtimes.json"
xcrun simctl list devicetypes -j > "$SHRUBIFY_SMOKE_ROOT/devices.json"
read -r SHRUBIFY_SMOKE_RUNTIME SHRUBIFY_SMOKE_TYPE < <(python3 - "$SHRUBIFY_SMOKE_ROOT" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
runtimes=[r for r in json.loads((root/'runtimes.json').read_text())['runtimes'] if r.get('isAvailable') and r['name'].startswith('iOS 26')]
assert runtimes, 'An iOS 26 simulator is required to test the navigation material'
runtime=sorted(runtimes,key=lambda r:tuple(int(v) for v in r['version'].split('.')))[-1]
devices=json.loads((root/'devices.json').read_text())['devicetypes']
device=next(d for d in devices if d['name']=='iPad Air 11-inch (M2)')
print(runtime['identifier'],device['identifier'])
PY
)
SHRUBIFY_SMOKE_DEVICE=$(xcrun simctl create ShrubifyNavigationSmoke "$SHRUBIFY_SMOKE_TYPE" "$SHRUBIFY_SMOKE_RUNTIME")
xcrun simctl boot "$SHRUBIFY_SMOKE_DEVICE"
xcrun simctl bootstatus "$SHRUBIFY_SMOKE_DEVICE" -b
SHRUBIFY_SMOKE_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
SHRUBIFY_SMOKE_ARCH=$(uname -m)
xcrun --sdk iphonesimulator swiftc -parse-as-library -sdk "$SHRUBIFY_SMOKE_SDK" \
  -target "$SHRUBIFY_SMOKE_ARCH-apple-ios26.0-simulator" \
  Sources/EeveeSpotify/Appearance/NavigationCapsuleLayout.swift \
  Sources/EeveeSpotify/Appearance/NavigationCapsuleSurface.swift \
  Tests/NavigationSurfaceSmoke/App.swift \
  -o "$SHRUBIFY_SMOKE_ROOT/ShrubifyUISmoke.app/ShrubifyUISmoke"
python3 - "$SHRUBIFY_SMOKE_ROOT/ShrubifyUISmoke.app/Info.plist" <<'PY'
import plistlib,sys
info={'CFBundleIdentifier':'com.shrubify.navigation-smoke','CFBundleExecutable':'ShrubifyUISmoke','CFBundleName':'ShrubifyUISmoke',
      'CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','MinimumOSVersion':'26.0',
      'UIDeviceFamily':[2],'UIRequiresFullScreen':True,
      'UISupportedInterfaceOrientations':['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']}
with open(sys.argv[1],'wb') as f:plistlib.dump(info,f)
PY
codesign --force --sign - "$SHRUBIFY_SMOKE_ROOT/ShrubifyUISmoke.app"
xcrun simctl install "$SHRUBIFY_SMOKE_DEVICE" "$SHRUBIFY_SMOKE_ROOT/ShrubifyUISmoke.app"
xcrun simctl launch "$SHRUBIFY_SMOKE_DEVICE" com.shrubify.navigation-smoke
SHRUBIFY_SMOKE_DATA=$(xcrun simctl get_app_container "$SHRUBIFY_SMOKE_DEVICE" com.shrubify.navigation-smoke data)
for _ in {1..45}; do
  [[ -f "$SHRUBIFY_SMOKE_DATA/Documents/result.json" ]] && break
  sleep 1
done
cp "$SHRUBIFY_SMOKE_DATA/Documents/"*.png Outputs/ui-smoke/
cp "$SHRUBIFY_SMOKE_DATA/Documents/result.json" Outputs/ui-smoke/
python3 - <<'PY'
import json
from pathlib import Path
result=json.loads(Path('Outputs/ui-smoke/result.json').read_text())
print(json.dumps(result,indent=2))
assert result['passed'], 'Rendered navigation backing extends outside its bounded capsule'
PY

#!/usr/bin/env bash
# macOS GitHub Actions runner; dependencies installed by workflow.
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE_IPA="${1:?usage: scripts/build_shrubify.sh <spotify.ipa> <build number>}"
BUILD="${2:?Missing build number}"
export THEOS="${THEOS:-$PWD/theos}"

# Reuse the exact compiled package and injector when the source/toolchain cache key
# matches. Never rebuild native Swift code for IPA-only version updates.
if [[ "${SHRUBIFY_PACKAGE_CACHE_HIT:-false}" == "true" ]]; then
  echo 'Restored exact-source compiled tweak + injection library from Actions cache.'
  find packages -maxdepth 1 -type f -name 'com.shrubify.spotify_*.deb' -print -quit | grep -q . || {
    echo '::error::Compiled tweak cache marked hit but .deb is missing'; exit 1;
  }
  [[ -s packages/zxPluginsInject.dylib ]] || {
    echo '::error::Compiled tweak cache marked hit but injector dylib is missing'; exit 1;
  }
else
  chmod +x Tools/SwiftProtobufBuild/build-eeveeswiftprotobuf.sh Tools/build-zxpi.sh Tools/alt-icons.sh
  PROTO_FRAMEWORK="$THEOS/lib/iphone/rootless/EeveeSwiftProtobuf.framework"
  PROTO_BINARY="$PROTO_FRAMEWORK/EeveeSwiftProtobuf"
  if [[ -s "$PROTO_BINARY" && -d "$PROTO_FRAMEWORK/Modules/EeveeSwiftProtobuf.swiftmodule" ]] &&
     lipo -archs "$PROTO_BINARY" | grep -q 'arm64e' &&
     lipo -archs "$PROTO_BINARY" | grep -q 'arm64'; then
    echo 'Using prebuilt EeveeSwiftProtobuf framework (cached when available).'
  else
    echo 'EeveeSwiftProtobuf framework missing or incomplete; compiling it now.'
    THEOS_PACKAGE_SCHEME=rootless bash Tools/SwiftProtobufBuild/build-eeveeswiftprotobuf.sh
  fi
  THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1
  bash Tools/build-zxpi.sh
fi
DEB_PATH="$(find packages -maxdepth 1 -name 'com.shrubify.spotify_*.deb' -type f | sort | tail -1)"
[[ -n "$DEB_PATH" && -f "$DEB_PATH" ]] || { echo '::error::Shrubify deb not found'; exit 1; }

# Check cache contents against the current package metadata. This fails closed
# instead of shipping a stale tweak when something invalid is restored.
[[ "$(dpkg-deb -f "$DEB_PATH" Package)" == 'com.shrubify.spotify' ]] || {
  echo '::error::Wrong cached tweak package identity'; exit 1;
}
TWEAK_VERSION="$(awk '$1=="Version:"{print $2}' control)"
[[ "$(dpkg-deb -f "$DEB_PATH" Version)" == "$TWEAK_VERSION" ]] || {
  echo '::error::Cached tweak version does not match control'; exit 1;
}
DEB_EXTRACT="$(mktemp -d -t shrubify-deb.XXXXXX)"
trap 'rm -rf "$DEB_EXTRACT"' EXIT
dpkg-deb -R "$DEB_PATH" "$DEB_EXTRACT"
DYLIB="$(find "$DEB_EXTRACT" -type f -name 'EeveeSpotify.dylib' | head -1)"
BUNDLE="$(find "$DEB_EXTRACT" -type d -name 'EeveeSpotify.bundle' | head -1)"
FRAMEWORK="$(find "$DEB_EXTRACT" -type d -name 'EeveeSwiftProtobuf.framework' | head -1)"
[[ -n "$DYLIB" && -f "$DYLIB" ]] || { echo '::error::Tweak dylib missing from package'; exit 1; }
INJECT=("$DYLIB")
[[ -n "$BUNDLE" ]] && INJECT+=("$BUNDLE")
[[ -n "$FRAMEWORK" ]] && INJECT+=("$FRAMEWORK")

SPOT_VERSION="$(python3 - "$SOURCE_IPA" <<'PYVERSION'
import zipfile,plistlib,sys
with zipfile.ZipFile(sys.argv[1]) as z:
    print(plistlib.loads(z.read('Payload/Spotify.app/Info.plist'))['CFBundleShortVersionString'])
PYVERSION
)"
TWEAK_VERSION="$(awk '$1=="Version:"{print $2}' control)"
mkdir -p Outputs/IPAS
OUT="Outputs/IPAS/Shrubify-Spotify-${SPOT_VERSION}-v${TWEAK_VERSION}-b${BUILD}.ipa"
# Level 3 uses standard ZIP deflate like level 9, but avoids expensive max
# compression of a large IPA. The output IPA is validated below.
cyan -i "$SOURCE_IPA" -o "$OUT" -f "${INJECT[@]}" -c 3 -m 15.0 -duw
ipapatch --input "$OUT" --inplace --noconfirm --dylib packages/zxPluginsInject.dylib
bash Tools/alt-icons.sh "$OUT"
python3 scripts/brand_ipa.py "$OUT" --build "$BUILD"
# Catch stale extensions/signing files and malformed IPA payloads before upload.
python3 scripts/inspect_ipa.py "$OUT" --expected "$SPOT_VERSION" --require-shrubify
printf '%s\n' "$OUT" > Outputs/latest_ipa_path.txt
printf '%s\n' "$DEB_PATH" > Outputs/latest_deb_path.txt
printf 'Shrubify IPA: %s\n' "$OUT"

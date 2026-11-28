# Shrubify 4.2.5~beta14 setup and releases

The iPad beta uses one system glass effect per recognized bottom bar and restores Spotify's own backing when the glass is disabled. Native playback remains available in both iPad layouts. Custom lyrics can open while their source is loading. Read the [beta notes](RELEASE-4.2.5~beta14.md), [testing checklist](TESTING.md) and [integration notes](docs/EVOLVED-INTEGRATION.md).

The tweak keeps the internal `EeveeSpotify.dylib` and `EeveeSpotify.bundle` identifiers for compatibility. The package is `com.shrubify.spotify`; branded IPAs use `com.shrubify.client`. The Shrubify version comes from `control`, which generates the in-app version at build time. Spotify’s app version is a separate value.

## Install

Find the 4.2.5 beta 14 prerelease in [GitHub Releases](https://github.com/ShrubHub-iOS/Shrubify/releases). The default AltStore feed lists stable releases. Sign the IPA using your own compatible certificate/profile and installation method. Jailbreak packages require the matching Theos Orion dependency. These are community builds; device compatibility is not guaranteed.

## Build locally

Use a Mac with Xcode, Theos, its Orion/Swift support, and the tools listed by `build-ipa-local.sh`. Provide your own authorized compatible base Spotify IPA. The build does not acquire or decrypt Spotify from the App Store.

```bash
export THEOS=/path/to/theos
bash build-ipa-local.sh /path/to/Spotify.ipa
```

For a rootless tweak package, use `THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1` after preparing the renamed SwiftProtobuf framework with `Tools/SwiftProtobufBuild/build-eeveeswiftprotobuf.sh`.

## GitHub release automation

The **Shrubify - Watch, Build, Release and Update Source** workflow runs on relevant `Master`/`main` changes, a schedule, or manual dispatch. It compiles the current tweak, injects an existing configured IPA, checks the package version and IPA structure, publishes release assets, and regenerates `docs/repo.json`.

- Configure an authorized source through `config/ipa-sources.json`, the private `SPOTIFY_IPA_CATALOG_URL` secret, or `SPOTIFY_IPA_URL`.
- `ALLOW_PUBLIC_IPA_RELEASE=true` enables public release publication. GitHub Actions needs the configured repository write permissions.
- A detected Spotify update without a matching configured IPA is reported as pending. The workflow verifies the actual IPA version before labeling it.
- The release title, tag and output filenames use the version in `control`. A new Shrubify version needs freshly built files; relabeling an old IPA does not update its embedded tweak.
- `docs/repo.json` is generated from actual published releases and download assets. The website reads this source for its current download/version display.

## Validate

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
python3 scripts/check_shrubify_branding.py
python3 scripts/check_release_consistency.py
```

The native workflow also runs Swift regression suites and builds a rootless tweak on macOS. Physical-device checks remain listed in `TESTING.md`. Existing preference/storage keys and historical release records retain their original identifiers so upgrades remain compatible.

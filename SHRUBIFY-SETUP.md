# Shrubify 4.2.4 setup and releases

Shrubify 4.2.4 uses native Spotify player/navigation/page layouts on iPad and gives each glass surface exactly one owner. The tab bar and mini-player are drawn by the native iPad glass layer; the window pass only draws them when that layer cannot mount, and it removes its own plate and hands back the backing it cleared as soon as the native one appears. The shared material no longer overlays a full-height white gradient, so plates stay see-through instead of reading as grey plastic. The player carries one rounded glass card behind its title, progress bar, transport row and tool row, plus a decorative circle behind every key (shuffle, previous, play, next, repeat, share, queue, lyrics and the two top keys); those mount from the player's own layout hook, so they appear on iPad where the player chrome was never activated before. All plates are behind the content, never resize Spotify's views and never change a hit region, and every cleared backing has an exact undo. Studio's **Glass status** reports which surfaces were found and how many keys carry glass. A lyrics source that fails is still rescued by a free, token-less provider (LRCLIB, then Genius when its switch is on) before the app reports "no lyrics found", and LRCLIB resolves title suffixes and scored search hits instead of one exact string. Material, style and intensity live on a single Studio page. The original Shrubify fullscreen custom lyrics view is available from the native player footer as well as ShrubPanel and lyrics settings. Requires iOS 17.4+; the real system glass effect requires iOS 26+. Read [RELEASE-4.2.4.md](RELEASE-4.2.4.md), [TESTING.md](TESTING.md) and [integration notes](docs/EVOLVED-INTEGRATION.md).

The tweak keeps the internal `EeveeSpotify.dylib` and `EeveeSpotify.bundle` identifiers for compatibility. The package is `com.shrubify.spotify`; branded IPAs use `com.shrubify.client`. The Shrubify version comes from `control`, which generates the in-app version at build time. Spotify’s app version is a separate value.

## Install

Download the current assets from [GitHub Releases](https://github.com/ShrubHub-iOS/Shrubify/releases/latest). Sign the IPA using your own compatible certificate/profile and installation method. Jailbreak packages require the matching Theos Orion dependency. These are community builds; device compatibility is not guaranteed.

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

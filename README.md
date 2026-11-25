> **4.2.5 beta 5:** Refined iPad Now Playing typography and new lrc.red and LyricsPlus providers. The stable install channel continues to serve 4.2.4.

# Shrubify 4.2.5~beta6

**Created and maintained by shrubbery and the ShrubHub team.**

Shrubify is an **unofficial, community-developed iOS/iPadOS tweak** based on an upstream GPL-3.0 project. It is not developed, endorsed, or supported by Spotify. **The app's built-in service, catalog, accounts, and underlying interface still belong to Spotify.** This repository distributes the Shrubify tweak source and build tooling; see the license and original project attribution below.

## What actually makes Shrubify different?

| Feature | What it does | Limitations |
| --- | --- | --- |
| **Original custom lyrics** | Fullscreen Shrubify karaoke with word/syllable animations, follow/seek, credits and an animated album-art background. Open from ShrubPanel or lyrics settings. | Requires a timed lyrics source. Saved typography/alignment preferences are retained. Native playback commands depend on Spotify compatibility. |
| **Shrubify Studio** | Player and app appearance in one place. The iPad dock and mini-player use system Liquid Glass over the page, and **Glass status** lists which surfaces this Spotify build exposes. Lyrics appearance lives under Lyrics. | iPad still uses the native player; Shrubify decorates it instead of replacing it. Old layout archives are retained but no longer applied. iOS 17.4+; system glass requires iOS 26+. Spotify version compatibility needs device testing. |
| **ShrubPanel** | Live lyrics, queue and sleep timer first; Studio and Replay are shortcuts. Reach it from Shrubify settings or (where the player observer attaches) a long press on the mini-player. | The mini-player gesture is version-dependent; the settings entry is the reliable fallback. |
| **Shrubify Replay** | Private, opt-in local listening records: listening duration, track counts, top artists, seven-day trends and approximate plays. Includes privacy controls and a reset button. | Counts only *observed* playback while Shrubify is active, not your full Spotify history. Accuracy depends on now-playing metadata being present. No network sync. |
| **ShrubQueue** | Shortcut to Spotify's native queue, bookmark the current song, and save a snapshot of the last 20 locally recorded tracks. | Snapshots are **not** a capture or restoration of Spotify's real queue. Opening tracks requires a captured Spotify track URI and in-app navigation support. |
| **Evolved UI** | Apple Music-style player, fading artwork backdrop, glass tabs and mini-player, and redesigned home/library/album/playlist/artist pages. | On iPad, Spotify continues to handle presentation and playback while Shrubify provides the player body and system glass on supported bottom bars. Private UI hooks on supported devices require version-specific checks. |
| **Compatibility & Diagnostics** | Optional Stability Mode, version reporting, issue links and debug-log export. | Cannot guarantee compatibility with all Spotify builds or eliminate every crash. |

The iPad player adapts the artwork and controls to the pane and keeps Spotify’s own presentation controls. The glass dock and mini-player preserve native navigation and playback actions. Device testing covers the visuals and private Spotify layout hooks.

## Install and build

- **Shrubify 4.2.5 beta 6 release notes** [RELEASE-4.2.5~beta6.md](RELEASE-4.2.5~beta6.md)

- **Source and full setup:** [SHRUBIFY-SETUP.md](SHRUBIFY-SETUP.md)
- **Changes in this release:** [CHANGELOG.md](CHANGELOG.md)
- **Testing checklist / known limits:** [TESTING.md](TESTING.md)
- **Bug reports:** [GitHub Issues](https://github.com/zoinkdoggie94/Shrubify/issues/new/choose)
- **Upstream source and history:** [README-UPSTREAM.md](README-UPSTREAM.md)

The Theos tweak's **internal** `EeveeSpotify` identifiers remain intact where required for binary compatibility. Renaming these without adjusting dependency links can make the tweak fail to load. The user-facing project is Shrubify. Building a patched IPA requires an authorized, compatible base IPA; the workflow does not acquire or decrypt one for you. An IPA needs a compatible signing certificate and provisioning profile. Only publish files that you have rights to redistribute.

## Privacy and performance

Replay starts **disabled**. When enabled, Shrubify reads iOS Now Playing metadata every ~10 seconds while active and stores an on-device, bounded history (up to 350 tracks, 400 daily totals and 30 snapshots). There are no analytics uploads, account tokens, or requests to a Shrubify server. It batches persistence (rather than writing every playback tick), stops counting when the app backgrounds, and lets you erase all recorded data.

New UI additions use the existing SwiftUI settings navigation and Spotify's in-app navigation when supported. Experimental player layout hooks remain behind the existing compatibility and Stability Mode controls. This architecture reduces potential regressions; **real-world device testing is still required**.

## Credits and licensing

**Project and current development:** [shrubbery](https://github.com/zoinkdoggie94) (owner and lead developer), [HakureiMango](https://github.com/HakureiMango) (co-owner and contributor), and the [ShrubHub team](https://github.com/ShrubHub-iOS) (official organization and project support).


**EeveeSpotifyEvolved:** [zbzxbg and contributors](https://github.com/zbzxbg/EeveeSpotifyEvolved) — GPL-3.0 player, page and glass UI implementation, lyrics renderers and complete provider layer; also the earlier sleep timer and Replay inspiration. [Source revision, scope and attribution](docs/EVOLVED-INTEGRATION.md).

**Upstream work:** whoeevee, jaydenjcpy, estrogencat and the contributors documented in [contributors.json](contributors.json) and [README-UPSTREAM.md](README-UPSTREAM.md). Their contributions are substantial and remain acknowledged. The upstream GPL-3.0 obligations, original author notices, and the complete [LICENSE](LICENSE) remain in place. Shrubify is a fork, **not** a claim of authorship over the upstream codebase.

## Faster GitHub Actions builds

The first run for a **changed tweak source** still compiles the Swift tweak, the injector and possibly the renamed SwiftProtobuf framework. Once the build succeeds, GitHub Actions caches the complete compiled tweak package and injector, keyed to source files, tools, Xcode version, architecture and package version. Builds that only change the **input Spotify IPA** can reuse the compiled components. Cache hits are validated against the declared package identity/version; an invalid cache fails instead of silently shipping outdated code. The workflow also retains its preflight source checks and IPA packaging inspection.

IPA repacking uses normal ZIP compression level 3 instead of 9 to reduce CPU time, while keeping full ZIP validation. This can increase the output IPA's file size. **Build time is not guaranteed**, especially on the first run after a source change, a cache eviction, or when downloading a large input IPA. The completed Actions run shows cache hit/miss status so performance can be diagnosed.

The displayed Shrubify tweak version comes from [`control`](control), via generated Swift build configuration. Update that one version number when releasing new tweak code. Spotify's app version remains separate.

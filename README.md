# Shrubify 3.0.3 — Listening is easy with Shrubify!

**Created and maintained by shrubbery and the ShrubHub team.**

Shrubify is an **unofficial, community-developed iOS/iPadOS tweak** based on an upstream GPL-3.0 project. It is not developed, endorsed, or supported by Spotify. **The app's built-in service, catalog, accounts, and underlying interface still belong to Spotify.** This repository distributes the Shrubify tweak source and build tooling; see the license and original project attribution below.

## What actually makes Shrubify different?

| Feature | What it does | Limitations |
| --- | --- | --- |
| **Shrubify Studio** | Choose Classic, Minimal, Immersive, or Custom player modes; edit artwork backdrops, artwork corner radius, lyrics cards, mini-player appearance and player elements. Save up to 12 named layouts locally. | Uses existing version-gated hooks. Some changes need a restart. Liquid Glass requires a supported iOS version. |
| **ShrubPanel** | A small in-app hub for Studio, Replay, ShrubQueue and supported lyrics tools. Reach it from Shrubify settings or (where the player observer attaches) a long press on the mini-player. | The mini-player gesture is version-dependent; the settings entry is the reliable fallback. |
| **Shrubify Replay** | Private, opt-in local listening records: listening duration, track counts, top artists, seven-day trends and approximate plays. Includes privacy controls and a reset button. | Counts only *observed* playback while Shrubify is active, not your full Spotify history. Accuracy depends on now-playing metadata being present. No network sync. |
| **ShrubQueue** | Shortcut to Spotify's native queue, bookmark the current song, and save a snapshot of the last 20 locally recorded tracks. | Snapshots are **not** a capture or restoration of Spotify's real queue. Opening tracks requires a captured Spotify track URI and in-app navigation support. |
| **ShrubModes** | One-tap player presets that keep Spotify's original palette and honor chosen accent colors. | Some hooks change between Spotify versions. |
| **Compatibility & Diagnostics** | Optional Stability Mode, version reporting, issue links and debug-log export. | Cannot guarantee compatibility with all Spotify builds or eliminate every crash. |

Shrubify retains earlier additions such as the existing Liquid Glass integrations, custom lyrics support, icon picker, player gestures and compatibility controls. This release does **not** change Spotify's color palette to a ShrubHub theme.

## Install and build

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

**Project and current development:** [shrubbery](https://github.com/zoinkdoggie94) and the ShrubHub team.

**Upstream work:** whoeevee, jaydenjcpy, estrogencat and the contributors documented in [contributors.json](contributors.json) and [README-UPSTREAM.md](README-UPSTREAM.md). Their contributions are substantial and remain acknowledged. The upstream GPL-3.0 obligations, original author notices, and the complete [LICENSE](LICENSE) remain in place. Shrubify is a fork, **not** a claim of authorship over the upstream codebase.

## Faster GitHub Actions builds

The first run for a **changed tweak source** still compiles the Swift tweak, the injector and possibly the renamed SwiftProtobuf framework. Once the build succeeds, GitHub Actions caches the complete compiled tweak package and injector, keyed to source files, tools, Xcode version, architecture and package version. Builds that only change the **input Spotify IPA** can reuse the compiled components. Cache hits are validated against the declared package identity/version; an invalid cache fails instead of silently shipping outdated code. The workflow also retains its preflight source checks and IPA packaging inspection.

IPA repacking uses normal ZIP compression level 3 instead of 9 to reduce CPU time, while keeping full ZIP validation. This can increase the output IPA's file size. **Build time is not guaranteed**, especially on the first run after a source change, a cache eviction, or when downloading a large input IPA. The completed Actions run shows cache hit/miss status so performance can be diagnosed.

The displayed Shrubify tweak version comes from [`control`](control), via generated Swift build configuration. Update that one version number when releasing new tweak code. Spotify's app version remains separate.

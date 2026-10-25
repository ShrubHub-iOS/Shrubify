## Shrubify 3.0.2 — iOS 14 compatibility and faster builds

- Fixed four distinct Swift compiler errors confirmed by the 3.0.1 GitHub Actions log: iOS 15-only `.monospacedDigit()`, iOS 16-only `.bold()`, and iOS 16-only `Button.fontWeight()` calls in the new 3.0 views.
- Replaced affected UI modifiers with iOS 14-compatible font styles while retaining Studio, Replay, ShrubPanel and ShrubQueue.
- Moved fast source/preflight tests to the very start of the macOS job, before the IPA download, Xcode selection and dependency installation.
- Added an iOS 14 SwiftUI API regression check and automated fixture tests for the precise patterns that broke the build.
- Cache the precompiled SwiftProtobuf dependency and save it immediately after a successful dependency build; future builds can skip recompiling it even when a later tweak build previously failed.
- The full IPA build still needs a macOS Actions runner, and cache misses or changes to the dependency script/Xcode version will require an initial rebuild.

**Verification:** Swift syntax parsing, shell checks, YAML parse, Python regression tests, and applied-patch testing. No complete iOS compile or device test was available in the current environment.

## Shrubify 3.0.1 — Source reliability update

- Split the complex Studio SwiftUI builder into smaller views to improve compilation and maintainability.
- Simplified the Replay history graph’s sizing and date rendering expressions.
- Stopped the Replay timer and its observers when listening tracking is disabled.
- Added automatic compiler-error summaries to GitHub Actions and a small diagnostics artifact when compilation fails.
- Added regression tests for parsing both ordinary and ANSI-encoded Swift build errors.
- Preserves the Spotify palette, Shrubify identity, and the existing Studio, Panel, Replay, and Queue features.

**Verification:** Swift syntax parsing, YAML parsing, shell/Python checks and automated source-generator/diagnostics tests. This does not substitute for a real macOS compilation and device test.

# Shrubify Changelog

## 3.0.0 — Listening is easy with Shrubify! (source release)

### New
- **Shrubify Studio:** Four music-player presets and adjustable existing player options including artwork corner radius, without changing Spotify's palette.
- **Named Studio layouts:** Save and restore up to 12 sets of player/backdrop/mini-player options.
- **ShrubPanel:** New SwiftUI navigation hub, reachable from Shrubify settings and a mini-player long press when the supported observer attaches.
- **Shrubify Replay:** Opt-in, device-local track and listening-time estimates, top songs, top artists, seven-day trends, playback counts, privacy control, and erase action.
- **ShrubQueue:** Shortcut to the in-app queue where Spotify's navigator is captured; single-song bookmarks and local recent-listening snapshots.
- **Diagnostics setting:** Mini-player long-press shortcut can be turned off to keep the former karaoke interaction.
- **GitHub docs:** Current README, technical setup, testing checklist, issue forms and release notes.

### Performance and resilience
- Replay polls at most once every 10 seconds with a 2-second timer tolerance, rather than adding another high-frequency view hook.
- Replay persistence is throttled and its on-device database is bounded.
- Playback tracking pauses while backgrounded; no time is backfilled for missed samples.
- Presentation of ShrubPanel guards missing windows, duplicate modals and unavailable navigation APIs.
- Public release notes distinguish automated builds from device-verified releases.
- Build workflow runs a fast syntax/shell preflight and invokes the build script through Bash to avoid lost executable-bit failures.

### Compatibility / known issues
- This is a **source update**, not a claim of successful macOS compilation or iPad validation.
- UI hooks remain dependent on Spotify internals. Studio and queue navigation can vary by Spotify version; Replay depends on MediaPlayer now-playing metadata.
- Queue snapshots do not reconstruct Spotify's real queue.
- No guarantee of zero crashes; use Stability Mode to isolate optional hooks and attach logs to bug reports.

## 2.0.0
- Shrubify branding, artwork, developer attribution, diagnostics and Stability Mode.
- Preserved upstream author credits and GPL-3.0 license.

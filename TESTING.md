# Shrubify 4.1.5 testing checklist

## 4.1.5 acceptance

- Open custom lyrics on bright, dark and high-contrast covers: current and surrounding lines remain sharp and readable, including unsung words.
- Confirm the filled custom-lyrics button has an icon, rounded label and usable tap target.
- Confirm Settings displays Shrubify as the local plan label; actual subscription/billing details stay unchanged.
- Test free-account track transitions, home/search/playlist ads and foreground return. No claim of complete ad coverage is made without device testing.
- Confirm native iPad fullscreen and pause controls still work.


This checklist is for **real builds on devices**; passing source-only syntax tests does not mean installation, hooks or user flows have been verified.

## Build and install

- [ ] GitHub Actions Swift compilation + tweak staging succeed on macOS.
- [ ] IPA validation succeeds with the expected `com.shrubify.client` identifier.
- [ ] Properly sign all nested components and install with a profile permitting that bundle ID.
- [ ] Confirm install and first launch on supported iPhone and iPad OS versions.
- [ ] Confirm install works when official Spotify is also installed.
- [ ] Verify login/session survival across cold restarts.

## iPad recovery acceptance

- [ ] Verify native iPad player expands to fullscreen and returns to its pane.
- [ ] Verify play/pause, skip, seek, volume, output routing, queue and save using native controls.
- [ ] Verify the original navigation has no injected capsule or native-bar mask, including during scrolling and pane resizing.
- [ ] Verify album/playlist/artist headers and track rows retain native alignment.
- [ ] Verify new lyrics providers, login and local data survive an in-place update.

## Appearance and listening features (custom interface applies to iPhone during recovery)

- [ ] Studio opens Evolved player, tab/mini-player, page and lyrics controls.
- [ ] Previous layout archives remain stored and are not applied to the new renderer.
- [ ] Evolved artwork, backdrop and player controls respond correctly to track changes.
- [ ] Spotify and Apple Music player styles switch correctly.
- [ ] Chosen accent persists; system glass is gated to iOS 26+.
- [ ] ShrubPanel opens from settings; mini-player gesture functions where available.
- [ ] Presentation dismisses cleanly without multiple stacked panels.
- [ ] Replay disabled by default; enabling it collects only when valid title/artist metadata and active playback exist.
- [ ] Pause, background, seek, skip and podcast cases do not incorrectly count listening.
- [ ] Playback tracking persists across relaunch; erase action deletes all Replay and snapshots.
- [ ] ShrubQueue opens the native queue when navigator is available and reports unavailable otherwise.
- [ ] Track bookmark and recent snapshots work; unsupported track URLs show a message, not a crash.

## Stability

- [ ] Test 30-minute active playback, 20 skips, background/foreground, lyrics opening/closing, orientation rotation and offline state.
- [ ] Test with Stability Mode on and off.
- [ ] Examine exported debug log and any device crash report, noting OS and Spotify versions.
- [ ] Check VoiceOver, long titles and small-screen layout before calling the UI polished.

## Known platform limitations

Spotify changes private classes between releases. Hook compatibility and login behavior require per-version device checks. Local Replay listening times are approximate while the app is active and don't use Spotify's historical listening data. Queue snapshots are bookmarks/recent sessions, not real queue serialization. No automatic tests can guarantee zero crashes.

## Evolved-inspired listening tools

See [integration notes](docs/EVOLVED-INTEGRATION.md#validation) for timer, typography and Replay device checks. Run `bash scripts/test_listening_tools.sh` alongside the beta regression harness on a machine with Swift installed.

## 4.1.5 regression acceptance

Run `scripts/test_pr_integration.sh` for responsive geometry and obsolete-request cancellation, plus `scripts/test_v4_beta.sh` for ABI-checked native pause/seek and long-podcast clock fixtures. Run the full native validation workflow before shipping.

On device: compare iPhone portrait/landscape and iPad fullscreen/Split View/Stage Manager; rotate and resize with lyrics open; test large text, VoiceOver, Reduce Motion and Reduce Transparency; confirm one menu, readable artwork/controls, reachable footer, native fallback and native-size mini-player controls. Exercise all transport/queue/output/save/seek controls, short tracks in Replay, endpoint resets, token deletion, source changes, rapid track skips, network recovery, old SponsorBlock action toasts, disabling SponsorBlock while playing and sleep-timer pause confirmation in foreground/background.

## 4.1.5 crash and navigation regressions

- `scripts/test_v4_beta.sh`: modern track with a throwing legacy artist getter, legacy-only track, missing/throwing/scalar metadata, incomplete startup recovery and a subprocess exiting without normal cleanup.
- `scripts/test_pr_integration.sh`: bounded navigation geometry for 320–1280 point containers.
- `scripts/test_navigation_surface.sh` is a legacy experimental component diagnostic only. It missed nested backing and real scrolling/touch failures and is not a release acceptance test. Tablet recovery skips those custom interface hooks entirely.
- On the reported iPad: update in place, open with restored playback, play/switch several songs, reopen, inspect the Home bar and repeat with a visible mini-player. Confirm data is preserved and keep the crash report if a different fault occurs.

## Original Shrubify custom lyrics restoration

- Run `scripts/test_restored_lyrics.sh` for real syllable grouping, word timing, line-only sources, CJK/RTL rendering data and contributor links.
- `scripts/test_v4_beta.sh` also checks direct player clock ABI and stale duration/pause state after a track transition.
- Native staging must compile and bundle `KaraokeBackgroundShader.metallib`. Verify the resource in both the DEB and IPA.
- On device: open the original modal through settings/ShrubPanel/footer, close it, seek a lyric, pause/resume, switch tracks, try missing/line-only lyrics and confirm saved appearance settings. Check background/foreground, Reduce Motion and Low Power Mode.
- Confirm native iPad player fullscreen/playback and navigation still work after closing custom lyrics.

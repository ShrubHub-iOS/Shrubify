# Shrubify 4.1.8 testing checklist

## UI changes on this branch

- `bash scripts/test_lyrics_interactions.sh` creates its own disposable iPad on the **iOS 26.1** runtime; it must not boot, shut down or delete an existing simulator. The PR runs the compile job and this interaction suite independently.
- The iPad fixture samples rendered pixels in a high-contrast Home thumbnail and player cover. They must stay sharp with the old glass preference explicitly on and with it off. It scrolls a real collection view through reuse, taps a shortcut, a track and a player control, and checks for zero content materials or icon wells. The independent custom-lyrics fixture still exercises Sync and browse/resume.
- On the **reported iPad**, update in place and compare **Studio → Glass on bottom bars** off/on. Check the eight Home shortcuts, “Jump back in”, “Recents”, a long track list and the expanded Now Playing cover. In both settings, compare the art with the native mini-player thumbnail: no frost, extra outlines or button bubbles. Fling the same warmed-up shelves in both directions while music plays, skip tracks, expand/collapse the player, rotate and resize Split View. Verify native taps/swipes and smooth scrolling. If hitches persist, record the device, OS, Spotify build and an Animation Hitches trace on the same route.
- With Reduce Transparency on, or Stability Mode on at launch, both bars must be native. Unknown or oversized bar layouts should also stay native. Simulator captures are **fixtures, not Spotify screenshots or device frame-time measurements**.
- In **Lyrics → Lyrics appearance**, compare blur 0, 1, 2 and 4; open custom lyrics on a narrow phone. Drag through the words, let playback advance, then tap **Back to current line**. Confirm line taps still seek and **Sync** expands/collapses without moving the playback bar offscreen. Check both settings navigation and the long-press ShrubPanel route.

## 4.1.8 controls and material acceptance

- Run `bash scripts/test_lyrics_interactions.sh` on macOS/Xcode 26.1.1 with an iOS 26 simulator. It taps production controls through XCUITest, including button edges, delay/reset, play/slider and three close/reopen cycles while the view updates.
- The same suite starts with a missing preference (native bars), then checks exactly one decorative UIGlassEffect behind each recognized bar, backing restoration, unchanged button frames and native actions. It does not run Spotify itself.
- On device: confirm all lyrics controls respond across their full visible areas, close/reopen works repeatedly, only opted-in, supported native tabs/mini-player show material, and existing fullscreen/playback/follow/line seeking remain functional.
- Actions attaches XCTest result bundles and screenshots; publication waits for this suite to pass.


## 4.1.8 acceptance

- Check bright/white, saturated and dark artwork: no header/reading rectangles or active-line outline; lyrics remain readable over one continuous background.
- Check −/+ advances/delays the displayed lyrics by 100 ms immediately, reset returns to zero, reopening preserves the value, and tapping a lyric seeks with that same delay.
- Use real KRC/QRC/TTML word-timed tracks: fill advances inside each word, rewinds after backward seek, and follows the actual playback clock. Line-only LRC is labeled honestly.
- Check close/follow/timing glass shapes after rotation, compact width and Reduce Transparency; check the compact playback capsule and native five-tab dock with glass on/off.
- Confirm playback, fullscreen opening/dismissal, all tabs and multiple windows remain functional.


## 4.1.8 appearance and interaction acceptance

- Check that the custom-lyrics icon matches the native footer icons and opens the original fullscreen view.
- Check bright/dark covers, portrait/landscape and split-screen: blurred artwork remains visible, sharp lyrics stay inside the reading panel, and word timing still follows playback.
- On iOS 26, check glass close/follow/playback controls and native iPad tab/mini-player materials. Turn off **Glass on bottom bars** and confirm its material disappears without changing controls.
- Test Reduce Motion, Reduce Transparency, Low Power Mode, track changes and foreground return.
- Test all native tabs, mini-player play/pause, fullscreen opening/dismissal, lyrics scrubbing and multiple windows. Native actions must work with glass on and off.


## 4.1.8 acceptance

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
- [ ] With bottom-bar glass off, verify navigation has no injected material or mask, including during scrolling and pane resizing.
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

## 4.1.8 regression acceptance

Run `scripts/test_pr_integration.sh` for responsive geometry and obsolete-request cancellation, plus `scripts/test_v4_beta.sh` for ABI-checked native pause/seek and long-podcast clock fixtures. Run the full native validation workflow before shipping.

On device: compare iPhone portrait/landscape and iPad fullscreen/Split View/Stage Manager; rotate and resize with lyrics open; test large text, VoiceOver, Reduce Motion and Reduce Transparency; confirm one menu, readable artwork/controls, reachable footer, native fallback and native-size mini-player controls. Exercise all transport/queue/output/save/seek controls, short tracks in Replay, endpoint resets, token deletion, source changes, rapid track skips, network recovery, old SponsorBlock action toasts, disabling SponsorBlock while playing and sleep-timer pause confirmation in foreground/background.

## 4.1.8 crash and navigation regressions

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

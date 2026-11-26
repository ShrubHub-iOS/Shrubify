# Shrubify 4.2.5~beta13 testing checklist

## 4.2.5 beta 13 on iPad

- Scroll to the artist card while playing “Conversations.” Check that the entire portrait is visible at a compact size in both layouts. Skip to a different artist while the photo is loading and confirm the previous portrait never appears.
- In fullscreen, tap the artist name below the track title. Repeat with Open artist page in the artist card. Both should show the Spotify artist page beside the player, without a prompt.
- In fullscreen, tap the down arrow and check that playback continues in the bottom-right mini-player. Tap the fullscreen icon on a separate visit and check that the player returns to the sidebar.
- Expand and collapse the sidebar with a lyric and with the artist card on screen. The rounded transition should preserve the current content, and Reduce Motion should use the short fade.
- Open fullscreen from the sidebar, tap the close button, and repeat. Test on a bright Canvas track, after opening and closing settings, and across rotation. Confirm that the header stays readable and no duplicate artwork comes through.
- Swipe up past playback controls to the About the artist and Song credits sections. Swipe back to playback and toggle fullscreen twice. Confirm the current track, artwork, lyrics and controls stay in Shrubify's player and stale credits never appear after a skip.
- Check that the tab selection sits behind the active label and icon. A tab at an unsettled edge should have no clipped selection shape.
- On Home, scroll bright imagery behind the dock before playing a song. Check that the areas to the left and right of the tab buttons show the page without any second surface. Start playback and check that glass is visible on the first mini-player frame.
- Scroll bright tiles behind the mini-player. Check that the cover corners and the progress rail stay inside the same rounded surface. Start playback on Home and check the selection lens as the tab layout changes.

- Watch a verse switch between one and two lines. The lyric should keep the same top edge, fade in by itself, and maintain word timing. Check Reduce Motion, backward scrubbing, and tapping to open the full view.

- Start a track from an album before opening Now Playing. Confirm every tab remains visible and tappable and the right mini-player shows glass across artwork color changes. Open the split player first, confirm the cover appears, then expand immediately. Watch the native header and background on first open and after returning from fullscreen.
- Play through several word-timed lyric lines without touching the player. Short gaps should retain the previous line at steady contrast, long instrumental gaps should clear it, and skips should never display the preceding track's lyric.

- Scroll bright and dark artwork underneath the Home and album docks. Check that the material shows the page beneath it and labels stay readable. Switch tabs and resize or open the split player while watching the selection and plate alignment.
- Open and close the mini-player repeatedly. With two bars present, confirm both show the page through the glass. Toggle glass off and verify native backings return.
- Open full screen and split Now Playing over bright Canvas. Check that the transition below the header has no hard edge. The playback, volume and shortcut rows should fit in the normal split pane. Change tracks and use the stock pane, dismiss and menu buttons.
- Play “Conversations” and “Bad Energy” from Legends Never Die. Tap Lyrics before the initial lookup finishes and try rapid skips, an offline retry and reopening. Verify timed lyrics follow the playing track and native lyrics survive a failed custom request.

- Tap the cover in split view and fullscreen. Check the native tilt viewer when Spotify exposes it. In Shrubify's viewer, drag the cover and tilt the device to see the reflection move. With Reduce Motion enabled, the cover stays still. Dismiss the viewer and verify playback and the current track stay intact.
- Scrub both directions during a lyric and across a gap. Verify the live line tracks the song, the preview stays aligned under the cover, and tapping it opens lyrics without changing playback.
- Try a known word-timed lyric and a line-only response such as the LRCLIB versions of “Conversations” and “Bad Energy.” Check the timing label, partial lines, retry, and follow after manual scrolling.

- In Lyrics settings, select lrc.red, then LyricsPlus. Open “Conversations” or “Bad Energy,” seek in both directions, and check that provider and word timing are correct. Then try Automatic Selection and the usual fallback behavior.
- Check the iPad header during split and full-screen transitions. Native buttons and their labels should remain fully visible, the backdrop should blend smoothly below the header, and a second cover should never appear. Verify the selected word clears during gaps and that Dynamic Type retains all playback controls.

## Selective native glass acceptance

- Switching among Home, Premium, Library and Search repeatedly must not reintroduce old bar backings. Native background, opacity and blur snapshots are captured once per view and restored in reverse order when glass is disabled.
- The dock's glass sits under its known Spotify host. The mini-player's glass sits inside its bar behind the controls and uses the more legible Regular material on the Clear setting.

- Clear and Regular use distinct UIKit glass styles; unconfigured appearance defaults to Clear. Tinted alone uses accent tint. No synthetic rim or specular layer.
- Enabling glass clears only known native bar backings, including layer-level colors and opaque drawing flags, and fully restores them on disabling; decorative views containing real controls/artwork must never be hidden.
- Open two iPad windows if supported: each recognized bar gets one plate from its dedicated host hook. No broad window scans, no stale Home oval, and no visible rectangular backgrounds outside the capsule.
- Check the Home shortcut tint, rounded corners and filters on iPad. Every filter and shortcut remains tappable. Resize and scroll through recycled tiles; no stale artwork tint or glass over artwork.
- The older oversized selection oval is gone. Spotify's native selected state remains visible and follows real navigation; no injected selection background survives on another page.
- Device layout and scroll-inset acceptance remain required; simulator fixtures do not run Spotify itself.

- The tab bar must read as **one** capsule over the page: no doubled rim, no second capsule edge inside the first, and the page shows through it. On iPad the mini-player is owned by the native glass layer too (the iPhone mini-bar capsule is switched off there), so the two bars no longer overlap.
- Open the full-screen and sidebar player. Verify that both show the artwork-led layout, the native header can switch presentation, and the lyrics and playback actions work.
- Studio -> Liquid Glass -> **Glass status** reports whether glass is attached to the tab bar or mini-player.
- Turn Liquid Glass off and back on: the bars return to Spotify's own look byte for byte (backgrounds, materials and hidden gradients restored), then the glass returns without a restart.
- 4.2.3 lyrics acceptance still applies: a source that cannot answer is rescued by LRCLIB (then Genius when its switch is on) before "no lyrics found", and a title with a suffix still resolves.
- Play a popular song with a source that cannot answer (for example select Musixmatch with an invalid token). The lyrics must still appear: the log shows `safety net: trying LRCLIB` and the provider line names the source that actually answered.
- A Spotify title with a suffix (`(feat. …)`, `- Remastered …`) must still resolve on LRCLIB: the log shows either an exact match for a stripped variant or `search matched "…"`.
- Open lyrics for a track whose Musixmatch subtitle list is empty; the app must show "no lyrics found" at worst — never crash.

## 4.2.2 bulletproof chrome acceptance

- Studio -> Liquid Glass reports actual tab and mini-player discovery; the transport row intentionally has no glass plate.
- The tab bar must now be see-through glass over the page, not a lighter capsule on a black pill: the cleared backing is what shows the content beneath.
- Turn the master switch off and confirm the tab bar's original black backing and gradient return exactly, with no leftover clear backgrounds.
- Rotate, resize Split View, open and close the player and a sheet, then confirm the plates follow or disappear and never sit above a modal.
- Taps must still reach every tab, the mini-player and all transport buttons; the plates never accept a touch.

## 4.2.1 visible chrome acceptance

- On iPadOS 26 the native bottom bar must show content through it; the expanded player must have no injected transport card.
- The material must be clearly visible on Spotify's near-black chrome; it is deliberately boosted above the shared default used by custom screens.
- Open a track list, scroll it under the tab bar and confirm the capsule stays above Spotify's opaque backing and never intercepts a tap.
- Turn the master switch off: all three plates go and Spotify's own chrome is untouched. Reduce Transparency removes them too.

## 4.2.0 iPad chrome acceptance

- On iPadOS 26 default settings: only the bottom bars show glass, with native controls and artwork unobstructed.
- Open the expanded player and drag the **Intensity** slider in Studio; all three surfaces and the two bottom bars must update live.
- Turn Glass on bottom bars off: both bars restore their original appearance and player controls remain unchanged.
- With Reduce Transparency on, no plate may remain. Check the debug log for `[GlassChrome] mounted` lines to confirm which surfaces were found on this Spotify build.
- Confirm taps still work on every tab, the mini-player and all three transport buttons, and that the plate never receives touches.

## 4.1.9 glass, player and ad acceptance

- Studio → App appearance → **Liquid Glass** on iPhone and iPad: switch the material between Clear/Regular/Tinted and drag intensity while the player, tab bar and mini-player are visible; every mounted surface must update without relaunching.
- Confirm Reduce Transparency replaces the material with an opaque fill and Increase Contrast strengthens the rim on both idioms.
- iPadOS 26: enable **Glass on bottom bars**; the native tab bar and mini-player get the same material. Turn the master switch off and confirm both return to Spotify's original backings.
- Open the player on iPhone and iPad: the custom lyrics button must be reachable. On layouts without the recognised footer row it appears as a floating glass button and opens the fullscreen custom lyrics view.
- Play a free-tier session through several track changes and check that no in-stream audio ad, under-player ad card or ad-break eligibility request appears. Inspect the debug log for `[AdBlock]` attribution when one does.

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

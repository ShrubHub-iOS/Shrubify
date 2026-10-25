# Shrubify 3.0 testing checklist

This checklist is for **real builds on devices**; passing source-only syntax tests does not mean installation, hooks or user flows have been verified.

## Build and install

- [ ] GitHub Actions Swift compilation + tweak staging succeed on macOS.
- [ ] IPA validation succeeds with the expected `com.shrubify.client` identifier.
- [ ] Properly sign all nested components and install with a profile permitting that bundle ID.
- [ ] Confirm install and first launch on supported iPhone and iPad OS versions.
- [ ] Confirm install works when official Spotify is also installed.
- [ ] Verify login/session survival across cold restarts.

## Shrubify 3.0 features

- [ ] Studio presets activate the right player elements after restarting.
- [ ] Save, restore and delete layouts; verify after force quit.
- [ ] Artwork corner-radius slider updates the backdrop-hook cover appearance.
- [ ] Minimal hides only chosen elements; Classic restores default appearance.
- [ ] Immersive preserves existing accent and avoids unsupported Liquid Glass APIs on older iOS.
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

# Listening improvements inspired by EeveeSpotifyEvolved

Reference: [zbzxbg/EeveeSpotifyEvolved](https://github.com/zbzxbg/EeveeSpotifyEvolved),
revision `92d783486d527c20ccffb759de523d6c7b956547` (GPL-3.0).
Shrubify base: `8a62e42734038aa6aa0d6281a9c25fcb77d14e36`.

## Included

- **Sleep timer:** 1, 5, 10, 15, 30, 45, 60 or 90 minutes, available from
  Listening settings and ShrubPanel. The GCD timer approach is adapted from
  Evolved's `Sources/EeveeSpotify/Playback/SleepTimer.swift`. The implementation
  here uses a monotonic deadline and serializes all state on the main queue.
  Cancellation/replacement invalidate old callbacks. Expiry uses Shrubify's
  exception-guarded explicit pause bridge, never a play/pause toggle. This avoids
  guessed selector signatures and cannot resume already paused music.
- **Lyrics typography:** adjustable 22–40 pt type and 8–32 pt row spacing.
  Inspired by Evolved's typography controls and `LyricsTypographyPreview.swift`;
  implemented using Shrubify's own `KaraokeLineView`. The iOS 16+ preview uses
  original sample text and the same renderer and settings as custom lyrics.
  Preview hit testing is disabled so it does not capture settings scrolling.
  Older saved settings retain 30 pt type and 16 pt spacing. Reopen custom
  lyrics after editing. Controls remain available on older systems; the
  renderer preview requires the wrapping layout introduced in iOS 16.
- **Replay summary:** 7-day, 30-day, 1-year and all-retained listening-time totals,
  plus the number of listening days. Daily totals already held by Shrubify
  support those summaries without collecting extra data. Song/artist rankings
  remain lifetime totals for retained tracks and are labeled accordingly.

The preview and timer screens use SwiftUI shapes, gradients and SF Symbols.
No upstream screenshots, song lyrics, logos, audio or artwork were copied.
Existing upstream author notices and Shrubify's GPL license remain intact.
The Evolved README's upstream credits identify Taurus as conceptual inspiration
for its timer, with no Taurus source copied; no Taurus source was used here.

## Compatibility and validation

No new Spotify hooks, network providers or background entitlements are added.
The timer needs a player captured by Shrubify's existing playback hooks. If the
pause bridge is unavailable it reports that result on the timer page. It does
not modify Spotify's native sleep timer. There is no persistence across process
termination. GCD cannot bypass iOS suspension: expiry can be delayed until the
app is scheduled again; foregrounding immediately checks the deadline.

Run `bash scripts/test_listening_tools.sh` for monotonic deadline, cancellation,
replacement and delayed-wake tests. Existing `scripts/test_v4_beta.sh` covers
settings migration, typography bounds and round-trip persistence. The native
validation workflow runs both before building the tweak on macOS.

Local verification in the Linux workspace: 14 Python unit tests, branding and
iOS 14 source preflights, shell syntax and diff whitespace checks passed.
Swift, Xcode, an iOS SDK and a physical iPhone are unavailable here; native
compilation, visual layout and actual playback behavior are not locally verified.

Device checks before release:

- Start a 1-minute timer, close its page, and verify a pause at expiry.
- Cancel/restart near expiry; verify the old timer cannot affect playback.
- Pause manually before expiry; verify the timer never resumes playback.
- Test background playback, lock screen, suspension/foreground and force quit.
- Confirm unsupported builds show the unavailable-controls message.
- Adjust lyric text size, spacing and alignment; reopen lyrics and compare with
  the preview, including long lines and RTL text. Test VoiceOver and Reduce Motion.
- Check Replay's periods against exported daily totals; verify opt-in tracking
  remains off on a fresh install and privacy/reset still work.

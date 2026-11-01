# Beta 2 update

Seek now updates the lyric clock immediately and ignores stale-position callbacks for up to two seconds. The lyric header has dedicated layout space. Settings-hosted ShrubPanel uses the existing navigation stack, avoiding duplicate title bars.

Lyrics settings include reorderable fallbacks: main provider first, then enabled fallbacks on empty/error results, without duplicate requests. Default main remains SpicyLyrics; default fallback is LRCLIB, with legacy Genius fallback preserved unless a custom list is saved. Credentials are required for providers that use them. Genius supplies plain text only.

Taurus-inspired prominent glass appears above Vitrine. Both archives use the same system material; the distinct preset adds Taurus’s 0.14 white prominent film, not a full Taurus redesign. Vitrine remains selectable and existing settings remain readable.

Stability guards cover non-finite playback clocks, absent diffable indices, romanization failures and integer conversion of timestamps. Metal backgrounds pause outside the active scene, run at 15 fps in Low Power Mode, and release their renderer when dismantled. No device crash reports were supplied: crash elimination, heat and battery claims cannot be verified from these checks.

Device checks: repeated forward/backward lyric taps, automatic following after seek, source failures with a custom fallback order, native/custom lyrics modes, ShrubPanel from Settings and as a modal, Vitrine/Taurus options after restart, and background/foreground playback. Record exact Spotify/iOS versions and export .ips crash reports for remaining crashes.

---

# Shrubify 4.0.0 beta 1

This first beta builds on 3.0.6 and preserves its playback engine, injection/signing paths, account behavior, existing glass integration and v3 storage keys. Taurus versus Vitrine is still undecided; no Taurus hooks or assets are imported.

## Included

- Replay history search by title/artist, last-heard date filters, and user-initiated JSON export of retained tracks, daily totals and snapshots. Date filters do not recalculate historical listening totals: per-song totals still cover its entire retained history.
- Search saved snapshots by name, song or artist. Deletion resolves against the filtered list so the correct snapshot is removed.
- Global custom-lyrics timing adjustment from -5 to +5 seconds in 100 ms increments, applied consistently to highlighting and tap-to-seek. Positive values delay lyrics. Reopen the custom lyrics screen after changing timing.
- Studio now saves artwork radius in new layouts. Old layouts still decode, and restoring an old layout leaves the current radius intact.
- ShrubPanel shortcut visibility controls, all enabled by default.
- Settings labels can grow vertically, the hero no longer adds glass inside the existing list surface, and Replay metrics use rows that accommodate larger text.
- Replay rankings are computed once per data publication instead of repeatedly during rendering; samples do not publish twice when persisting. Lyrics notifications are coalesced, the existing eight-track cache refreshes recency on reads, and the lyric animation timeline pauses outside the active scene.
- Debian beta version `4.0.0~beta1` maps to GitHub tag component `4.0.0-beta1`. A future release workflow marks beta releases as prereleases and does not make them latest. Prereleases are excluded from the stable source feed.

## Preserved limits and deferred v4 work

Replay stays opt-in and foreground-only. Snapshots do not restore Spotify's real queue. Custom-only lyrics mode still hides supported native entry points rather than removing Spotify's implementation. Beta 1 does not include provider-chain fallback, manual lyric matching, actual queue editing, a full player redesign or a Taurus migration. Those require separate implementation and compatibility evaluation.

## Validation

Run `python3 -m unittest discover -s scripts/tests -p 'test_*.py'`, `python3 scripts/check_ios14_swiftui.py`, and `python3 scripts/check_shrubify_branding.py`. On macOS run `bash scripts/test_v4_beta.sh` for settings migration, delay/seek agreement, bounded timing arithmetic, search, cache eviction and notification coalescing. The native PR workflow runs this harness and compiles the release tweak without publishing.

Before distributing an IPA, test on a device: cold launch/login, playback and seeking, positive/negative lyric offsets, background/foreground, old and new saved layouts, large text, Replay search/export/deletion, filtered snapshot deletion, and panel preferences. Record exact iOS/Spotify versions. App speed and battery improvements need measurement; reducing repeated work is not a measured speedup claim.

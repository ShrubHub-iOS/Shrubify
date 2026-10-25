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

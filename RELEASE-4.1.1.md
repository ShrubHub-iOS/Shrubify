> Archived release. Current release: [Shrubify 4.1.4](RELEASE-4.1.4.md).

# Shrubify 4.1.1

A maintenance update for the broken player layout and playback/lyrics defects found in the 4.1.0 audit.

- Replace competing player overlays with a responsive player: bounded square artwork, separate wide-screen columns, scrollable short-window controls, accessible actions and a native-player fallback when required controls are unavailable.
- Keep mini-player text and controls at native size. Remove redundant tab backing and invalidate glass measurements after resizing. Use the supported system glass initializer, adaptive fallback material and Reduce Transparency handling.
- Validate malformed translation and Siri data, cancel obsolete lyrics work, coalesce duplicate lookups and bound total request latency. Fix LRCLIB endpoint changes, token clearing and stale translation cache results.
- Stop SponsorBlock when disabled, reject old Skip/Undo actions after track changes and use the ABI-checked seconds seek bridge. Preserve long-podcast durations and isolate fetch generations.
- Refresh Replay playback state before its fallback, check metadata identity, count short tracks, verify sleep-timer pausing and use the triggering window for ShrubPanel.
- Synchronize current app labels, package version and documentation on **4.1.1**. Spotify's own version and historical release records remain separate.

Requires iOS 17.4 or later. Native Liquid Glass and the integrated lyric renderer require iOS 26 or later; earlier supported versions retain native lyric presentation.

Validation covers automated regression tests and native compilation. iPhone/iPad visual, VoiceOver, output-route and background playback acceptance must also be checked on a device; automated checks do not establish that every Spotify build is compatible.

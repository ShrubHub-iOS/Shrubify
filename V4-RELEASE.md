Shrubify 4.0.0

This is the full v4 package version. It retains existing settings, Studio layouts, Replay archives, ShrubPanel, ShrubQueue and glass choices. Account credentials and signing/bundle identity behavior are unchanged.

Included improvements:

- Asynchronous lyric loading with bounded, cancellable provider work, shared requests, eight-track result caching and configuration-aware invalidation.
- Primary source plus ordered fallbacks, with prompt fallback on queued SpicyLyrics responses. The custom view stays open while loading and offers a retry for missing timed lyrics.
- Lyric tapping, pause/play, elapsed/remaining time, a scrubbable progress bar and an optional Follow lyrics switch.
- Safe LRC and provider timing conversion, correct final-line handling and instrumental results. Timed fallbacks remain usable with Genius as the main source.
- Independent settings window and scene-aware alert/presentation lookup. Live account configuration replaces the old bundled-cohort overwrite behavior; old cached configuration is cleared once without erasing account or listening data.
- Request buffer cleanup and task-identity replay tracking; one body/completion sequence for custom lyric responses. Legitimate configuration, signup and reconnect requests are no longer cancelled just because 30 seconds elapsed.
- Correct shader packaging, unchanged-texture reuse, refreshed lyric artwork and reduced background activity for accessibility/power preferences.
- Studio preset identity fixes and estimated Repeat One recognition in Replay. Spotify track URIs separate recordings where available, with migration from existing title-based history.

The supplied beta 4 crash is a native missing-tab-page assertion. Independent settings presentation and preserving live account navigation configuration target that failure area. Its exact missing URI was absent from the IPS, so a device confirmation is still required; this release does not claim every crash is eliminated. Performance work removes known waits and repeated work, but temperature and battery improvements have not been measured on a device.

Validation before publication runs Python build-tool tests, Swift syntax checks, compiled playback-bridge fixtures and compiled request/parser/coordinator regressions. The final IPA is checked for archive integrity, branding, required tweak resources and signing-file cleanup.

Device checks to perform after signing: fresh login and settings navigation, relaunch, reconnect after several minutes, rapid skips, missing and queued lyrics, provider/fallback changes, rejected seeks, pause during seeking, Repeat One, iPad scenes, large text, Reduce Motion, Low Power Mode and background/resume. Stability Mode and existing diagnostic export remain available for compatibility issues.

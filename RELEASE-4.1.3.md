> Archived release. Current release: [Shrubify 4.1.8](RELEASE-4.1.8.md).

# Shrubify 4.1.3

This is an iPad compatibility recovery after the broken replacement UI in 4.1.1–4.1.2.

- iPad now keeps Spotify's native player, fullscreen presentation, play/pause, seeking, volume, queue and output controls. The replacement player that covered them is no longer installed on tablets.
- Skip the injected tablet navigation, mini-player and album/playlist/artist page layouts. This removes the replacement capsules and header overlays responsible for the duplicated backing, clipped icons and misplaced page content.
- Skip experimental remote flag overrides on iPad so the native presentation is not forced into a conflicting configuration. Stored appearance preferences are retained. Settings explain tablet recovery instead of advertising inactive appearance controls.
- Keep the 4.1.2 metadata crash guard, startup recovery and complete expanded lyrics-provider layer. Existing iPhone appearance controls remain available.
- The old standalone capsule screenshot test is no longer a release gate: it did not exercise Spotify's controls, fullscreen presentation or scrolling. Source checks, behavioral regressions, full native compilation and IPA inspection remain required.

This update restores the native iPad interface while Evolved tablet integration is unfinished. Full Spotify interactions still require an on-device check; native compilation cannot prove those interactions work on every Spotify build.

Install over the existing app with the same bundle identity and compatible signing to retain local data.

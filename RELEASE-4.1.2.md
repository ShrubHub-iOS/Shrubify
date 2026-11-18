> Archived release. Current release: [Shrubify 4.1.4](RELEASE-4.1.4.md). The navigation component test from this release did not cover the reported Spotify iPad UI failures.

# Shrubify 4.1.2

This hotfix addresses the playback crash and oversized navigation backing reported in 4.1.1.

- **Playback crash:** the crash report was matched to the exact 4.1.1 dylib. Its failing Objective-C message was `artistTitle`, a legacy getter unavailable on current Spotify. The player and Replay now use an ABI-checked metadata bridge that prefers `artistName`, checks method availability and contains Objective-C exceptions. Unsupported metadata leaves the native player available.
- **Startup recovery:** a persisted incomplete-startup probe can enable Stability Mode on the next launch. The probe clears after a healthy main run loop or graceful background transition. This does not erase credentials, preferences or listening history.
- **Navigation backing:** host width is bounded by tab count (at most 352 points), rather than iPad-wide item slots. Measured UIKit insets no longer expand the host. Transparent bar appearance, explicit legacy material clearing and a bounded native-tab mask address the extra slab; original masks/materials are restored when disabled.
- **Regression coverage:** native Objective-C fixtures cover modern, legacy, missing, throwing and scalar-return metadata getters. A real iPad simulator renders the production navigation surface and checks for colored backing pixels outside its capsule.

Install as an update over the existing app using the same bundle identity and compatible signing. Do not delete the existing installation to troubleshoot this crash; deletion can remove local data. Device-specific Spotify integration still needs on-device acceptance testing; the simulator check covers the navigation component, not the full Spotify app.

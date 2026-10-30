# Shrubify 3.0.5 release candidate

- Repair native tooling cache: Theos builds Orion and Swift support under `.theos_build`, not `.build`. Cache both directories under a fingerprint of the compiler, Theos and recursive submodule revisions, computed once before compilation. The previous run rebuilt Orion for 256.92 seconds and could not save its cache. Warm-cache speed gains need a second Actions run to measure.
- Disable redundant artifact ZIP compression for the already compressed IPA.
- Remove Shrubify's added borders, tint overlays and shadows from glass panes. Vitrine material and system corner shaping draw their own edges; remove duplicate mini-player, tab bar and artwork rims as well.
- Allow settings descriptions to wrap and prioritize their text over spacers.
- Keep tab editor frames nonnegative during small/zero-width layout passes.
- Make Studio detail links work on Settings' UIKit navigation stack and retain SwiftUI navigation within ShrubPanel.
- Isolate saved-layout restore/delete buttons and enlarge the delete target.
- Add native macOS PR validation that builds the release tweak without downloading an IPA or publishing a release.

## Validation

Python regression suite and branding/iOS compatibility source checks pass locally. This workspace is Linux: UIKit compilation, device appearance, Spotify hooks, IPA installation, and cold/warm Actions timings have not been verified here. The PR's native validation must pass before merging. Test on the actual iOS version with Spotify 9.1.94 (the most recent successful repository build) or record the exact newer version used.

Device checks: Settings and Studio at large text sizes; restore versus delete; narrow tab editor; Vitrine on/off on iOS 26; player, mini-player, search and tab bar with album tint enabled/disabled. This refines the existing Vitrine material adapter; it does not port Vitrine's complete standalone redesign.

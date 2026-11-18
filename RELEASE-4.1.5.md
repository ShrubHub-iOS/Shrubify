> Historical release notes. Current release: [Shrubify 4.1.6](RELEASE-4.1.6.md).

# Shrubify 4.1.5

- Make the original fullscreen custom lyrics readable over any cover: darken artwork, remove text blur and compound fading, retain sharp surrounding lines, word animations and scrolling.
- Replace the plain custom-lyrics entry with a filled capsule, quote icon and rounded semibold label; style the settings entry as a prominent button.
- Restore local Shrubify plan branding independently of entitlement patching and endpoint version. Preserve actual subscription and billing data.
- Separate optional ad hooks so missing Spotify classes cannot disable unrelated blockers. Add bounded startup/foreground activation retries, method ABI checks and an independently guarded audio-ad getter.
- Keep network ad filtering active with native lyrics. Preserve the working native iPad player and navigation; Liquid Glass redesign is deferred.

Validation includes native compilation, existing playback/lyrics regressions, contrast across 1,001 cover luminances, ad-hook isolation and endpoint routing. Real-device audio/banner coverage and appearance still need testing; this release does not claim every possible ad format has been observed and blocked.

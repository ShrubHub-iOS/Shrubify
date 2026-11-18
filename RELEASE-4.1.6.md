# Shrubify 4.1.6

- Replace the oversized custom-lyrics capsule with a white lyrics icon in a native footer slot, retaining an accessible name and touch target.
- Restore visible blurred album artwork, including a static artwork fallback for Reduce Motion, Low Power Mode and unavailable Metal. Keep sharp lyrics inside a rounded reading panel, with a bounded text width on iPad.
- Add native Liquid Glass to custom-lyrics close/follow controls and a compact playback tray on iOS 26. Glass no longer replaces the artwork backdrop. Respect Reduce Transparency with opaque materials.
- Add decorative iPad glass behind supported native tab rows and mini-player content. Keep Spotify's frames, masks, safe areas, transforms, gestures, button actions and fullscreen presentation unchanged. Skip oversized/unrecognized layouts and existing native materials. Each window owns its material; switching the setting off removes it.
- Preserve the 4.1.5 ad-blocker and plan-branding fixes. No extra account or network changes.

Validation: native build and existing playback/lyrics regressions; contrast over 1,001 cover luminances; bounded glass geometry across phone/tablet/split-screen widths and invalid measurements. Visual appearance and native interaction inside Spotify still require device testing; this does not claim zero bugs across every Spotify/iOS layout.

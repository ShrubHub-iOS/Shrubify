# Shrubify 4.1.9

- Rebuild Liquid Glass as one shared material (`ShrubifyLiquidGlass`) used by the player, tab bar, mini-player, lyrics button and the native iPad bottom bars. iOS 26 uses the real `UIGlassEffect`; older supported versions use a tuned blur with the same rim and specular sheen. Reduce Transparency and Increase Contrast are respected.
- Replace the scattered glass controls with one **Liquid Glass** page in Studio: master switch, Clear/Regular/Tinted material, live intensity slider, and the iPad bottom-bar backing. Settings apply to both iPhone and iPad and update mounted surfaces without relaunching.
- Default the iPad bottom-bar glass on (the stored choice still wins) and drive it from the same master switch, so a single setting no longer behaves differently per page.
- Restore a visible custom-lyrics entry in the native player. When the native footer row can be recognised the button joins it; on iPad layouts without that row it becomes a floating Liquid Glass button on the player instead of disappearing.
- Draw the in-player lyrics key with the same glass material instead of a flat translucent circle.
- Harden ad blocking for in-stream audio: block ad-break bookkeeping (`adbreak`, `adslot`, `UpdateAdState`, `SetAlwaysEligibleForAdBreak`), ad-media paths, and the `adlogic` spelling; add independent kills for the ad-slot registrar, the ad state controller and the Betamax audio-ad picture-in-picture service.

## Verification limits

The Swift tweak cannot be compiled or run in this workspace: it needs Theos, an iOS SDK and a docked device or simulator. Behaviour below was not exercised on hardware. Device acceptance still has to confirm the glass material on iPadOS 26, the new lyrics entry on both idioms, and that the extra ad services are named as expected in the shipped Spotify build; every added hook is guarded on class and selector presence, so a renamed class is skipped rather than fatal.

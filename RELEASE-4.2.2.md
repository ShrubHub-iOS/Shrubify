# Shrubify 4.2.2 — bulletproof Liquid Glass

Three failure modes kept the glass off the screen. All three are closed here.

## 1. The glass was painted on an opaque pill

The plate was inside Spotify's bar, but Spotify drew its own near-black backing over the same area. The pass now clears that backing — bar background colour, bar material effect, and the legacy `TabBarGradientView` / `TabBarBackgroundView` layers — and records an exact undo for each change. Turning the switch off restores Spotify's chrome byte for byte.

## 2. A stale switch could silence everything

The pass also required the separate `ShrubifyNativeTabletGlass` value, which earlier builds stored while the feature did nothing. A `false` left behind there meant "no glass" with no way to tell. Only the master switch and Reduce Transparency decide now; Increase Contrast still strengthens the rim.

## 3. You could not see what it found

Studio -> Liquid Glass -> **Glass status** lists the tab bar, the mini-player and the player controls with **glass on** or **not found yet**. If a surface is missing on your Spotify build, that line says so instead of leaving you staring at a flat bar.

## Still true from 4.2.1

Plates anchor on the `TabBar.Item.*` views and the previous/play/next buttons, so a renamed container class cannot drop the material; they are boosted so they read on near-black chrome, non-interactive, hidden from accessibility, and bounded in the work they do.

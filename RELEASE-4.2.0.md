# Shrubify 4.2.0 — Liquid Glass everywhere

Shrubify 4.2.0 is about the one thing the 4.1.9 rebuild still missed: the iPad player and the app chrome around it were still drawn by Spotify, flat and dark, while the glass only reached the two bottom bars.

## What changed

- **One chrome pass, every surface.** A window-level pass finds Spotify's own tab bar, mini-player and player transport controls, then mounts a single decorative plate of the shared `ShrubifyLiquidGlass` material on each. No Spotify view is replaced, resized or made to lose a touch.
- **Found by identifier, not by hope.** The hosts are matched by accessibility identifier (`tabs-container-view-identifier`, `SPTNowPlayingBar`) *and* class name (`TabBarView`, `PlaybackControlsElementsUnit`). A Spotify rename therefore cannot silently remove the glass — the previous build's single-class hooks could, and did.
- **On by default on iPad.** Both the master switch and **Glass on bottom bars** ship on, and the settings page still turns either off immediately. The bar backing and the chrome pass recognise each other's plates, so no surface ever gets two layers of material.
- **Bounded and reversible.** One scan per 0.5 s with a fixed depth and node cap, plates that are non-interactive and hidden from accessibility, and removal on Reduce Transparency or when the switch is off.

## What to check on the device

- Tab bar, mini-player and player controls all show the material at launch with default settings.
- The Intensity slider moves all of them without reopening the player.
- Turning the master switch off restores Spotify's original backings; turning only the iPad bar switch off leaves the player's control card glassed.
- Every tab, mini-player tap and transport button still responds exactly as before.

# Shrubify 4.1.8

- Replace Close and timing earlier/later/reset with native UIButton targets that fill their visible controls, including taps away from thin symbol strokes. Preserve the working play, slider, follow and line-seek paths.
- Give every lyrics presentation its own dismissal session. Close cannot be suppressed by a stale global flag; add accessibility escape and keyboard Escape, and clear presentation state on external dismissal. Present opaque lyrics fullscreen to isolate input from the underlying player.
- Keep iPad Home, artwork, rows, tab icons and the expanded player native. Remove the glass renderer for individual items, its collection-cell hooks and its window/lyrics-triggered searches. Studio’s optional **Glass on bottom bars** setting (off by default) uses only recognized native tab and mini-player layouts.
- Clear only bounded native-bar colors and decorative legacy gradients that obscure glass, restore them on disable, and preserve original controls, frames, gestures and actions.
- Gate release publication on an iPad XCUITest suite using production controls, dismissal and material code: actual edge taps, timing/reset, repeated dismiss/reopen, existing playback/slider controls, wide-dock actions and glass on/off restoration. Screenshots and result bundles are attached to Actions.

The simulator fixture verifies these production components with controlled playback inputs. It does not run Spotify or prove every Spotify layout; real-device compatibility still needs validation.

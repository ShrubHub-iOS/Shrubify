# Shrubify 4.1.7

- Remove the custom lyrics header/reading panels and active-line outline. Use one continuous blurred album-art backdrop with a hue-preserving luminance cap, keeping text contrast without large black containers.
- Add visible earlier/later controls in 0.1-second steps, a delay readout and tap-to-reset. Update the renderer immediately, save the custom-view delay, and apply the same offset to lyric seeking.
- Increase real word-fill contrast, preserve source word/syllable timestamps, improve playback sampling to 30 Hz, respect Reduce Motion and label word versus line sync. Sources without real word timestamps remain line-synced.
- Round glass in layoutSubviews after actual bounds are known, add a visible edge, use a compact floating playback capsule and remove default rectangular button styling.
- Support the wider native five-tab iPad dock; remove its bounded legacy blur backing while glass is active and restore it on disable. Retain native frames, gestures, actions, safe areas and fullscreen presentation.

Validation covers native compilation, existing playback/provider regressions, artwork contrast over 1,331 RGB colors, timing bounds/word progress and native dock geometry. On-device appearance and Spotify layout compatibility still require testing; no claim of perfect operation across all providers or iOS versions.

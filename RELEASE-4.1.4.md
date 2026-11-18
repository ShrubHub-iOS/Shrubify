> Historical release notes. Current release: [Shrubify 4.1.6](RELEASE-4.1.6.md).

# Shrubify 4.1.4

Restore Shrubify's original fullscreen custom lyrics view from before the Evolved port. The original renderer, word/syllable animations, scrolling, credits and Metal background return as an independent feature.

- Open it from **ShrubPanel → Open custom lyrics**, **Lyrics / Lyrics appearance → Shrubify custom lyrics → Open custom lyrics**, or the custom-lyrics footer button when the native footer has room. The footer button gets its own arranged position and does not cover native controls.
- Restore the saved custom lyrics settings for text size, spacing, alignment, direction, blur and timing. The animated background is the default; optional glass is contained inside the standalone lyrics modal and does not reinstate the old global material integrations.
- Connect the original view to the expanded provider layer, keeping real word timing and clickable maker/uploader credits. Line-synced sources use line timing; untimed text does not receive an invented timeline.
- Restore guarded live-player capture independently of the Evolved player styling. Support direct StatefulPlayer clocks as well as state objects; unknown clock/playback state is displayed as unavailable rather than fabricated zero times. Track changes clear old duration and pause state.
- Keep the working 4.1.3 native iPad player, fullscreen presentation, navigation and page layouts. Keep the metadata crash guard and all expanded lyrics sources.

Native compilation, provider/clock regressions and packaged Metal resources are checked in CI. Spotify device interactions still require on-device acceptance; this is a restoration of the original Shrubify renderer, not a claim that the Evolved tablet redesign is finished.

Update in place with the same bundle identity and compatible signing to retain app data and preferences.

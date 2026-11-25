# Shrubify 4.2.5~beta8

- iPad Now Playing draws its header over a continuous darkened cover blur, using the same blur renderer as the lyrics view. The close button can restore Spotify's own navigation if the current layout has no usable exit action.
- Scrolling past playback opens Spotify's native details, including artist info and credits where available.
- The dock includes tabs hosted outside the main row. The mini-player's artwork and inset progress rail share the rounded glass boundary, with Regular glass for legibility on busy pages.
- Live lyrics keep a fixed top edge. The incoming line animates on its own while word timing follows playback.
- Artwork blur runs off the main thread, recursive bar layout is guarded, and an empty settings window lets touches reach Spotify.

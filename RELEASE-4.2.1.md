# Shrubify 4.2.1 — the glass you can actually see

4.2.0 mounted the plates, but it mounted them where nobody could see them. Two concrete bugs, both fixed here.

## What was wrong

- **The plate was underneath Spotify's pill.** It went in at subview index 0, so any opaque background view Spotify draws inside the same container covered it completely. Plates now detect an opaque backing and insert directly above it.
- **The material was too faint for this surface.** The shared neutral tint is about 7% white — correct over album art, invisible over Spotify's near-black chrome. Chrome plates now use a boosted tint (about 25%), a stronger specular sheen and a brighter rim, all still driven by the Studio intensity slider and still removed under Reduce Transparency.

## And it stops depending on class names

The tab capsule is shaped by the union of the real `TabBar.Item.*` views and the transport card by the union of the previous/play/next buttons. Those identifiers survive Spotify redesigns; a renamed container class no longer means "no glass".

## Device check

- A light glass capsule behind the tab items at launch, glass card behind the transport buttons in the expanded player.
- The capsule stays above Spotify's own backing while you scroll a list beneath it, and never eats a tap.
- Master switch off or Reduce Transparency on: the plates disappear and Spotify's chrome is byte-for-byte untouched.

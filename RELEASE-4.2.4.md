# Shrubify 4.2.4 — one owner per bar, and glass where the player actually is

4.2.3 put material on the tab bar and stopped the lyrics false-miss, but the
bottom bar still looked like a plastic imitation of Liquid Glass, and the player
— the screen people actually look at — had no glass at all. Both had the same
root cause: the glass was being drawn by whichever owner happened to run first,
and the player's owner never ran on iPad at all.

## Why the tab bar looked fake

Three different systems could each draw a capsule on the same bar:

- the native iPad glass layer (`NativeTabletGlass`), on the bar's own layout;
- the window-pass chrome (`ShrubifyGlassChrome`), anchored on the tab items; and
- the iPhone mini-bar capsule (`MiniBarGlass`), which also matched the iPad bar.

They only checked their own host before mounting, so two capsules could land on
one bar with different sizes, two rims and two sheens — and the material itself
added a full-height white gradient on top. Frosted glass plus a white wash plus
a second rim is exactly the grey slab in the screenshots.

Now:

- **The native layer is the only owner of the tab bar and mini-player.** The
  window pass checks whether the native plate is alive before mounting, removes
  its own fallback plate the moment the native one appears, and deliberately
  does **not** hand back the opaque backing it cleared in that case (doing so
  would paint over the native glass). The iPhone mini-bar capsule no longer runs
  on iPad; its round artwork still does.
- **The material is glass again.** The specular band is now a narrow highlight
  at the top edge, capped regardless of how dark Spotify's chrome is, and the
  neutral tint has a hard ceiling. Plates show the page underneath instead of a
  pale fill.

## Glass in the player

The iPad build skips the custom-interface hooks, so the player's transport-row
hook was never activated and the window scan never found the player either: a
depth-first walk spent its whole node budget inside the Home feed before
reaching the modal player, which is a sibling, not a descendant.

- The scan is now **breadth-first**, so the player page is reached early.
- The player has its **own hook** on the transport row, activated on iPad with a
  class probe, so glass appears even when the tree is deeper than the scan.
- One rounded **glass card** sits behind the player's control block (title,
  progress bar, time, transport row, tool row).
- A decorative **circle behind every key**: shuffle, previous, play, next,
  repeat, share, queue, lyrics, plus the top-left and top-right keys. Every
  plate is inserted *behind* the control, so glyphs are never blurred and no hit
  region changes; nested controls are skipped so one key cannot get two rims.

## Also in this release

- Studio's **Glass status** now reports the player and how many keys carry
  glass, and says "native glass" for the two bars instead of claiming them.
- Turning Liquid Glass off still restores Spotify's own backgrounds, materials
  and gradients byte for byte; the fallback simply skips its undo when the
  native owner has taken the bar over.
- Lyrics behaviour is unchanged from 4.2.3: the free-source safety net and the
  LRCLIB title variants remain.

## Known limits

The plate placement is derived from Spotify's live view tree, so a future
Spotify redesign can move a surface; **Glass status** is the readout for that.
The result has been validated by compilation and the repository's checks, not on
a physical iPad — the card's inset and each circle's offset are intentionally
small so that an unexpected host still looks reasonable.

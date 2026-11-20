# Shrubify 4.2.3 — glass on the player, lyrics that actually arrive

4.2.2 proved the material could survive Spotify's chrome: the tab bar turned
into real glass. Everything else stayed flat. This release closes both halves of
that gap — the player and the buttons — and fixes the lyrics lookup that was
reporting "no lyrics found" for songs every provider has.

## The player and its buttons now carry glass

Three separate reasons kept them flat:

1. **The transport row required one shared superview.** The iPad player wraps
   each key in its own container, so the pass looked for three buttons under a
   single parent, found none, and gave up. It now takes their **common
   ancestor**: wrapped keys still form one row, and the tightest matching host
   wins so the plate can never stretch across the page.
2. **The mini-player was recognised by one identifier.** It now tries three
   identities in order — Spotify's bar identifier, any bar-shaped view named
   `NowPlayingBar` / `MiniPlayer` / `MiniBar`, and finally the compact bar
   wrapped around the play key. Page-sized views are excluded by height, so the
   fallback cannot land on the wrong container.
3. **The keys themselves had no material.** Each of the previous, play and next
   keys now gets its own glass circle. It is inserted *behind* the button, so
   the circle is a visible glass ring and the glyph is never blurred; the plate
   is non-interactive, hidden from accessibility, and never resizes, re-parents
   or re-styles anything Spotify owns.

Studio → Liquid Glass → **Glass status** now ends with
`Player buttons: N of 3 glass`, so a build that exposes fewer than three keys
says so instead of leaving you guessing.

## Lyrics: a failed source is no longer a dead end

The single-source path (which is what the native player style uses) tried the
chosen provider and then stopped unless the Genius fallback switch was on. One
expired token, one endpoint that changed shape, and a popular song reported
"no lyrics found".

- Every failure now goes through a **safety net**: LRCLIB first — no token, no
  account, no region, and it returns time-synced lyrics — then Genius when its
  own switch is on. The provider line always names the source that actually
  answered. The Apple Music official-TTML experiment still asks nothing else,
  because that is its literal meaning.
- The default auto-select order starts with **LRCLIB**. The chain has a fixed
  time budget, and the key-gated providers used to spend all of it before
  LRCLIB (ninth) was ever asked. Word-level sources are still consulted inside
  the upgrade window, so nothing is lost on the quality side.
- LRCLIB lookups now try the title, the suffix-stripped title and the
  bracketed-base title, then fall back to a **scored search** gated on title and
  duration (an artist match only breaks ties). A title like
  `Song (feat. X)` or `Song - Remastered 2011` no longer hides a match that
  exists.
- The Musixmatch path no longer force-unwraps the last subtitle: an empty
  subtitle list used to crash the lookup, and now it is simply "this entry has
  no lyrics", which lets the safety net continue.

## Still true

Plate mounting is bounded (fixed depth, node cap, one scan per half second),
idempotent, and restores Spotify's own backing byte for byte when the switch is
turned off. Reduce Transparency still swaps in an opaque fill and Increase
Contrast still strengthens the rim.

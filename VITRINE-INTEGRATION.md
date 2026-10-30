# Shrubify × Vitrine — integration notes

This targeted patch does **not** merge Vitrine's full standalone redesign, which uses a separate
set of Spotify-specific hooks and injection-time app changes. Running those alongside Shrubify's
existing tab bar and player hooks could cause crashes and layout conflicts.

## Included

- Adapted Vitrine `SGGlassEffect` material initialization and `SGShapeGlass` corner configuration
  (GPL-3.0, original source: https://github.com/My-Name-Is-Jeff/vitrine).
- Optional **Vitrine material** switch in Settings → Liquid Glass, iOS 26+ only; requires restart.
- Uses the material and shape on Shrubify-created panes, player lyrics surfaces, search fields,
  in-page search, now-playing bar, tab editor, and transition fallback.
- Keeps existing Spotify colors, customizations, and pre-existing Liquid Glass mode. Default OFF.
- Crash guards: do not force iOS 26 player flags on older OS versions; cap transition scans;
  guard tab-editor touches and narrow tab widths.
- Uses a solid surface when Reduce Transparency is enabled and keeps glass panes behind the
  control hierarchy without negative z-order, following Vitrine's updated ghosting fix.
- Existing Codable options remain compatible: `vitrineMaterial` is optional, so previously saved
  settings won't reset when this patch is installed.

## Not included / limitations

- No complete Vitrine UI rewrite, injection pipeline, Spotify flags, Live Activity or
  Vitrine-only settings menu. Vitrine's upstream code reports testing specifically on Spotify
  9.1.78, 9.1.88 and 9.1.90; compatibility outside those versions needs device testing.
- iOS SDK compiler and live device testing are required for final compatibility confidence.
- No existing IPAs, workflows, source-feed JSON, or website layout are replaced.

## Licensing

Vitrine derives from spoti.pw and is GPL-3.0 licensed, as is Shrubify's project source.
The adapted implementation is tracked in `VitrineGlass.m` and the repository GPL-3.0 `LICENSE` applies.
Retain the upstream notices and corresponding source when distributing a build.

## 3.0.5 refinement

Removed the extra chrome overlay and hand-drawn tab bar, mini-player and artwork borders added in 3.0.4. The system material now supplies its own edge treatment, following Vitrine’s material and shaping approach. The full Vitrine redesign remains outside this adapter. Device appearance has not yet been verified.

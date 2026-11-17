# Evolved player, UI and lyrics port

Imported from [zbzxbg/EeveeSpotifyEvolved](https://github.com/zbzxbg/EeveeSpotifyEvolved)
revision `92d783486d527c20ccffb759de523d6c7b956547` under GPL-3.0.
Original Shrubify base: `8a62e42734038aa6aa0d6281a9c25fcb77d14e36`.

## User-facing changes

The previous Liquid Glass renderer, Taurus material preset and Vitrine material
adapter are removed. **Evolved UI** is now the appearance entry in Shrubify settings.
The imported implementation includes:

- Evolved's Apple Music-style player: large cover with a fading artwork backdrop,
  repositioned title and transport controls, volume/footer controls, and in-player lyrics.
- Evolved's glass tab bar and mini-player, including label/create-button controls.
- Home headers and shortcut tiles, library/search styling and rows.
- Album, playlist and artist headers, artwork backgrounds, single playlist covers,
  artist biography sheet and release navigation.
- Evolved's full-screen and in-player lyrics renderers, word timing, interludes,
  romanization, translation, typography previews, per-source offsets and source ordering.

The first launch selects the Apple Music player and Evolved page/glass settings.
Spotify's player style remains selectable under **Evolved UI → Player design**.
Studio opens the new player/page/lyrics controls. Old Studio layout archives remain
stored but are not applied to the new renderer. Shrubify's branding, settings shell,
Replay (still opt-in), ShrubPanel, ShrubQueue and diagnostics remain available.
The earlier sleep timer and Replay summaries remain included.

## Lyrics sources

The complete imported provider layer supports **Spicy Lyrics, AMLL, PetitLyrics,
NetEase, QQ Music, KuGou, Unison, Musixmatch, BiniLyrics, LRCLIB, Genius**, plus
experimental **Apple Music official TTML** through the Experiments page.

Auto Select tries the configured source order and prefers richer timing and requested
translation/romanization. Each provider retains its parser, matching rules and credits.
Genius is plain text; LRCLIB is line-timed. Real word timing depends on the provider
and the particular track. Spicy Lyrics requires the user's client key. Apple Music
requires the user's own media-user-token and eligible account. These credentials
are not bundled or fabricated. Provider availability and catalogs are external.

The first six stored source values retain their meanings, including Spicy Lyrics at
raw value 5. Existing provider selection, client key, Musixmatch token and accent
color are retained. Deprecated material choices are no longer read. Existing lyrics
transport delegates still buffer by task identity and deliver provider results
asynchronously, using a serial worker for the imported provider state.

## Platforms

**Minimum iOS: 17.4. System glass effects: iOS 26+.** The deployment floor is raised
because the imported lyrics layer links Apple's Translation framework. The tweak
package and branded IPA both declare the floor; an input IPA with a higher minimum
keeps that higher requirement. Branded IPAs remove the old design-compatibility plist
key, as Evolved's glass implementation expects. A jailbreak package cannot itself
rebuild Spotify's Info.plist; check its system-design behavior on the device.

The upstream baseline is Spotify **9.2.0 / 9.1.88**. This port includes its private UI
identifiers and per-class hook guards, but has **not** been device-tested on those
versions. Stability Mode skips the Evolved interface activation. Private Spotify
classes can change; a successful compile does not establish visual compatibility.

## Licensing

See [full upstream credits](EVOLVED-UPSTREAM-CREDITS.md), the in-app **Open-source
licenses** page and the existing [GPL license](../LICENSE). Notices for Evolved,
whoeevee, SideloadLabs, spoti.pw's GPL version, kumone, and provider/parser contributors
are preserved. Evolved documents Taurus as conceptual inspiration with no Taurus
source copied; those provenance notices remain. There is no Taurus material preset
or Vitrine adapter in the active build.

No upstream screenshot, logo, audio or album artwork is bundled. Lyrics preview
sample text is original. Artwork displayed by the UI comes from the playing track.

## Validation

- Python integration guards check removal of the retired renderer/material adapter,
  provider registration, asynchronous delegates and the deployment floor.
- `bash scripts/test_evolved_lyrics.sh` runs twelve imported upstream suites for
  matching, Spicy JSON/attribution, QQ QRC decoding, KuGou romanization, AMLL/Apple
  TTML, line splitting, interludes, wrapping, lyrics-door state and missing-lyrics notices.
- `bash scripts/test_evolved_migration.sh` checks preservation of provider selections, credentials, accent colors, legacy layout archives and Replay opt-in, plus migration idempotence.
- Existing settings, playback bridge, request-buffer and sleep timer tests remain in native CI.
- The native workflow parses every Swift source and builds a rootless tweak on macOS.

Before release, test cold launch, player opening/dismissal, all transport/footer
buttons, track changes, rotation and iPad layout. Check home/library/album/artist/
playlist navigation, light/dark appearance and iOS 26 glass. Check each provider with
matching/missing/instrumental songs and required credentials, source switching,
source order, timing offsets, translation and romanization. Verify long text, RTL,
VoiceOver, Reduce Motion and Reduce Transparency. Check Stability Mode, Replay opt-in,
queue navigation and timer expiry/cancellation. No device screenshots or playback
verification from this port are available yet.

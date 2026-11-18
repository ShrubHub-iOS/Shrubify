> Archived release document. Current release: [Shrubify 4.1.7](RELEASE-4.1.7.md).

# Shrubify 4.1.0

The Evolved UI and expanded lyrics release.

- Apple Music-style player with fading artwork, transport/footer controls and in-player lyrics.
- Evolved glass tabs and mini-player, home/library styling, and album/playlist/artist page designs.
- Twelve lyrics providers: Spicy Lyrics, AMLL, PetitLyrics, NetEase, QQ Music, KuGou, Unison, Musixmatch, BiniLyrics, LRCLIB and Genius, plus experimental Apple Music official TTML. Required client keys/account tokens must be supplied by the user.
- Auto Select/source ordering, real word timing where provided, romanization, translation, typography and timing controls.
- Shrubify Studio opens the new controls. Replay remains opt-in; ShrubPanel, ShrubQueue and the sleep timer remain available. Old Studio layouts are retained but no longer applied.
- Reviewed fixes for settings/popup presentation, player capture, activation/disable controls, provider timeout/cancellation, stale-track results, cache identity and log redaction.
- App version labels, package metadata, release automation and current documentation use 4.1.0.

Requires iOS 17.4+. System glass effects require iOS 26+. Upstream UI baseline is Spotify 9.2.0 / 9.1.88; this port has not been device-tested. A passing native build is not a guarantee of playback, layout, installation or live provider compatibility. See [TESTING.md](TESTING.md) and [integration details](docs/EVOLVED-INTEGRATION.md).

The IPA is unsigned and requires your own compatible signing setup. Spotify's app version remains separate from the Shrubify tweak version. Upstream credits and GPL source/license notices are preserved.

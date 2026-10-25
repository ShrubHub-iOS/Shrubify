# Shrubify — Common Issues

**Maintained by shrubbery and the ShrubHub team.** This guide applies to Shrubify 3.x. The project is unofficial, based on upstream GPL-licensed work, and is not affiliated with Spotify.

## Where are the Shrubify settings?

Open Spotify's account/profile menu and select the Shrubify settings entry. The current release includes Studio, Replay, ShrubPanel, queue shortcuts, themes, diagnostics, and compatibility settings. Some options only work with certain Spotify/iOS versions.

## Why am I still seeing "Eevee" or version 2.0.0?

Those labels belong to older builds. Shrubify 3.0.3 changes the badge and plan labels and generates the displayed tweak version from its `control` file during compilation. You must install an IPA **built after** the update, not reuse an older IPA from Downloads or a previous Actions artifact. The Spotify version beside it is separate from the Shrubify version.

## App won't install

The IPA must be properly signed using a certificate and provisioning profile compatible with `com.shrubify.client`. The GitHub Actions IPA is unsigned. An installation popup alone does not identify whether the cause is signing, entitlements, packaging or an expired/revoked certificate.

## Crashes, missing options or broken layout

Try Stability Mode and disable experimental or version-specific player options before restarting. Confirm the exact Spotify version, Shrubify version, iOS/iPadOS version, installation type and reproduction steps. For bugs, attach the available diagnostics/debug log and use the [Shrubify issue form](https://github.com/zoinkdoggie94/Shrubify/issues/new/choose). No release can guarantee compatibility with every Spotify update.

## Shrubify Replay isn't showing old plays

Replay records estimated listening time and history **only after you enable it**. Its observations are local to this app installation and don't import your Spotify listening history. They are not a substitute for Spotify's server-side statistics.

## Where are my updates and AltStore source?

[Releases](https://github.com/zoinkdoggie94/Shrubify/releases) and the generated `docs/repo.json` reflect eligible published builds; private Actions artifacts do not populate the public AltStore source. Only redistribute IPAs when authorized to do so.

## Spotify Connect, downloads and account limits

Features controlled by Spotify's servers still depend on your account and playback device. Shrubify's local UI changes cannot guarantee availability of every streaming, download, lyrics, or Connect feature.

## Original upstream attribution

The source includes [LICENSE](LICENSE), [README-UPSTREAM.md](README-UPSTREAM.md), and [contributors.json](contributors.json) for original authors and licensing obligations. Technical internal names such as `EeveeSpotify.dylib` remain where binary compatibility requires them.

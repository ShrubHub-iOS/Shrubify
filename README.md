# Shrubify

**Built by shrubbery and the ShrubHub team.**

Shrubify is an independent open-source fork with its own interface, logo, credits, compatibility diagnostics and automated IPA packaging workflow. It is **unofficial** and is not affiliated with Spotify. Spotify and its trademarks belong to their respective owners.

## What makes this build Shrubify

- Original Shrubify icon and in-app identity with the supplied leaf/music artwork.
- Clean settings layout retaining Spotify's dark/light appearance and user-selected accent instead of forcing ShrubHub colors.
- Developers & credits page led by shrubbery, with a link to [the developer's GitHub profile](https://github.com/zoinkdoggie94) and upstream creators credited separately.
- Compatibility & diagnostics screen with optional *Stability Mode* that skips experimental hook groups after restart.
- Self-hosted releases, log and attribution branding, and release automation maintained in this fork.

## Build / install

See [SHRUBIFY-SETUP.md](SHRUBIFY-SETUP.md). The compiled dylib and bundle retain their historic **internal** names because the hook loader and injection scripts depend on them; users see **Shrubify**. Building requires macOS/Theos; GitHub Actions provides macOS runners. An IPA must be supplied by someone authorized to use it. IPA output must be signed using a compatible signing profile before installation.

## Crash troubleshooting

Open **Shrubify → Shrubify diagnostics → Stability Mode**, enable it and restart. This disables multiple experimental components while leaving core settings accessible. Export debug logs from **Shrubify → Troubleshooting** and include the Spotify/iOS versions in a bug report. Stability Mode cannot fix all crashes, including loading and signing failures.

## Credits and license

Shrubify is maintained by **shrubbery and the ShrubHub team**. It is based on an existing GPL-3.0-licensed project with substantial upstream work by **whoeevee**, **jaydenjcpy**, **estrogencat** and [additional contributors](contributors.json). This fork does not claim exclusive authorship of that existing code. The original credit history is retained in [README-UPSTREAM.md](README-UPSTREAM.md) and the [GPL-3.0 LICENSE](LICENSE).

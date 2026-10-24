# Shrubify — full fork + release automation

This fork is built from the EeveeSpotify Reincarnated source in the ZIP you provided. It keeps the original implementation filenames (`EeveeSpotify.dylib`, `EeveeSpotify.bundle`) because the hook and injection system expects them. The tweak package is `com.shrubify.spotify`; the version in `control` and `Sources/EeveeSpotify/Tweak.x.swift` is `1.0.0`.

## What changed

- **Shrubify** name in its settings header, app display name, and output IPA bundle ID (`com.shrubify.client`). The source IPA stays `com.spotify.client`.
- Polished, more spacious settings rows; neutral black/white header without forcing ShrubHub colors.
- Real iOS 26 SwiftUI glass for the settings hero (`.glassEffect`); earlier supported iOS versions material fallback.
- The upstream's iOS 26 Liquid Glass Spotify surfaces (tab bar, now-playing, search, playlists, and lyrics) are **retained**; a shortcut is added in Shrubify settings. These effects are optional/off by default until enabled in the settings, as they were upstream.
- Fork's GitHub Releases link instead of comparing its tweak version against an unrelated upstream release.
- Build and source-creation automation, plus a small clean monochrome icon in `docs/icon.png` for the AltStore source.
- All upstream attributions and GPL-3.0 source files remain available.

## Upload this ZIP into Codespaces and replace the repository contents

1. Make/open your **Shrubify** GitHub repo in Codespaces. The repo should have a `main` or `Master` branch.
2. Use the Codespaces file explorer to upload `Shrubify-v2-full.zip` into your repo's **top-level folder** (beside `Makefile`).
3. Open the Codespaces terminal **in that same repo folder** and paste the commands below.

```bash
unzip -oq Shrubify-v2-full.zip -d /tmp/shrubify-update
rsync -a --delete --exclude='.git/' --exclude='Shrubify-v2-full.zip' /tmp/shrubify-update/Shrubify/ ./
rm -f Shrubify-v2-full.zip
python3 -m json.tool config/ipa-sources.json >/dev/null
python3 -m json.tool docs/repo.json >/dev/null
git add -A
git commit -m "Create Shrubify with Liquid Glass and automated releases"
git push
```

**Caution:** `rsync --delete` intentionally replaces the entire fork with the ZIP's contents (preserving `.git`). Commit or back up work first if you have other unpublished customizations.

## GitHub settings — required

In your Shrubify repo:

- **Settings → Actions → General → Workflow permissions:** choose **Read and write permissions** (needed to publish Releases, commit `docs/repo.json`, and optionally file update issues).
- **Settings → Secrets and variables → Actions → Variables:** add `ALLOW_PUBLIC_IPA_RELEASE` with value `true` **only if you have permission to redistribute the Spotify IPA**. Without this variable, you can still run a *manual* build and get its IPA as a private Actions artifact, but scheduled public releases are disabled.
- Set **Settings → Actions → General** to allow required third-party actions if your repo's policies restrict them.
- Source IPAs must be directly downloadable over HTTPS, must contain a `Payload/Spotify.app/Info.plist`, must have bundle ID `com.spotify.client`, and must already be decrypted. The automation does **not** download or decrypt Spotify from the App Store.

Choose ONE way to give the automation authorized IPA files:

**Option A: static mapping in the repo** (simple). Edit `config/ipa-sources.json`:

```json
{
  "versions": {
    "9.1.10": "https://YOUR-OWN-SERVER.example/Spotify-9.1.10.ipa",
    "9.1.11": "https://YOUR-OWN-SERVER.example/Spotify-9.1.11.ipa"
  }
}
```

The URLs above are *examples only*. Replace them with **your actual legally distributable direct-download URLs**. Commit the file. The next Actions run automatically selects the entry matching Spotify's official US App Store version.

**Option B: updated private catalog** (better for hands-free operation): Add an Actions **Secret** named `SPOTIFY_IPA_CATALOG_URL`, containing an HTTPS endpoint that returns the same JSON format as option A. If your provider populates this JSON whenever you obtain a new authorized version, Shrubify builds/releases the update with no repo edit needed.

**Option C: one latest URL** (less reliable): Add a secret `SPOTIFY_IPA_URL`. You must update the value whenever the download changes. The workflow checks the actual IPA version; it will **refuse** to label an old IPA as a new Spotify update.

If a new Spotify version is detected without a matching source, the workflow writes a summary and can create one tracking Issue (if Issues are enabled). It will not pretend to publish the update.

## How to build once right now

1. Go to **Actions → Shrubify - Watch, Build, Release and Update Source → Run workflow**.
2. Paste an authorized **HTTPS direct download URL** for your already-decrypted Spotify IPA into `ipa_url`. A local iPad file must first be stored at a URL the GitHub macOS runner can reach; the GitHub runner cannot access your iPad's Files app.
3. Leave `force_release` unchecked unless rebuilding an existing exact source revision.
4. Run. It builds the framework and tweak from **your** code, injects into that IPA, updates the IPA's app display name, bundle ID (`com.shrubify.client`), and numeric build number, and uploads a build artifact.
5. If `ALLOW_PUBLIC_IPA_RELEASE=true`, it also publishes the IPA and `.deb` in **GitHub Releases**, then regenerates `docs/repo.json` from actual GitHub Release assets.
6. The IPA is not pre-signed. Sign it using your own authorized certificate, keeping the custom bundle ID. Changing the bundle ID can affect Spotify sign-in, Keychain, app extensions and other features. The workflow does not claim these have been device-tested.

**No false guarantees:** the workflow validates ZIP structure, matching Spotify bundle/version, and that the tweak binary is in the output. It cannot detect every API/UI change inside Spotify, so a successful Actions build is **not** proof that the new Spotify version behaves correctly. Test it before treating it as a stable public release.

## Automatic Spotify-update cycle

- Triggered at **07:23 and 19:23 UTC** daily (GitHub schedules can be delayed), when relevant source code changes are pushed, or manually.
- Reads Spotify's **official iTunes Lookup** App Store version and matches it with your IPA catalog.
- Compares IPA's **actual** Info.plist version with the App Store version on automatic jobs.
- Skips an already-published same source commit+Spotify version.
- Builds Shrubify + the IPA on a macOS GitHub runner, uploads an Actions artifact, optionally publishes a public Release, and updates the AltStore source.
- Tweaks-only code changes also create a new Release and increment the IPA build number for AltStore updates, provided a matching IPA is available.

## Your AltStore source link

After first authorized public release, use:

`https://raw.githubusercontent.com/<YOUR-GITHUB-USERNAME>/Shrubify/<YOUR-DEFAULT-BRANCH>/docs/repo.json`

For example, if your repo is `zoinkdoggie94/Shrubify` and the default branch is `main`:

`https://raw.githubusercontent.com/zoinkdoggie94/Shrubify/main/docs/repo.json`

The repo initially has `apps: []` because no releases actually exist yet. **No fake IPA URL, release, or version is inserted.** After publishing, `scripts/generate_source.py` reads GitHub Releases, copies real asset download links and real IPA byte sizes, and places the newest release first. GitHub Actions commits the updated JSON to `docs/repo.json`.

Optional: enable **Settings → Pages → Deploy from a branch → default branch /docs** to get `https://<username>.github.io/Shrubify/repo.json`. Pages is not required; the raw link works for AltStore-compatible source readers when reachable.

## License / attribution

Upstream: EeveeSpotify Reincarnated (source retained in this archive). Original contributors must remain credited under the GPL-3.0 license in `LICENSE`. This fork is unofficial and not affiliated with Spotify. A license to modify the GPL tweak does **not** grant rights to redistribute Spotify's proprietary app IPA; public publishing is therefore opt-in.

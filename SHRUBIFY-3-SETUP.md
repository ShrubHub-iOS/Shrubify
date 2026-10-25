# Shrubify 3.0 — Codespaces upgrade

## Replace source with this ZIP in Codespaces

1. Commit or back up **your own** existing edits before overwriting the working tree.
2. Upload `Shrubify-3.0-FULL.zip` in `/workspaces/Shrubify`.
3. Run the commands below. `rsync` updates files from the ZIP but preserves `.git` and your existing generated `docs/repo.json`.

```bash
cd /workspaces/Shrubify
# Start from the latest remote branch before copying the update.
# Stop if this reports a conflict; do not force-push.
git pull --ff-only origin Master
unzip -oq Shrubify-3.0-FULL.zip -d /tmp/shrubify3
# Keep Git history and the repo.json your release workflow already generated.
rsync -a --exclude='.git/' --exclude='docs/repo.json' /tmp/shrubify3/Shrubify-Master/ ./
rm -f Shrubify-3.0-FULL.zip
bash -n scripts/build_shrubify.sh
python3 -m py_compile scripts/*.py

# Stage tracked source/document changes plus the NEW 3.0 files.
# Avoid accidentally committing older ZIP uploads, IPA files or log archives.
git add -u
git add Sources/EeveeSpotify/Shrubify3 scripts/tests CHANGELOG.md TESTING.md SHRUBIFY-3-SETUP.md
git commit -m "Shrubify 3.0 major update [skip ci]"
git push origin HEAD:Master
```

If rebase reports conflicts, **stop and resolve them**, particularly `docs/repo.json` or workflow edits; do not force push. Run the GitHub build action manually from the `Master` branch.

## GitHub Actions settings

- Set Actions **Workflow permissions** to `Read and write` for release/source update workflows.
- `SPOTIFY_IPA_URL` secret is an optional direct HTTPS URL to your own authorized compatible IPA. Updating a secret does **not** start a workflow; press *Run workflow* to start one.
- For scheduled version checks, supply a matching IPA catalog or update `config/ipa-sources.json` as documented in `SHRUBIFY-SETUP.md`.
- `ALLOW_PUBLIC_IPA_RELEASE=true` is a **repository variable** (not a secret); it enables public IPA release publishing only where you have redistribution permission. With it off, a successful build produces a private Actions artifact but will not add an app to `repo.json`.
- A new Spotify version may require compatibility fixes; detecting a version is not proof that its IPA will build or run.

## Using the new features

In Spotify's settings, open the **Shrubify 3.0 · Listening is easy** section. Studio's changes that affect hook activation need an app restart. Replay is opt-in and stores records on-device. In ShrubQueue, **listening snapshots aren't the real Spotify queue**; they preserve a selection of your recorded listening history. The mini-player long-press panel relies on the supported player observer and may not show up with Stability Mode or incompatible Spotify versions.

See [TESTING.md](TESTING.md) to validate your actual device before publishing any claims about crash-free behavior.


## Compiler failures

The build workflow now writes compiler errors directly into its GitHub Actions
**Summary** and uploads a small `Shrubify-Compiler-Errors-<run>` text artifact.
You do not need to copy thousands of Swift warnings. This only runs when the
real build command fails; a green syntax preflight is not proof of compilation.

The 3.0.1 source reliability pass simplifies SwiftUI view builders and makes
Replay start its timer only when listening history is enabled. Actual iOS/macOS
compilation and device compatibility must still be tested.


## Shrubify 3.0.2: build performance and availability checks

This maintenance update replaces SwiftUI modifiers rejected by the iOS 14 deployment target. The build workflow now checks common source errors before downloading your IPA or installing dependencies. The expensive SwiftProtobuf framework is cached by macOS architecture, selected Xcode version, protobuf version and dependency-build script contents. **The first run builds that framework normally**; subsequent runs reuse it when the cache key matches. If the tweak compilation fails, the framework cache still survives. GitHub's caches can expire and runners may change, so rebuild time is not guaranteed.

You can check the compatibility guard in Codespaces without starting a macOS IPA build:

```bash
python3 scripts/check_ios14_swiftui.py
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

The checker covers known Shrubify 3.0 modifier mistakes, not every possible SwiftUI API availability issue; the actual macOS iOS SDK compilation remains the authoritative check.

## Shrubify 3.0.3 build-speed notes

The first 3.0.3 build will compile the modified tweak and create a reusable compiled-package cache. The next build with identical tweak sources can skip that native compilation and only inject/brand/validate the new Spotify IPA. Inspect the GitHub Actions step **Restore matching compiled tweak package and injector** to see the cache hit or miss. A source change or cache expiration requires a full compile. The workflow retains source checks and IPA validation; it does not skip safety-critical package checks or signing requirements.

The on-screen tweak version is generated from the `Version:` field of `control`, not hardcoded in Swift. That is independent of the Spotify version displayed beside it. The cached compiled package is accepted only if its Debian package identity and version match the current source.

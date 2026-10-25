# Shrubify v2.0.0 — full update

This ZIP contains the full source fork. The update uses the user-supplied Shrubify logo, not an AI-generated replacement. It does NOT contain any Spotify IPA.

## Replace the files from Codespaces (Master branch)

1. Upload `Shrubify-v2.0.0-FULL.zip` to the repository root of Codespaces.
2. Commit/back up your own unsaved changes before replacing files.
3. Run:

```bash
cd /workspaces/Shrubify
unzip -oq Shrubify-v2.0.0-FULL.zip -d /tmp/shrubify-v2
rsync -a --exclude='.git/' --exclude='*.ipa' /tmp/shrubify-v2/Shrubify-Master/ ./
rm -f Shrubify-v2.0.0-FULL.zip
git add -A
git status --short
git commit -m "Shrubify 2.0: original branding, credits and stability improvements [skip ci]"
git push origin HEAD:Master
```

**Note:** The commands overwrite same-named files, not deleted files, so remove outdated files manually if you previously created custom overrides. In particular, old IPA builds must be rebuilt; this ZIP does not update a previously signed IPA.

4. From GitHub Actions, manually run **Shrubify - Watch, Build, Release and Update Source** once, supplying your direct IPA URL if necessary. You may also choose the next build trigger as configured in the workflows.
5. Use the successful Actions artifact to sign/install. The signing profile must support `com.shrubify.client`.
6. Check the launcher icon and Settings → Developers & credits and Settings → Shrubify diagnostics.

## What's changed

- Default launcher icon now points to `Shrubify` PNG variants injected into the app; alternate icon chooser still works and legacy Eevee-named variants no longer display.
- In-app masthead uses the supplied leaf/music icon.
- `shrubbery` has a featured, linked GitHub avatar in credits; ShrubHub team is displayed beneath.
- Maintains an upstream contributor section and GPL credits, but legacy app-facing upstream branding is removed.
- Added Stability Mode (takes effect after restarting), preserving core integration while omitting optional experimental UI/lyrics and remote-flags hooks.
- Reworked avatar loading with a shared cache, size limit, and task cancellation; removed the old surprise launch window banner and a forced settings-controller unwrap.
- Release and AltStore descriptions now describe Shrubify, not a generic renamed fork; source code ancestry remains acknowledged in documentation.

## Testing limitations

We can validate Swift *parsing*, scripts, and IPA structure in a Linux environment; compiling the tweak requires the macOS toolchain. No test can guarantee zero crashes, especially across unsupported Spotify versions. If it still crashes, capture the device crash report and a Shrubify debug log and open an issue with exact Spotify/iOS versions.

## Attribution and distribution

The code is GPL-3.0 and derived from existing upstream authors. Keep the original LICENSE and README-UPSTREAM.md along with the source. Spotify's IPA is proprietary: do not publish it without redistribution rights.

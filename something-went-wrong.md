# Shrubify — Sign-in or "Something went wrong"

A login error alone does not prove a tweak malfunction. Authentication can be affected by Spotify account/server changes, network conditions, app signing, and whether your installed Spotify version is compatible with the tweak.

1. Check that Spotify is reachable on your network and verify whether your account works through an official supported Spotify client.
2. Confirm your Shrubify IPA is signed for its actual bundle ID (`com.shrubify.client`) with valid provisioning and entitlements.
3. If you updated Spotify or Shrubify, verify the supported version and enable Shrubify's Stability Mode if experimental hooks are involved.
4. Report the exact iPadOS version, Spotify build number, Shrubify version, signing method, and redacted debug logs through [Shrubify Issues](https://github.com/zoinkdoggie94/Shrubify/issues/new/choose).

Never post account credentials, session tokens, provisioning secrets or private signing keys in public logs. Shrubify is unofficial and cannot guarantee access when Spotify changes server-side authentication rules.

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

class EvolvedIntegrationTests(unittest.TestCase):
    def test_old_material_adapter_is_removed(self):
        self.assertFalse((ROOT / "Sources/EeveeSpotifyC/VitrineGlass.m").exists())
        self.assertFalse((ROOT / "Sources/EeveeSpotify/LiquidGlass").exists())
        header = (ROOT / "Sources/EeveeSpotifyC/include/Tweak.h").read_text()
        self.assertNotIn("VitrineGlass", header)

    def test_ipad_glass_hook_scope(self):
        # The UIKit fixture exercises the renderer, not Orion registration in
        # Spotify. Guard against installing a cell/base-class scroll hook again.
        appearance = ROOT / "Sources/EeveeSpotify/Appearance"
        hooks = (appearance / "NativeTabletGlass.x.swift").read_text()
        self.assertCountEqual(re.findall(r'ClassHook<([^>]+)>', hooks), ["UIView", "UIView"])
        self.assertCountEqual(re.findall(r'static let targetName = "([^"]+)"', hooks), [
            "NavigationUI_TabBarImpl.TabBarView",
            "_TtC22NowPlaying_BarPageImplP33_CCC0D2EEA6D4725EECD8965E8C38C86D20TouchPassthroughView",
        ])
        renderer = (appearance / "NativeTabletGlass.swift").read_text()
        for global_trigger in ["connectedScenes", "UIWindow", "eeveeKaraokeLyricsChanged", "asyncAfter"]:
            self.assertNotIn(global_trigger, renderer)

    def test_selective_native_glass(self):
        appearance = ROOT / "Sources/EeveeSpotify/Appearance"
        renderer = (appearance / "ShrubifyLiquidGlass.swift").read_text()
        chrome = (appearance / "ShrubifyGlassChrome.swift").read_text()
        self.assertIn("style == .clear ? .clear : .regular", renderer)
        self.assertNotIn("CAGradientLayer", renderer)
        self.assertNotIn("layer.borderWidth", renderer)
        self.assertNotIn("mountPlayerCard", chrome)
        self.assertNotIn("mountKeyPlate", chrome)
        self.assertNotIn("Timer.scheduledTimer", chrome)
        self.assertIn("NativeTabletGlass.reapply", chrome)
        self.assertNotIn("pass(in window", chrome)
        self.assertNotIn("window-scanning fallback", (appearance / "ShrubifyGlassChrome.x.swift").read_text())
        tablet = (appearance / "NativeTabletGlass.swift").read_text()
        self.assertIn("other.owner === owner", tablet)
        self.assertNotIn('shrubify.native.selection', tablet)
        self.assertNotIn('func updateSelection(', tablet)
        self.assertIn('state.clearColor(material.contentView)', tablet)
        self.assertIn('state.clearOpacity(root)', tablet)
        self.assertIn('container.insertSubview(plate, belowSubview: sibling)', tablet)
        self.assertIn('tabCount: tabCount', tablet)
        self.assertIn('!containsNativeContent(child)', tablet)
        hooks = (appearance / "ShrubifyGlassChrome.x.swift").read_text()
        self.assertNotIn('ClassHook<UIView>', hooks)
        self.assertNotIn('static let targetName = "UIWindow"', hooks)

    def test_every_selectable_source_has_a_repository(self):
        source = (ROOT / "Sources/EeveeSpotify/Lyrics/CustomLyrics.x.swift").read_text()
        for name in ["Netease", "AmllTtml", "AppleMusicOfficialTtml", "Bini", "Unison", "QQMusic", "KuGou"]:
            self.assertTrue((ROOT / f"Sources/EeveeSpotify/Lyrics/Repositories/{name}LyricsRepository.swift").exists(), name)
            self.assertIn(name + "LyricsRepository", source)

    def test_both_lyrics_transports_remain_asynchronous(self):
        for name in ["DataLoaderServiceHooks.x.swift", "HttpClientURLSessionHooks.x.swift"]:
            source = (ROOT / "Sources/EeveeSpotify" / name).read_text()
            for handler in ["complete", "response", "forwards"]:
                self.assertIn("SpotifySessionTransport." + handler, source)
            self.assertNotIn("URLSessionHelper", source)
            self.assertNotIn("semaphore.wait", source)

        shared = (ROOT / "Sources/EeveeSpotify/Shared/Helpers/SpotifySessionTransport.swift").read_text()
        self.assertIn("loadLyricsDataAsync", shared)
        self.assertNotIn("semaphore.wait", shared)

    def test_native_deployment_floor(self):
        self.assertIn("latest:17.4", (ROOT / "Makefile").read_text())
        self.assertIn("firmware (>= 17.4)", (ROOT / "control").read_text())

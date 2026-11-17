from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class EvolvedIntegrationTests(unittest.TestCase):
    def test_old_material_adapter_is_removed(self):
        self.assertFalse((ROOT / "Sources/EeveeSpotifyC/VitrineGlass.m").exists())
        self.assertFalse((ROOT / "Sources/EeveeSpotify/LiquidGlass").exists())
        header = (ROOT / "Sources/EeveeSpotifyC/include/Tweak.h").read_text()
        self.assertNotIn("VitrineGlass", header)

    def test_every_selectable_source_has_a_repository(self):
        source = (ROOT / "Sources/EeveeSpotify/Lyrics/CustomLyrics.x.swift").read_text()
        for name in ["Netease", "AmllTtml", "AppleMusicOfficialTtml", "Bini", "Unison", "QQMusic", "KuGou"]:
            self.assertTrue((ROOT / f"Sources/EeveeSpotify/Lyrics/Repositories/{name}LyricsRepository.swift").exists(), name)
            self.assertIn(name + "LyricsRepository", source)

    def test_both_lyrics_transports_remain_asynchronous(self):
        for name in ["DataLoaderServiceHooks.x.swift", "HttpClientURLSessionHooks.x.swift"]:
            source = (ROOT / "Sources/EeveeSpotify" / name).read_text()
            self.assertIn("loadLyricsDataAsync", source)
            self.assertNotIn("semaphore.wait", source)

    def test_native_deployment_floor(self):
        self.assertIn("latest:17.4", (ROOT / "Makefile").read_text())
        self.assertIn("firmware (>= 17.4)", (ROOT / "control").read_text())

"""Regression guards for the optional Vitrine glass-material integration."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


class VitrineIntegrationTests(unittest.TestCase):
    def test_optional_setting_keeps_old_codables_readable(self):
        options = source("Sources/EeveeSpotify/LiquidGlass/LiquidGlassOptions.swift")
        self.assertIn("var vitrineMaterial: Bool?", options)
        self.assertIn("static var liquidGlassOptions", options)

    def test_glass_adapter_is_compiled_by_existing_makefile(self):
        makefile = source("Makefile")
        self.assertIn("find Sources/EeveeSpotifyC -name '*.m'", makefile)
        self.assertTrue((ROOT / "Sources/EeveeSpotifyC/VitrineGlass.m").is_file())
        self.assertIn('#import "VitrineGlass.h"', source("Sources/EeveeSpotifyC/include/Tweak.h"))

    def test_no_vitrine_spotify_hooks_collide(self):
        adapter = source("Sources/EeveeSpotifyC/VitrineGlass.m")
        self.assertNotIn("%hook", adapter)
        self.assertNotIn("%ctor", adapter)
        self.assertIn("ShrubVitrineGlassEffect", adapter)
        self.assertIn("ShrubVitrineShapeGlass", adapter)

    def test_only_one_named_in_app_vitrine_credit(self):
        credits = source("Sources/EeveeSpotify/Settings/Shared/GitHub/Views/EeveeContributorsSheetView.swift")
        self.assertEqual(credits.count('username: "My-Name-Is-Jeff"'), 1)
        for account in ('zoinkdoggie94', 'HakureiMango', 'ShrubHub-iOS'):
            self.assertIn(f'username: "{account}"', credits)

    def test_site_not_replaced(self):
        html = source("index.html")
        for marker in ('id="developers"', 'id="year"', 'github.com/HakureiMango', 'github.com/ShrubHub-iOS'):
            self.assertIn(marker, html)


if __name__ == "__main__":
    unittest.main()

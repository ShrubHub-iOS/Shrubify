from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

class AdHookIsolationTests(unittest.TestCase):
    def test_each_optional_ad_surface_has_an_independent_activation_group(self):
        source = (ROOT / "Sources/EeveeSpotify/EeveeAdBlockerExtended.x.swift").read_text()
        hooks = re.findall(r"class (\w+): ClassHook<[^>]+> \{\s*typealias Group = (\w+)", source)
        self.assertGreaterEqual(len(hooks), 19)
        groups = [group for _, group in hooks]
        self.assertEqual(len(groups), len(set(groups)), "One absent Spotify class must not disable a sibling blocker")
        for hook, group in hooks:
            self.assertIn(f"({hook}.targetName,", source)
            self.assertEqual(source.count(f"{{ {group}().activate() }}"), 1, "Never activate one group through multiple targets")

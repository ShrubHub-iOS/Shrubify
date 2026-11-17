import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('release_consistency', ROOT / 'scripts/check_release_consistency.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)

class ReleaseConsistencyTests(unittest.TestCase):
    def test_current_version_surfaces_match(self):
        self.assertEqual(checker.check(ROOT), [])

    def test_stale_readme_and_hardcoded_app_version_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            fixture = Path(temp)
            files = ['control', 'README.md', 'SHRUBIFY-SETUP.md', 'TESTING.md', f'RELEASE-{(ROOT / "control").read_text().split("Version: ")[1].splitlines()[0]}.md',
                     '.github/workflows/shrubify-release.yml',
                     'Sources/EeveeSpotify/Settings/Views/EeveeSettingsView.swift',
                     'Sources/EeveeSpotify/Shrubify3/ShrubifyBetaView.swift']
            for name in files:
                target = fixture / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / name, target)
            (fixture / 'README.md').write_text('# Shrubify 4.0.0\n')
            (fixture / files[-1]).write_text('Text("Welcome to Shrubify 4.0")')
            issues = checker.check(fixture)
            self.assertTrue(any('README.md: heading' in issue for issue in issues))
            self.assertTrue(any('BetaView.swift' in issue for issue in issues))

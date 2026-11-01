import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('release_version', Path(__file__).resolve().parents[1] / 'release_version.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseVersionTests(unittest.TestCase):
    def test_stable_unchanged(self):
        self.assertEqual('3.0.6', module.github_version('3.0.6'))

    def test_beta_is_valid_git_tag_component(self):
        self.assertEqual('4.0.0-beta1', module.github_version('4.0.0~beta1'))

    def test_invalid_versions_rejected(self):
        for value in ('4.0.0~beta0', '4.0', '4.0.0/other', '4.0.0$(id)'):
            with self.assertRaises(ValueError):
                module.github_version(value)

import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('brand_ipa', Path(__file__).resolve().parents[1] / 'brand_ipa.py')
branding = importlib.util.module_from_spec(spec)
spec.loader.exec_module(branding)

class DeploymentFloorTests(unittest.TestCase):
    def test_raise_older_or_missing_minimum(self):
        for old in [None, '14.0', '17.3.1', '17.0']:
            self.assertEqual(branding.minimum_ios_version(old), '17.4')

    def test_preserve_higher_input_requirement(self):
        for current in ['17.4', '17.4.1', '18.0', '26.0']:
            self.assertEqual(branding.minimum_ios_version(current), current)

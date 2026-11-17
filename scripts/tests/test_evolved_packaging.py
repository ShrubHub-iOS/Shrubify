import importlib.util
import io
from pathlib import Path
import plistlib
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('inspect_ipa', Path(__file__).resolve().parents[1] / 'inspect_ipa.py')
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)

class EvolvedPackagingTests(unittest.TestCase):
    def fixture(self, minimum='17.4', compatibility=False):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('Payload/Shrubify.app/Info.plist', plistlib.dumps({
                'CFBundleExecutable': 'Spotify', 'CFBundleIdentifier': 'com.shrubify.client',
                'CFBundleVersion': '42', 'MinimumOSVersion': minimum,
                'UIDesignRequiresCompatibility': compatibility,
                'CFBundleIcons': {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['Shrubify']}},
                'CFBundleIcons~ipad': {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['Shrubify']}},
            }))
            for name in ['Spotify', 'Shrubify@2x.png', 'Frameworks/EeveeSpotify.dylib',
                         'EeveeSpotify.bundle/en.lproj/Localizable.strings']:
                archive.writestr('Payload/Shrubify.app/' + name, b'fixture')
        data.seek(0)
        return zipfile.ZipFile(data)

    def test_evolved_resources_need_no_legacy_shader(self):
        with self.fixture() as archive:
            self.assertEqual(packaging.preflight(archive)['executable'], 'Spotify')

    def test_reject_wrong_os_floor_or_old_design(self):
        for minimum, compatibility in [('17.3', False), ('17.4', True)]:
            with self.fixture(minimum, compatibility) as archive:
                with self.assertRaises(ValueError):
                    packaging.preflight(archive)

import importlib.util
import pathlib
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'generate_source.py'
spec = importlib.util.spec_from_file_location('shrubify_generate_source', SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AltStoreSourceTests(unittest.TestCase):
    def test_empty_has_no_phantom_app(self):
        source = module.source_for('zoinkdoggie94/Shrubify', [], 'Master')
        self.assertEqual([], source['apps'])

    def test_release_uses_real_asset(self):
        releases = [dict(tag_name='shrubify-s9.1.94-v3.0.0-g123abcd',
                         published_at='2026-10-24T22:00:00Z', draft=False,
                         body='altstore-build: 37', assets=[dict(name='Shrubify.ipa',
                                                                   browser_download_url='https://example.org/releases/Shrubify.ipa',
                                                                   size=1032)])]
        source = module.source_for('zoinkdoggie94/Shrubify', releases, 'Master')
        self.assertEqual('com.shrubify.client', source['apps'][0]['bundleIdentifier'])
        self.assertEqual('37', source['apps'][0]['versions'][0]['buildVersion'])
        self.assertEqual('https://example.org/releases/Shrubify.ipa', source['apps'][0]['versions'][0]['downloadURL'])
        self.assertIn('Replay', source['apps'][0]['localizedDescription'])

    def test_draft_and_no_asset_are_not_published(self):
        releases = [dict(tag_name='shrubify-s9.1.94-v3.0.0-g123abcd', published_at='', draft=True,
                         body='altstore-build: 37', assets=[])]
        self.assertEqual([], module.source_for('test/Shrubify', releases)['apps'])


if __name__ == '__main__':
    unittest.main()

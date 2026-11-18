"""Exercise the actual EXIT trap, never a real CoreSimulator installation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SimulatorOwnershipTests(unittest.TestCase):
    def test_clean_up_only_a_successfully_created_device(self):
        for failure in ('create', 'boot', None):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                scripts = root / 'scripts'
                scripts.mkdir()
                for name in ('test_lyrics_interactions.sh', 'make_lyrics_interaction_project.py'):
                    shutil.copy(ROOT / 'scripts' / name, scripts / name)
                xcrun = root / 'xcrun'
                xcrun.write_text('''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as log: print(json.dumps(args), file=log)
if args[1] == os.environ['FAIL_ON']: sys.exit(1)
if args[1:3] == ['list', 'runtimes']:
    print(json.dumps({'runtimes':[{'isAvailable': True, 'identifier': 'fixture-iOS-26-1'}]}))
elif args[1:3] == ['list', 'devicetypes']:
    print(json.dumps({'devicetypes':[{'name':'iPad Air 11-inch (M2)', 'identifier':'fixture-type'}]}))
elif args[1] == 'create': print('only-created-by-this-run')
''')
                xcrun.chmod(0o755)
                (root / 'xcodebuild').write_text('#!/bin/sh\nexit 0\n')
                (root / 'xcodebuild').chmod(0o755)
                calls = root / 'calls.jsonl'
                env = dict(os.environ, CALLS=str(calls), FAIL_ON=failure or '-', PATH=tmp + ':' + os.environ['PATH'])
                result = subprocess.run(['bash', scripts / 'test_lyrics_interactions.sh'], env=env, capture_output=True)
                self.assertEqual(result.returncode == 0, failure is None, result.stderr)
                commands = [json.loads(line) for line in calls.read_text().splitlines()]
                self.assertFalse(any(c[1:3] == ['list', 'devices'] for c in commands))
                cleanup = [c for c in commands if c[1] in ('shutdown', 'delete')]
                self.assertEqual(cleanup, [] if failure == 'create' else [
                    ['simctl', action, 'only-created-by-this-run'] for action in ('shutdown', 'delete')])

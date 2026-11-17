#!/usr/bin/env python3
"""Reject current release labels that drift away from the package version."""
from pathlib import Path
import re
import sys


def check(root):
    match = re.search(r'^Version:\s*(\S+)', (root / 'control').read_text(), re.M)
    if not match:
        return ['control has no package version']
    version = match.group(1)
    errors = []
    for name in ['README.md', 'SHRUBIFY-SETUP.md', 'TESTING.md', f'RELEASE-{version}.md']:
        path = root / name
        if not path.exists():
            errors.append(f'{name}: missing current release document')
            continue
        heading = re.search(r'^# (.+)', path.read_text(), re.M)
        if not heading or f'Shrubify {version}' not in heading.group(1):
            errors.append(f'{name}: heading must identify Shrubify {version}')
    if f'RELEASE-{version}.md' not in (root / 'README.md').read_text():
        errors.append('README.md: release link does not match control')
    for relative in [
        'Settings/Views/EeveeSettingsView.swift',
        'Shrubify3/ShrubifyBetaView.swift',
    ]:
        path = root / 'Sources/EeveeSpotify' / relative
        text = path.read_text()
        if 'EeveeSpotify.version' not in text or re.search(r'"(?:Welcome to )?Shrubify \d+\.\d+(?:\.\d+)?"', text):
            errors.append(f'{relative}: current version label must use EeveeSpotify.version')
    if 'RELEASE-${TWEAK_VERSION}.md' not in (root / '.github/workflows/shrubify-release.yml').read_text():
        errors.append('release workflow must select notes using the package version')
    return errors


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    errors = check(root)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        sys.exit(1)
    print('Current app, README, setup, testing and release-note versions match control.')

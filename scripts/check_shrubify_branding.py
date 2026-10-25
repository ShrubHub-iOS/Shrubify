#!/usr/bin/env python3
"""Cheap, non-compiling regression check for previously leaked UI branding.

These checks run before downloading a large Spotify IPA or installing Theos.
Internal compatibility names are intentionally not renamed.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
premium = (root / 'Sources/EeveeSpotify/Premium/DynamicPremium+PremiumPlanRow.swift').read_text()
tweak = (root / 'Sources/EeveeSpotify/Tweak.x.swift').read_text()
makefile = (root / 'Makefile').read_text()
control = (root / 'control').read_text()

version_match = re.search(r'^Version:\s*(\S+)\s*$', control, re.MULTILINE)
assert version_match, 'Missing package version in control'
assert not re.search(r'(?<![A-Za-z])"Eevee"', premium), 'Eevee label leaked into Premium UI'
assert premium.count('"Shrubify"') >= 4, 'Expected Shrubify name in Premium badge and plan views'
assert 'static let version = GeneratedConfig.tweakVersion' in tweak, 'Tweak version is not derived from control'
assert 'static let tweakVersion = ' in makefile, 'GeneratedConfig must expose the package version'
assert 'SHRUBIFY_VERSION' in makefile, 'Missing Makefile version generation'
assert version_match.group(1).startswith('3.'), 'Unexpected older package version'
print(f'Shrubify {version_match.group(1)} branding and version preflight passed')

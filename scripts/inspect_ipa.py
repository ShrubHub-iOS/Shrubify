#!/usr/bin/env python3
"""Inspect Spotify and Shrubify IPA identities and their install packaging."""
import argparse
import json
import plistlib
import re
import sys
import zipfile

APP_INFO = re.compile(r'^Payload/[^/]+\.app/Info\.plist$')


def info(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        match = [p for p in names if APP_INFO.fullmatch(p)]
        if len(match) != 1:
            raise ValueError('Expected one Payload/*.app/Info.plist')
        p = plistlib.loads(archive.read(match[0]))
        return {'version': str(p['CFBundleShortVersionString']),
                'build': str(p.get('CFBundleVersion', '1')),
                'bundle': str(p['CFBundleIdentifier'])}


def preflight(archive):
    files = archive.namelist()
    if len(files) != len(set(files)):
        raise ValueError('Duplicate IPA archive member detected')
    plists = [n for n in files if APP_INFO.fullmatch(n)]
    if len(plists) != 1:
        raise ValueError('Expected a single Payload/*.app/Info.plist')
    app_prefix = plists[0][:-len('Info.plist')]
    p = plistlib.loads(archive.read(plists[0]))
    exe = p.get('CFBundleExecutable')
    if not isinstance(exe, str) or not exe or '/' in exe or app_prefix + exe not in files:
        raise ValueError('Main executable missing from Payload app')
    if p.get('CFBundleIdentifier') != 'com.shrubify.client':
        raise ValueError('IPA is not branded to com.shrubify.client')
    if not str(p.get('CFBundleVersion', '')).isdigit():
        raise ValueError('CFBundleVersion must be numeric')
    forbidden = []
    for n in files:
        parts = n.split('/')
        if not n.startswith(app_prefix):
            forbidden.append(n)
        elif any(x in {'PlugIns', 'Extensions', 'Watch', 'WatchKit', 'WatchKitSupport', '_CodeSignature', 'SC_Info'} or x.endswith('.appex') for x in parts):
            forbidden.append(n)
        elif parts[-1] in ('embedded.mobileprovision',):
            forbidden.append(n)
    if forbidden:
        raise ValueError('Leftover unresignable extensions/signing files: ' + ', '.join(forbidden[:5]))
    if not any(n.endswith('/EeveeSpotify.dylib') for n in files):
        raise ValueError('EeveeSpotify.dylib not in IPA')
    bad = archive.testzip()
    if bad:
        raise ValueError('Corrupt IPA ZIP member: ' + bad)
    return {'app': app_prefix[:-1], 'executable': exe, 'files': len(files)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa')
    parser.add_argument('--expected', default='')
    parser.add_argument('--require-shrubify', action='store_true')
    parser.add_argument('--output', default='')
    args = parser.parse_args()
    data = info(args.ipa)
    if args.expected and data['version'] != args.expected:
        raise ValueError(f'IPA version {data["version"]} does not match expected {args.expected}')
    if args.require_shrubify:
        with zipfile.ZipFile(args.ipa) as z:
            data['preflight'] = preflight(z)
    elif data['bundle'] != 'com.spotify.client':
        raise ValueError('Input is not stock Spotify: ' + data['bundle'])
    print(json.dumps(data, indent=2))
    if args.output:
        with open(args.output, 'a', encoding='utf-8') as f:
            for k, v in data.items():
                if isinstance(v, str):
                    f.write(f'{k}={v}\n')
    if args.require_shrubify:
        print('PASS: structural packaging checks. NOT signed or device-installation tested.')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('::error::IPA packaging check failed: ' + str(exc), file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env python3
"""Read IPA version from its actual app Info.plist, never the download URL."""
import argparse
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path

def info(path):
    with zipfile.ZipFile(path) as z:
        names = [s for s in z.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist',s)]
        if len(names) != 1: raise ValueError('Expected one Payload/*.app/Info.plist')
        p = plistlib.loads(z.read(names[0]))
        return {'version':str(p['CFBundleShortVersionString']),
                'build':str(p.get('CFBundleVersion','1')),
                'bundle':str(p['CFBundleIdentifier'])}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('ipa');ap.add_argument('--expected',default='')
    ap.add_argument('--require-shrubify',action='store_true');ap.add_argument('--output',default='')
    a=ap.parse_args(); metadata=info(a.ipa)
    if a.expected and metadata['version'] != a.expected:
        raise ValueError(f"IPA version {metadata['version']} does not match App Store version {a.expected}")
    if a.require_shrubify:
        if metadata['bundle'] != 'com.shrubify.client':
            raise ValueError('Unexpected Shrubify bundle ID: '+metadata['bundle'])
        with zipfile.ZipFile(a.ipa) as z:
            if not any('EeveeSpotify.dylib' in f for f in z.namelist()):
                raise ValueError('Missing injected tweak dylib')
    else:
        if metadata['bundle'] != 'com.spotify.client':
            raise ValueError('Input is not a stock Spotify IPA: '+metadata['bundle'])
    print(json.dumps(metadata,indent=2))
    if a.output:
        with open(a.output,'a',encoding='utf-8') as f:
            for k,v in metadata.items(): f.write(f'{k}={v}\n')

if __name__ == '__main__':
    try: main()
    except Exception as e:
        print('::error::Invalid IPA: '+str(e),file=sys.stderr);sys.exit(1)

#!/usr/bin/env python3
"""Minimal Info.plist-only modification: name + unique AltStore build number.

Does not touch Spotify's bundle ID, colors, streaming behavior or icons.
The IPA must be re-signed after this operation.
"""
import argparse
import os
import plistlib
import re
import tempfile
import zipfile
from pathlib import Path

ap=argparse.ArgumentParser();ap.add_argument('ipa');ap.add_argument('--build',required=True)
a=ap.parse_args()
if not a.build.isdecimal(): raise ValueError('Build must be numeric')
source=Path(a.ipa)
fd,temp=tempfile.mkstemp(suffix='.ipa',dir=source.parent);os.close(fd)
try:
    with zipfile.ZipFile(source,'r') as zin,zipfile.ZipFile(temp,'w') as zout:
        candidates=[x for x in zin.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist',x)]
        if len(candidates)!=1: raise ValueError('Missing app Info.plist')
        for item in zin.infolist():
            data=zin.read(item.filename)
            if item.filename==candidates[0]:
                p=plistlib.loads(data)
                if p.get('CFBundleIdentifier')!='com.spotify.client':
                    raise ValueError('Unexpected bundle: '+str(p.get('CFBundleIdentifier')))
                p['CFBundleName']='Shrubify';p['CFBundleDisplayName']='Shrubify'
                p['CFBundleVersion']=a.build
                data=plistlib.dumps(p,fmt=plistlib.FMT_BINARY)
            zout.writestr(item,data)
    os.replace(temp,source)
except BaseException:
    if os.path.exists(temp):os.unlink(temp)
    raise
print(f'Branded {source} as Shrubify (build {a.build})')

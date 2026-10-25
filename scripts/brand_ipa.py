#!/usr/bin/env python3
"""Prepare an *unsigned* injected Spotify IPA for signing as Shrubify.

Keeps the custom com.shrubify.client ID, preserves code/dylibs/frameworks,
but removes leftover old signing metadata and unused embedded app extensions
whose old Spotify identifiers/entitlements cannot be signed with Shrubify's ID.
A valid matching provisioning profile and a genuine iOS code signature are
STILL mandatory; this script does not sign or guarantee installation.
"""
import argparse
import os
import plistlib
import re
import tempfile
import zipfile
from pathlib import Path

APP_INFO = re.compile(r"^Payload/[^/]+\.app/Info\.plist$")
DROP_PARTS = {"Watch", "WatchKit", "WatchKitSupport", "PlugIns", "Extensions",
              "_CodeSignature", "SC_Info", "__MACOSX"}
DROP_FILES = {"embedded.mobileprovision", "PkgInfo", ".DS_Store"}


def should_drop(filename, app_prefix):
    parts = filename.rstrip('/').split('/')
    if any(part in DROP_PARTS for part in parts):
        return True
    if any(part.endswith('.appex') for part in parts):
        return True
    if any(part.startswith('._') for part in parts):
        return True
    if parts[-1] in DROP_FILES:
        return True
    # An installable IPA needs only Payload; don't forward stray build metadata.
    if not filename.startswith(app_prefix):
        return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa')
    parser.add_argument('--build', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]+', args.build):
        parser.error('Build must contain digits only')
    path = Path(args.ipa)
    if not path.is_file():
        parser.error('IPA file not found')
    fd, temp = tempfile.mkstemp(prefix='.shrubify-', suffix='.ipa', dir=path.parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(path, 'r') as zin, zipfile.ZipFile(temp, 'w') as zout:
            plist_paths = [n for n in zin.namelist() if APP_INFO.fullmatch(n)]
            if len(plist_paths) != 1:
                raise ValueError(f'Expected one main .app/Info.plist, found {len(plist_paths)}')
            plist_name = plist_paths[0]
            app_prefix = plist_name[:-len('Info.plist')]
            original = plistlib.loads(zin.read(plist_name))
            current = original.get('CFBundleIdentifier')
            if current not in ('com.spotify.client', 'com.shrubify.client'):
                raise ValueError('Unexpected input bundle ID: ' + str(current))
            executable = original.get('CFBundleExecutable')
            if not isinstance(executable, str) or not executable or '/' in executable:
                raise ValueError('Missing or invalid CFBundleExecutable in app Info.plist')
            if app_prefix + executable not in zin.namelist():
                raise ValueError('App executable missing: ' + app_prefix + executable)
            original['CFBundleIdentifier'] = 'com.shrubify.client'
            original['CFBundleName'] = 'Shrubify'
            original['CFBundleDisplayName'] = 'Shrubify'
            original['CFBundleVersion'] = args.build
            # Force actual SpringBoard primary icon to bundled Shrubify PNG assets.
            # CFBundleIconName often points to Spotify's original Assets.car; remove it.
            original.pop('CFBundleIconName', None)
            for key in ('CFBundleIcons', 'CFBundleIcons~ipad'):
                icon_config = original.get(key)
                if not isinstance(icon_config, dict):
                    icon_config = {}
                else:
                    icon_config = dict(icon_config)
                primary = dict(icon_config.get('CFBundlePrimaryIcon') or {})
                primary.pop('CFBundleIconName', None)
                primary['CFBundleIconFiles'] = ['Shrubify']
                primary['UIPrerenderedIcon'] = True
                icon_config['CFBundlePrimaryIcon'] = primary
                original[key] = icon_config
            # Sideload tools must not inherit device restrictions from App Store IPA.
            original.pop('UISupportedDevices', None)
            replacement = plistlib.dumps(original, fmt=plistlib.FMT_BINARY)
            seen = set()
            dropped = 0
            for entry in zin.infolist():
                n = entry.filename
                if n in seen:
                    raise ValueError('Duplicate ZIP member: ' + n)
                seen.add(n)
                if should_drop(n, app_prefix):
                    dropped += 1
                    continue
                data = replacement if n == plist_name else zin.read(entry)
                zout.writestr(entry, data)
            if plist_name not in seen:
                raise ValueError('Missing app plist')
        with zipfile.ZipFile(temp, 'r') as check:
            damaged = check.testzip()
            if damaged:
                raise ValueError('Archive is damaged at ' + damaged)
        os.replace(temp, path)
    except BaseException:
        if os.path.exists(temp):
            os.unlink(temp)
        raise
    print(f'Shrubify prepared for signing: {path} (com.shrubify.client, build {args.build}, removed {dropped} old/unneeded entries)')
    print('IMPORTANT: The IPA is UNSIGNED. The signer must sign the app and each nested executable with a profile permitting com.shrubify.client.')


if __name__ == '__main__':
    main()

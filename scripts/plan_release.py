#!/usr/bin/env python3
"""Discover new Spotify versions and match them to *user-supplied* IPA URLs.

This deliberately never scrapes/decrypts the App Store binary. A detected
update without a matching IPA URL is reported as pending, not falsely built.
"""
import argparse
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

SPOTIFY_APP_ID = "324684580"

def fetch_json(url, token=None):
    headers = {"Accept": "application/json", "User-Agent": "Shrubify-GitHub-Actions/1.0"}
    if token and "api.github.com" in url:
        headers["Authorization"] = "Bearer " + token
        headers["X-GitHub-Api-Version"] = "2022-11-28"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=22) as response:
        return json.load(response)

def catalog_versions(obj):
    if not isinstance(obj, dict):
        raise ValueError("IPA catalog must be a JSON object")
    versions = obj.get("versions", {})
    if not isinstance(versions, dict):
        raise ValueError("IPA catalog versions must be an object")
    clean = {}
    for version, value in versions.items():
        if not re.fullmatch(r"\d+(?:\.\d+){1,3}", str(version)):
            continue
        if isinstance(value, dict):
            value = value.get("ipa_url") or value.get("url")
        if isinstance(value, str) and value.startswith("https://"):
            clean[version] = value
    return clean

def emit(outputs):
    outfile = os.environ.get("GITHUB_OUTPUT")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if outfile:
        with open(outfile, "a", encoding="utf-8") as f:
            for key, val in outputs.items():
                # No multiline values go through GitHub outputs.
                f.write(f"{key}={val}\n")
    else:
        for key,val in outputs.items():
            print(f"{key}={val}")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"### Shrubify release check\n\nSpotify App Store: **{outputs['latest_version']}**. {outputs['reason']}\n")

def main():
    a = argparse.ArgumentParser()
    a.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY',''))
    a.add_argument('--sha', default=os.environ.get('GITHUB_SHA',''))
    a.add_argument('--tweak', default='1.0.0')
    a.add_argument('--manual-url', default='')
    a.add_argument('--catalog-url', default='')
    a.add_argument('--fallback-url', default='')
    a.add_argument('--token', default='')
    a.add_argument('--url-file', default='')
    a.add_argument('--event', default=os.environ.get('GITHUB_EVENT_NAME',''))
    a.add_argument('--public-release', choices=['true','false'], default='false')
    args = a.parse_args()
    result = fetch_json('https://itunes.apple.com/lookup?id='+SPOTIFY_APP_ID+'&country=us')
    matches = [x for x in result.get('results', []) if x.get('bundleId') == 'com.spotify.client']
    if not matches: raise RuntimeError('Spotify App Store lookup returned no verified Spotify application')
    latest = matches[0]['version']
    if not re.fullmatch(r'\d+(?:\.\d+){1,3}',latest): raise ValueError('Invalid App Store version')
    versions = catalog_versions(json.loads(Path('config/ipa-sources.json').read_text()))
    if args.catalog_url:
        versions.update(catalog_versions(fetch_json(args.catalog_url)))
    manual = args.manual_url.strip()
    url = manual or versions.get(latest, '') or args.fallback_url.strip()
    if url and not url.startswith('https://'):
        raise ValueError('Only HTTPS IPA download URLs are supported')
    # A manual build may use an older Spotify binary; inspect actual Info.plist later.
    expected = '' if manual else latest
    skip_reason = ''
    if args.event != 'workflow_dispatch' and args.public_release != 'true':
        skip_reason = 'Set repository variable ALLOW_PUBLIC_IPA_RELEASE=true to enable scheduled releases.'
    elif not url:
        skip_reason = 'No authorized IPA URL was configured for this version.'
    # Avoid recurring macOS builds for already-published release from this commit.
    if not skip_reason and not manual and args.repo and args.sha and args.token:
        tag = f'shrubify-s{latest}-v{args.tweak}-g{args.sha[:7]}'
        try:
            data = fetch_json(f'https://api.github.com/repos/{args.repo}/releases/tags/{tag}',args.token)
            if data.get('id'): skip_reason = 'This exact Spotify/tweak/source revision is already released.'
        except urllib.error.HTTPError as e:
            if e.code != 404: raise
    output = {
        'build': 'false' if skip_reason else 'true',
        'needs_ipa': 'true' if not url else 'false',
        'latest_version': latest,
        'expected_version': expected,
        'ipa_url': url if not skip_reason else '',
        'reason': skip_reason or 'A matching IPA is available; preparing the build.'
    }
    if args.url_file and url:
        Path(args.url_file).write_text(url)
        Path(args.url_file).chmod(0o600)
    emit(output)

if __name__ == '__main__':
    try: main()
    except Exception as e:
        print(f'::error::Release planning failed: {e}',file=sys.stderr)
        sys.exit(1)

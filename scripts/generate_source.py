#!/usr/bin/env python3
"""Make AltStore Classic / Feather / SideStore compatible source from *real* releases."""
import argparse
import json
import re
import urllib.request
from datetime import datetime,timezone
from pathlib import Path

TAG = re.compile(r'^shrubify-s(?P<spotify>\d+(?:\.\d+){1,3})-v(?P<tweak>\d+(?:\.\d+){1,3})-g[0-9a-f]{7}(?:-r\d+)?$')

def source_for(repo, releases, branch="main"):
    icon=f'https://raw.githubusercontent.com/{repo}/{branch}/docs/icon.png'
    seen=set(); versions=[]
    for release in sorted(releases,key=lambda r:r.get('published_at') or '',reverse=True):
        if release.get('draft'): continue
        matched=TAG.fullmatch(release.get('tag_name',''))
        if not matched: continue
        assets=[a for a in release.get('assets',[]) if a.get('name','').endswith('.ipa')]
        if not assets: continue
        asset=assets[0]
        version=matched['spotify']
        build=str(release.get('body','').split('altstore-build: ')[-1].splitlines()[0]).strip() if 'altstore-build: ' in release.get('body','') else ''
        if not build.isdecimal(): continue
        unique=(version,build)
        if unique in seen: continue
        seen.add(unique)
        versions.append({
           'version':version,'buildVersion':build,
           'date':(release.get('published_at') or datetime.now(timezone.utc).isoformat())[:10],
           'localizedDescription':f'Shrubify v{matched["tweak"]} for Spotify {version}. iOS 26 Liquid Glass settings; compatibility depends on Spotify version.',
           'downloadURL':asset['browser_download_url'],'size':int(asset['size']),
           'minOSVersion':'16.1'
        })
        if len(versions)>=75:break
    return {'name':'Shrubify','subtitle':'Made by shrubbery & the ShrubHub team',
       'description':'A community fork of EeveeSpotify Reincarnated. Liquid Glass settings on iOS 26, with Spotify\u2019s original colors preserved. Unofficial, not affiliated with Spotify.',
       'iconURL':icon,'website':f'https://github.com/{repo}',
       'apps': ([{'name':'Shrubify','bundleIdentifier':'com.shrubify.client',
                  'developerName':'shrubbery & ShrubHub team',
                  'subtitle':'Clean Spotify customization',
                  'localizedDescription':'Shrubify provides its own clean settings, app icon, developers page and stability diagnostics. Open-source upstream contributions are credited in the source repository.',
                  'iconURL':icon,'versions':versions,'appPermissions':{'entitlements':[],'privacy':[]}}]
                 if versions else [])}

def get_releases(repo,token):
    request=urllib.request.Request(f'https://api.github.com/repos/{repo}/releases?per_page=100',
      headers={'Accept':'application/vnd.github+json','User-Agent':'Shrubify-Source/1.0',
       **({'Authorization':'Bearer '+token} if token else {})})
    with urllib.request.urlopen(request,timeout=30) as f:return json.load(f)

def main():
    a=argparse.ArgumentParser();a.add_argument('--repo',required=True);a.add_argument('--token',default='');
    a.add_argument('--fixture',default='');a.add_argument('--branch',default='main');a.add_argument('--output',default='docs/repo.json')
    args=a.parse_args()
    releases=json.loads(Path(args.fixture).read_text()) if args.fixture else get_releases(args.repo,args.token)
    doc=source_for(args.repo,releases,args.branch)
    out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
    print(f'Generated {out} with {sum(len(app["versions"]) for app in doc["apps"])} released version(s)')

if __name__=='__main__':main()

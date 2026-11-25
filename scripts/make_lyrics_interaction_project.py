#!/usr/bin/env python3
"""Build a dependency-free Xcode UI-test project from production control sources."""
import hashlib
import json
from pathlib import Path
import plistlib
import sys

repo = Path(__file__).resolve().parents[1]
folder = Path(sys.argv[1]).resolve()
project = folder / 'LyricsInteractions.xcodeproj'
(project / 'xcshareddata/xcschemes').mkdir(parents=True, exist_ok=True)
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(key, isa, **fields):
    identifier = uid(key); objects[identifier] = dict(isa=isa, **fields); return identifier

def sources(names, prefix):
    refs, builds = [], []
    for name in names:
        ref = obj(prefix + name, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=str(repo / name), sourceTree='<absolute>')
        refs.append(ref); builds.append(obj('build-' + prefix + name, 'PBXBuildFile', fileRef=ref))
    phase = obj(prefix + 'sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0)
    return refs, phase

app_files = [
    'Tests/LyricsInteraction/App.swift',
    'Tests/LyricsInteraction/ContentFixture.swift',
    'Sources/EeveeSpotify/Karaoke/KaraokeActionButton.swift',
    'Sources/EeveeSpotify/Karaoke/KaraokeModal.swift',
    'Sources/EeveeSpotify/Karaoke/KaraokeGlass.swift',
    'Sources/EeveeSpotify/Karaoke/KaraokeTiming.swift',
    'Sources/EeveeSpotify/Karaoke/KaraokeReadingPane.swift',
    'Sources/EeveeSpotify/Karaoke/KaraokePlaybackControls.swift',
    'Sources/EeveeSpotify/Appearance/ShrubifyLiquidGlass.swift',
    'Sources/EeveeSpotify/Appearance/GlassCapsule.swift',
    'Sources/EeveeSpotify/Appearance/NativeTabletGlass.swift',
    'Sources/EeveeSpotify/Appearance/NativeGlassGeometry.swift',
    'Sources/EeveeSpotify/Appearance/PlayerLyricPreview.swift',
    'Sources/EeveeSpotify/Appearance/PlayerFullscreenPresentation.swift',
    'Sources/EeveeSpotify/Appearance/PlayerArtistNavigation.swift',
    'Sources/EeveeSpotify/Lyrics/LyricsChromeVisibility.swift',
]
app_refs, app_phase = sources(app_files, 'app-')
test_refs, test_phase = sources(['Tests/LyricsInteraction/UITests/ControlsTests.swift'], 'test-')
app_product = obj('app-product', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='LyricsControlHarness.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = obj('test-product', 'PBXFileReference', explicitFileType='wrapper.cfbundle', includeInIndex=0, path='InteractionUITests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
products = obj('products', 'PBXGroup', children=[app_product, test_product], name='Products', sourceTree='<group>')
root = obj('root', 'PBXGroup', children=app_refs + test_refs + [products], sourceTree='<group>')
common = dict(SWIFT_VERSION='5.0', SDKROOT='iphoneos', IPHONEOS_DEPLOYMENT_TARGET='26.0', CODE_SIGNING_ALLOWED='YES', CODE_SIGN_IDENTITY='-', TARGETED_DEVICE_FAMILY='2')

def configs(prefix, settings):
    entries = []
    for mode in ['Debug', 'Release']:
        entries.append(obj(prefix + mode, 'XCBuildConfiguration', name=mode, buildSettings={**common, **settings}))
    return obj(prefix + 'configs', 'XCConfigurationList', buildConfigurations=entries, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')

info = {'CFBundleIdentifier': 'com.shrubify.lyrics-harness', 'CFBundleExecutable': 'LyricsControlHarness', 'CFBundleName': 'LyricsControlHarness',
        'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0', 'MinimumOSVersion': '26.0',
        'UIDeviceFamily': [2], 'UIRequiresFullScreen': True,
        'UISupportedInterfaceOrientations': ['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
        'UILaunchScreen': {}, 'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False, 'UISceneConfigurations': {}}}
with (folder / 'Info.plist').open('wb') as file: plistlib.dump(info, file)
app_config = configs('app-', dict(PRODUCT_NAME='LyricsControlHarness', PRODUCT_BUNDLE_IDENTIFIER='com.shrubify.lyrics-harness', INFOPLIST_FILE=str(folder / 'Info.plist')))
test_config = configs('test-', dict(PRODUCT_NAME='InteractionUITests', PRODUCT_BUNDLE_IDENTIFIER='com.shrubify.lyrics-harness.uitests', GENERATE_INFOPLIST_FILE='YES', TEST_TARGET_NAME='LyricsControlHarness'))
app_target = obj('app-target', 'PBXNativeTarget', name='LyricsControlHarness', productName='LyricsControlHarness', productType='com.apple.product-type.application', productReference=app_product, buildConfigurationList=app_config, buildPhases=[app_phase], buildRules=[], dependencies=[])
proxy = obj('proxy', 'PBXContainerItemProxy', containerPortal=uid('project'), proxyType=1, remoteGlobalIDString=app_target, remoteInfo='LyricsControlHarness')
dependency = obj('dependency', 'PBXTargetDependency', target=app_target, targetProxy=proxy)
test_target = obj('test-target', 'PBXNativeTarget', name='InteractionUITests', productName='InteractionUITests', productType='com.apple.product-type.bundle.ui-testing', productReference=test_product, buildConfigurationList=test_config, buildPhases=[test_phase], buildRules=[], dependencies=[dependency])
obj('project', 'PBXProject', attributes={'LastUpgradeCheck': '2610', 'TargetAttributes': {test_target: {'TestTargetID': app_target}}}, buildConfigurationList=configs('project-', {}), compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0, knownRegions=['en', 'Base'], mainGroup=root, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app_target, test_target])

def encode(value):
    if isinstance(value, dict): return '{\n' + '\n'.join(f'{json.dumps(str(key))} = {encode(item)};' for key, item in value.items()) + '\n}'
    if isinstance(value, list): return '(' + ','.join(encode(item) for item in value) + ')'
    return json.dumps(str(value))
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=uid('project'))))
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2610" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="LyricsControlHarness.app" BlueprintName="LyricsControlHarness" ReferencedContainer="container:LyricsInteractions.xcodeproj"/></BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="InteractionUITests.xctest" BlueprintName="InteractionUITests" ReferencedContainer="container:LyricsInteractions.xcodeproj"/></BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="InteractionUITests.xctest" BlueprintName="InteractionUITests" ReferencedContainer="container:LyricsInteractions.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="LyricsControlHarness.app" BlueprintName="LyricsControlHarness" ReferencedContainer="container:LyricsInteractions.xcodeproj"/></BuildableProductRunnable></LaunchAction>
</Scheme>'''
(project / 'xcshareddata/xcschemes/LyricsInteractions.xcscheme').write_text(scheme)
print(project)

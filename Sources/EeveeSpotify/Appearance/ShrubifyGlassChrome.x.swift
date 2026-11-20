import UIKit
import Orion
import ObjectiveC.runtime

struct ShrubifyGlassChromeGroup: HookGroup {}

/// One hook on a class that always exists: every surface is discovered from the
/// window instead of from a Spotify class name that may be renamed, so this is
/// the only place Liquid Glass can stop working by accident.
class ShrubifyGlassWindowHook: ClassHook<UIView> {
    typealias Group = ShrubifyGlassChromeGroup
    static let targetName = "UIWindow"

    func layoutSubviews() {
        orig.layoutSubviews()
        let window = target
        onMainThreadSync { ShrubifyGlassChrome.pass(in: window) }
    }
}

func activateShrubifyGlassChrome() {
    guard EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { ShrubifyGlassChrome.start() }
    ShrubifyGlassChromeGroup().activate()
    writeDebugLog("[GlassChrome] window pass on — tab bar, mini-player and player controls")
}

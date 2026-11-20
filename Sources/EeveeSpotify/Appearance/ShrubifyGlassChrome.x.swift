import UIKit
import Orion

struct ShrubifyGlassChromeGroup: HookGroup {}

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
    guard #available(iOS 26.0, *), EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { ShrubifyGlassChrome.start() }
    ShrubifyGlassChromeGroup().activate()
}

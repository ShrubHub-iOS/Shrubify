import Foundation
import UIKit
import Orion
import ObjectiveC.runtime

struct NativeTabletTabGlassGroup: HookGroup {}
struct NativeTabletMiniGlassGroup: HookGroup {}

// These groups run only on iPad, where Evolved's replacement hooks stay off.
class NativeTabletTabGlassHook: ClassHook<UIView> {
    typealias Group = NativeTabletTabGlassGroup
    static let targetName = "NavigationUI_TabBarImpl.TabBarView"
    func layoutSubviews() {
        orig.layoutSubviews()
        let view = target
        onMainThreadSync { NativeTabletGlass.apply(to: view, miniPlayer: false) }
    }
}

class NativeTabletMiniGlassHook: ClassHook<UIView> {
    typealias Group = NativeTabletMiniGlassGroup
    static let targetName = "_TtC22NowPlaying_BarPageImplP33_CCC0D2EEA6D4725EECD8965E8C38C86D20TouchPassthroughView"
    func layoutSubviews() {
        orig.layoutSubviews()
        let view = target
        onMainThreadSync { NativeTabletGlass.apply(to: view, miniPlayer: true) }
    }
}


func activateNativeTabletGlass() {
    guard EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { NativeTabletGlass.start() }
    if #available(iOS 26.0, *) {
        for (name, activate) in [
            (NativeTabletTabGlassHook.targetName, { NativeTabletTabGlassGroup().activate() }),
            (NativeTabletMiniGlassHook.targetName, { NativeTabletMiniGlassGroup().activate() })
        ] {
            guard let cls = NSClassFromString(name) as? UIView.Type,
                  class_getInstanceMethod(cls, #selector(UIView.layoutSubviews)) != nil else { continue }
            activate()
        }
    }
}

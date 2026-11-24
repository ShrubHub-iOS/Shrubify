import UIKit
import Orion
import ObjectiveC.runtime

struct NativeTabletTabGlassGroup: HookGroup {}
struct NativeTabletMiniGlassGroup: HookGroup {}
struct NativeTabletNavigationGroup: HookGroup {}
struct NativeTabletCompactTabGroup: HookGroup {}
struct NativeTabletMiniControllerGroup: HookGroup {}

// Intentionally limited to the two bar hosts. Never hook a cell, image or
// button base class: scrolling Home must not run any Shrubify glass layout.
class NativeTabletTabGlassHook: ClassHook<UIView> {
    typealias Group = NativeTabletTabGlassGroup
    static let targetName = "NavigationUI_TabBarImpl.TabBarView"
    func layoutSubviews() {
        orig.layoutSubviews()
        let view = target
        onMainThreadSync { NativeTabletGlass.layout(.tabs, in: view) }
    }
    func didMoveToWindow() {
        orig.didMoveToWindow()
        let view = target
        onMainThreadSync { NativeTabletGlass.layout(.tabs, in: view) }
    }
}

class NativeTabletCompactTabHook: ClassHook<UIView> {
    typealias Group = NativeTabletCompactTabGroup
    static let targetName = "_TtC23NavigationUI_TabBarImpl17TabBarCompactView"

    func layoutSubviews() {
        orig.layoutSubviews()
        let view = target
        onMainThreadSync { NativeTabletGlass.layoutCompactTabs(in: view) }
    }
}

class NativeTabletMiniGlassHook: ClassHook<UIView> {
    typealias Group = NativeTabletMiniGlassGroup
    static let targetName = "_TtC22NowPlaying_BarPageImplP33_CCC0D2EEA6D4725EECD8965E8C38C86D20TouchPassthroughView"
    func layoutSubviews() {
        orig.layoutSubviews()
        let view = target
        onMainThreadSync { NativeTabletGlass.layout(.miniPlayer, in: view) }
    }
    func didMoveToWindow() {
        orig.didMoveToWindow()
        let view = target
        onMainThreadSync { NativeTabletGlass.layout(.miniPlayer, in: view) }
    }
}

class NativeTabletNavigationHook: ClassHook<UIViewController> {
    typealias Group = NativeTabletNavigationGroup
    static let targetName = "_TtC23NavigationUI_TabBarImpl19TabBarContainerImpl"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        let controller = target
        onMainThreadSync {
            guard let root = controller.viewIfLoaded else { return }
            NativeTabletGlass.layoutNavigation(in: root)
        }
    }
}

class NativeTabletMiniControllerHook: ClassHook<UIViewController> {
    typealias Group = NativeTabletMiniControllerGroup
    static let targetName = "_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        let controller = target
        onMainThreadSync {
            if let view = controller.viewIfLoaded { NativeTabletGlass.layoutMiniControllerView(view) }
        }
    }
}

func activateNativeTabletGlass() {
    guard #available(iOS 26.0, *), EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { NativeTabletGlass.start() }
    for (name, activate) in [
        (NativeTabletTabGlassHook.targetName, { NativeTabletTabGlassGroup().activate() }),
        (NativeTabletCompactTabHook.targetName, { NativeTabletCompactTabGroup().activate() }),
        (NativeTabletMiniGlassHook.targetName, { NativeTabletMiniGlassGroup().activate() })
    ] {
        guard let cls = NSClassFromString(name) as? UIView.Type,
              class_getInstanceMethod(cls, #selector(UIView.layoutSubviews)) != nil else { continue }
        activate()
    }
    for (name, activate) in [
        (NativeTabletNavigationHook.targetName, { NativeTabletNavigationGroup().activate() }),
        (NativeTabletMiniControllerHook.targetName, { NativeTabletMiniControllerGroup().activate() })
    ] {
        guard let cls = NSClassFromString(name) as? UIViewController.Type,
              class_getInstanceMethod(cls, #selector(UIViewController.viewDidLayoutSubviews)) != nil else { continue }
        activate()
    }
}

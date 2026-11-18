import Foundation
import UIKit
import Orion
import ObjectiveC.runtime

struct NativeTabletTabGlassGroup: HookGroup {}
struct NativeTabletMiniGlassGroup: HookGroup {}
struct NativeContentCellGlassGroup: HookGroup {}
struct NativeHomeShortcutGlassGroup: HookGroup {}
struct NativeFilterChipGlassGroup: HookGroup {}
struct NativePlayerControlGlassGroup: HookGroup {}

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
        onMainThreadSync {
            NativeTabletGlass.apply(to: view, miniPlayer: true)
            NativeContentGlass.refresh(in: view)
        }
    }
}

// Cells appearing after launch (including reused shelf and track cells) get a
// bounded pass over their own content. Unrecognized views are never styled.
class NativeContentCellGlassHook: ClassHook<UICollectionViewCell> {
    typealias Group = NativeContentCellGlassGroup
    func layoutSubviews() {
        orig.layoutSubviews()
        let cell = target
        onMainThreadSync { NativeContentGlass.schedule(cell) }
    }
    func didMoveToWindow() {
        orig.didMoveToWindow()
        let cell = target
        onMainThreadSync {
            if cell.window == nil { NativeContentGlass.prepareForReuse(cell) }
            else { NativeContentGlass.schedule(cell) }
        }
    }
    func prepareForReuse() {
        let cell = target
        onMainThreadSync { NativeContentGlass.prepareForReuse(cell) }
        orig.prepareForReuse()
    }
}

// The Home shortcut grid can also live outside a collection-view cell.
class NativeHomeShortcutGlassHook: ClassHook<UIView> {
    typealias Group = NativeHomeShortcutGlassGroup
    static let targetName = "LegacyUI_ECMCoreKit.InteractableLayoutBackingButton"
    func layoutSubviews() {
        orig.layoutSubviews()
        let tile = target
        onMainThreadSync {
            guard #available(iOS 26.0, *), NativeTabletGlass.contentEnabled else { return }
            NativeContentGlass.update(tile)
        }
    }
}

class NativeFilterChipGlassHook: ClassHook<UIView> {
    typealias Group = NativeFilterChipGlassGroup
    static let targetName = "EncoreConsumerMobile_BaseKit.FilterChipView"
    func layoutSubviews() {
        orig.layoutSubviews()
        let chip = target
        onMainThreadSync { NativeContentGlass.refresh(in: chip) }
    }
}

class NativePlayerControlGlassHook: ClassHook<UIView> {
    typealias Group = NativePlayerControlGlassGroup
    static let targetName = "NowPlaying_ModesImpl.PlaybackControlsElementsUnit"
    func layoutSubviews() {
        orig.layoutSubviews()
        let controls = target
        onMainThreadSync { NativeContentGlass.refresh(in: controls) }
    }
}


func activateNativeTabletGlass() {
    guard EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { NativeTabletGlass.start() }
    if #available(iOS 26.0, *) {
        NativeContentCellGlassGroup().activate()
        for (name, activate) in [
            (NativeTabletTabGlassHook.targetName, { NativeTabletTabGlassGroup().activate() }),
            (NativeTabletMiniGlassHook.targetName, { NativeTabletMiniGlassGroup().activate() }),
            (NativeHomeShortcutGlassHook.targetName, { NativeHomeShortcutGlassGroup().activate() }),
            (NativeFilterChipGlassHook.targetName, { NativeFilterChipGlassGroup().activate() }),
            (NativePlayerControlGlassHook.targetName, { NativePlayerControlGlassGroup().activate() })
        ] {
            guard let cls = NSClassFromString(name) as? UIView.Type,
                  class_getInstanceMethod(cls, #selector(UIView.layoutSubviews)) != nil else { continue }
            activate()
        }
    }
}

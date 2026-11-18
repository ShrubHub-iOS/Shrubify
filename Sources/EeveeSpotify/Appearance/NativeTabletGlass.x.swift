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

@MainActor
enum NativeTabletGlass {
    private static var key: UInt8 = 0
    private static let hosts = NSHashTable<UIView>.weakObjects()
    @MainActor private final class State {
        let miniPlayer: Bool
        weak var owner: UIView?
        var plate: UIVisualEffectView?
        var originalColor: UIColor?
        init(miniPlayer: Bool) { self.miniPlayer = miniPlayer }
        func remove() {
            plate?.removeFromSuperview(); plate = nil
            if miniPlayer { owner?.backgroundColor = originalColor }
            owner = nil
        }
    }

    static func reapply() {
        for host in hosts.allObjects {
            guard let state = objc_getAssociatedObject(host, &key) as? State else { continue }
            apply(to: host, miniPlayer: state.miniPlayer)
        }
    }

    static func apply(to host: UIView, miniPlayer: Bool) {
        hosts.add(host)
        let state: State
        if let old = objc_getAssociatedObject(host, &key) as? State { state = old }
        else {
            state = State(miniPlayer: miniPlayer)
            objc_setAssociatedObject(host, &key, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        guard #available(iOS 26.0, *),
              UserDefaults.standard.object(forKey: "ShrubifyNativeTabletGlass") as? Bool ?? true,
              host.window != nil else { state.remove(); return }
        var nodes = [host]; var index = 0
        var owner: UIView?
        while index < nodes.count && index < 96 {
            let node = nodes[index]; index += 1
            if miniPlayer && node.accessibilityIdentifier == "SPTNowPlayingBar" { owner = node; break }
            if !miniPlayer, let row = node as? UIStackView, row.axis == .horizontal,
               row.accessibilityIdentifier == "tabs-container-view-identifier" { owner = row; break }
            nodes.append(contentsOf: node.subviews.filter { $0 !== state.plate })
        }
        guard let owner else { state.remove(); return }
        let content: CGRect
        if let row = owner as? UIStackView, !miniPlayer {
            let items = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 }
            guard (2...6).contains(items.count) else { state.remove(); return }
            content = items.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: owner)) }
        } else { content = owner.bounds }
        guard let frame = NativeGlassGeometry.frame(bounds: owner.bounds, content: content, miniPlayer: miniPlayer)
        else { state.remove(); return }
        // Respect an existing native material instead of stacking a second one.
        guard !owner.subviews.contains(where: { $0 is UIVisualEffectView && $0 !== state.plate })
        else { state.remove(); return }
        if state.owner !== owner { state.remove() }
        if state.plate == nil {
            state.owner = owner; state.originalColor = owner.backgroundColor
            let plate = GlassCapsule.makeGlassView(wantsInteractive: false).view
            plate.overrideUserInterfaceStyle = .dark
            plate.isUserInteractionEnabled = false
            plate.accessibilityElementsHidden = true
            owner.insertSubview(plate, at: 0)
            state.plate = plate
        }
        if miniPlayer {
            if let color = owner.backgroundColor, color.cgColor.alpha > 0.001 { state.originalColor = color }
            owner.backgroundColor = .clear
        }
        if state.plate?.frame != frame { state.plate?.frame = frame }
        state.plate?.layer.cornerRadius = min(26, frame.height / 2)
        // No masks, content transforms, safe-area changes, gestures or action relays.
    }
}

func activateNativeTabletGlass() {
    guard EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
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

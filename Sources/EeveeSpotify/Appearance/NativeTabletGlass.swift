import Foundation
import UIKit
import ObjectiveC.runtime

@MainActor
enum NativeTabletGlass {
    private static var key: UInt8 = 0
    private static let hosts = NSHashTable<UIView>.weakObjects()
    @MainActor private final class State {
        let miniPlayer: Bool
        weak var owner: UIView?
        var plate: UIVisualEffectView?
        var originalColor: UIColor?
        weak var host: UIView?
        var hostColor: UIColor?
        var hostWasCleared = false
        var clearedEffects: [(UIVisualEffectView, UIVisualEffect)] = []
        var clearedBackings: [(UIView, CGFloat)] = []
        var clearedColors: [(UIView, UIColor?)] = []
        init(miniPlayer: Bool) { self.miniPlayer = miniPlayer }
        func remove() {
            plate?.removeFromSuperview(); plate = nil
            owner?.backgroundColor = originalColor
            if hostWasCleared, host !== owner { host?.backgroundColor = hostColor }
            hostWasCleared = false
            for (view, effect) in clearedEffects where view.effect == nil { view.effect = effect }
            clearedEffects.removeAll()
            for (view, alpha) in clearedBackings where view.alpha == 0 { view.alpha = alpha }
            clearedBackings.removeAll()
            for (view, color) in clearedColors { view.backgroundColor = color }
            clearedColors.removeAll()
            owner = nil; host = nil
        }
    }

    private static var observers: [NSObjectProtocol] = []
    private static var started = false
    private static var lastDiscovery: TimeInterval = 0

    static func start() {
        guard !started, UIDevice.current.userInterfaceIdiom == .pad else { return }
        started = true
        for notification in [UIWindow.didBecomeVisibleNotification, UIWindow.didBecomeKeyNotification,
                             UIApplication.didBecomeActiveNotification, .eeveeKaraokeLyricsChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { _ in
                onMainThreadSync { discover() }
            })
        }
        for delay in [0.0, 0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { discover() }
        }
    }

    private static func discover() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDiscovery >= 0.2 else { return }
        lastDiscovery = now
        for window in UIApplication.shared.windows where !window.isHidden && window.windowLevel == .normal {
            var nodes = [window as UIView]; var index = 0
            while index < nodes.count && index < 2048 {
                let node = nodes[index]; index += 1
                if node.accessibilityIdentifier == "tabs-container-view-identifier" { apply(to: node, miniPlayer: false) }
                if node.accessibilityIdentifier == "SPTNowPlayingBar" { apply(to: node, miniPlayer: true) }
                nodes.append(contentsOf: node.subviews.filter { $0.accessibilityIdentifier != "shrubify.native.glass.material" })
            }
        }
    }

    static func reapply() {
        lastDiscovery = 0
        discover()
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
               (row.accessibilityIdentifier == "tabs-container-view-identifier"
                || (2...6).contains(row.arrangedSubviews.count) && row.bounds.height <= 96
                   && row.arrangedSubviews.filter({ NSStringFromClass(type(of: $0)).contains("TabBarItem") }).count >= 2) {
                owner = row; break
            }
            nodes.append(contentsOf: node.subviews.filter { $0 !== state.plate })
        }
        guard let owner, owner.bounds.height <= 100 else { state.remove(); return }
        let content: CGRect
        if let row = owner as? UIStackView, !miniPlayer {
            let items = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 }
            guard (2...6).contains(items.count) else { state.remove(); return }
            content = items.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: owner)) }
        } else { content = owner.bounds }
        guard let frame = NativeGlassGeometry.frame(bounds: owner.bounds, content: content, miniPlayer: miniPlayer)
        else { state.remove(); return }
        if owner.subviews.contains(where: { $0 !== state.plate && ($0 as? UIVisualEffectView)?.effect is UIGlassEffect }) {
            state.remove(); return
        }
        if state.owner !== owner { state.remove() }
        if state.plate == nil {
            state.owner = owner; state.originalColor = owner.backgroundColor
            state.host = host; state.hostColor = host.backgroundColor
            let plate = GlassCapsule.makeGlassView(wantsInteractive: false).view
            plate.accessibilityIdentifier = "shrubify.native.glass.material"
            plate.overrideUserInterfaceStyle = .dark
            plate.isUserInteractionEnabled = false
            plate.accessibilityElementsHidden = true
            owner.insertSubview(plate, at: 0)
            state.plate = plate
        }
        // Clear only the bounded bar's old backing. Its contents and events stay intact.
        for effectView in owner.subviews.compactMap({ $0 as? UIVisualEffectView }) where effectView !== state.plate {
            guard let effect = effectView.effect, effect is UIBlurEffect else { continue }
            if let index = state.clearedEffects.firstIndex(where: { $0.0 === effectView }) { state.clearedEffects[index] = (effectView, effect) }
            else { state.clearedEffects.append((effectView, effect)) }
            effectView.effect = nil
        }
        if let color = owner.backgroundColor, color.cgColor.alpha > 0.001 { state.originalColor = color }
        owner.backgroundColor = .clear
        if host !== owner, host.bounds.height <= 100 {
            if let color = host.backgroundColor, color.cgColor.alpha > 0.001 { state.hostColor = color }
            host.backgroundColor = .clear
            state.hostWasCleared = true
        }
        clearLegacyBacking(around: owner, state: state)
        if state.plate?.frame != frame { state.plate?.frame = frame }
        state.plate?.layer.cornerRadius = min(26, frame.height / 2)
        // No masks, content transforms, safe-area changes, gestures or action relays.
    }
    private static func clearLegacyBacking(around owner: UIView, state: State) {
        var ancestor: UIView? = owner
        for _ in 0..<3 {
            guard let root = ancestor, root.bounds.height <= 110 else { break }
            if let material = root as? UIVisualEffectView, let effect = material.effect, effect is UIBlurEffect {
                if let index = state.clearedEffects.firstIndex(where: { $0.0 === material }) { state.clearedEffects[index] = (material, effect) }
                else { state.clearedEffects.append((material, effect)) }
                material.effect = nil
            }
            if root !== owner, root !== state.host {
                if let index = state.clearedColors.firstIndex(where: { $0.0 === root }) {
                    if let color = root.backgroundColor, color.cgColor.alpha > 0.001 { state.clearedColors[index] = (root, color) }
                } else { state.clearedColors.append((root, root.backgroundColor)) }
                root.backgroundColor = .clear
            }
            for child in root.subviews where child !== owner && child !== state.plate {
                let name = NSStringFromClass(type(of: child))
                guard child.bounds.height <= 110, name.contains("TabBarGradientView") || name.contains("TabBarBackgroundView") else { continue }
                var nodes = [child]; var index = 0; var ownsContent = false
                while index < nodes.count && index < 64 {
                    let view = nodes[index]; index += 1
                    if view is UIControl || view is UILabel || view is UIImageView { ownsContent = true; break }
                    nodes.append(contentsOf: view.subviews)
                }
                guard !ownsContent, index >= nodes.count else { continue }
                if !state.clearedBackings.contains(where: { $0.0 === child }) { state.clearedBackings.append((child, child.alpha)) }
                child.alpha = 0
            }
            ancestor = root.superview
        }
    }

}


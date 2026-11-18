import Foundation
import UIKit
import ObjectiveC.runtime

@MainActor
enum NativeTabletGlass {
    private static var key: UInt8 = 0
    private static let hosts = NSHashTable<UIView>.weakObjects()
    private final class Saved<V: UIView, Value> {
        weak var view: V?
        var value: Value
        init(_ view: V, _ value: Value) { self.view = view; self.value = value }
    }

    @MainActor private final class State {
        var plate: UIVisualEffectView?
        var colors: [Saved<UIView, UIColor>] = []
        var effects: [Saved<UIVisualEffectView, UIVisualEffect>] = []
        var backings: [Saved<UIView, CGFloat>] = []

        func clearColor(_ view: UIView) {
            guard let color = view.backgroundColor, color.cgColor.alpha > 0.001 else { return }
            if let saved = colors.first(where: { $0.view === view }) { saved.value = color }
            else { colors.append(Saved(view, color)) }
            view.backgroundColor = .clear
        }
        func clearBlur(_ view: UIVisualEffectView) {
            guard let blur = view.effect as? UIBlurEffect else { return }
            if let saved = effects.first(where: { $0.view === view }) { saved.value = blur }
            else { effects.append(Saved(view, blur)) }
            view.effect = nil
        }
        func hide(_ view: UIView) {
            guard view.alpha > 0 else { return }
            if let saved = backings.first(where: { $0.view === view }) { saved.value = view.alpha }
            else { backings.append(Saved(view, view.alpha)) }
            view.alpha = 0
        }
        func remove() {
            plate?.removeFromSuperview(); plate = nil
            for saved in colors where saved.view?.backgroundColor == .clear { saved.view?.backgroundColor = saved.value }
            for saved in effects where saved.view?.effect == nil { saved.view?.effect = saved.value }
            for saved in backings where saved.view?.alpha == 0 { saved.view?.alpha = saved.value }
            colors.removeAll(); effects.removeAll(); backings.removeAll()
        }
    }

    static var isEnabled: Bool {
        started && (UserDefaults.standard.object(forKey: "ShrubifyNativeTabletGlass") as? Bool ?? true)
    }

    private static var observers: [NSObjectProtocol] = []
    private static var started = false
    private static var lastDiscovery: TimeInterval = 0

    static func start() {
        guard #available(iOS 26.0, *), !started, UIDevice.current.userInterfaceIdiom == .pad else { return }
        started = true
        for notification in [UIWindow.didBecomeVisibleNotification, UIWindow.didBecomeKeyNotification,
                             UIApplication.didBecomeActiveNotification, .eeveeKaraokeLyricsChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { _ in
                onMainThreadSync { discover() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                                                                object: nil, queue: .main) { _ in
            onMainThreadSync { reapply() }
        })
        for delay in [0.0, 0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { discover() }
        }
    }

    private static func discover() {
        guard #available(iOS 26.0, *), isEnabled else { return }
        let decorateContent = !UIAccessibility.isReduceTransparencyEnabled
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDiscovery >= 0.2 else { return }
        lastDiscovery = now
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows where !window.isHidden && window.windowLevel == .normal {
            var nodes = [window as UIView]; var index = 0
            while index < nodes.count && index < 2048 {
                let node = nodes[index]; index += 1
                if isTabRow(node) { apply(to: node, miniPlayer: false) }
                if node.accessibilityIdentifier == "SPTNowPlayingBar" { apply(to: node, miniPlayer: true) }
                if decorateContent { NativeContentGlass.update(node) }
                nodes.append(contentsOf: node.subviews.filter {
                    $0.accessibilityIdentifier != "shrubify.native.glass.material" && $0.accessibilityIdentifier != "shrubify.native.content.material"
                })
            }
        }
    }

    static func reapply() {
        guard started else { return } // Stability Mode did not activate these hooks.
        for owner in hosts.allObjects {
            guard let state = objc_getAssociatedObject(owner, &key) as? State else { continue }
            state.remove()
        }
        NativeContentGlass.removeAll()
        lastDiscovery = 0
        discover()
    }

    static func apply(to host: UIView, miniPlayer: Bool) {
        guard #available(iOS 26.0, *), isEnabled, host.window != nil else { return }
        var nodes = [host]; var index = 0
        var owner: UIView?
        while index < nodes.count && index < 96 {
            let node = nodes[index]; index += 1
            if miniPlayer && node.accessibilityIdentifier == "SPTNowPlayingBar" { owner = node; break }
            if !miniPlayer, isTabRow(node) { owner = node; break }
            nodes.append(contentsOf: node.subviews.filter { $0.accessibilityIdentifier != "shrubify.native.glass.material" })
        }
        guard let owner else { return }
        // A layout hook may arrive via the enclosing bar; discovery arrives via
        // the row itself. Both must address the *same* reversible decoration.
        let state: State
        if let old = objc_getAssociatedObject(owner, &key) as? State { state = old }
        else {
            state = State()
            objc_setAssociatedObject(owner, &key, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            hosts.add(owner)
        }
        guard owner.bounds.height <= 100 else { state.remove(); return }
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
        if state.plate == nil {
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
            state.clearBlur(effectView)
        }
        state.clearColor(owner)
        if host !== owner, host.bounds.height <= 100 { state.clearColor(host) }
        clearLegacyBacking(around: owner, state: state)
        if state.plate?.frame != frame { state.plate?.frame = frame }
        // No masks, content transforms, safe-area changes, gestures or action relays.
    }
    private static func isTabRow(_ view: UIView) -> Bool {
        guard let row = view as? UIStackView, row.axis == .horizontal,
              row.bounds.height <= 100, (2...6).contains(row.arrangedSubviews.count) else { return false }
        return row.accessibilityIdentifier == "tabs-container-view-identifier"
            || row.arrangedSubviews.filter { NSStringFromClass(type(of: $0)).contains("TabBarItem") }.count >= 2
    }

    private static func clearLegacyBacking(around owner: UIView, state: State) {
        var ancestor: UIView? = owner
        for _ in 0..<3 {
            guard let root = ancestor, root.bounds.height <= 110 else { break }
            if let material = root as? UIVisualEffectView { state.clearBlur(material) }
            state.clearColor(root)
            for child in root.subviews where child !== owner && child !== state.plate {
                let name = NSStringFromClass(type(of: child))
                guard name.contains("TabBarGradientView") || name.contains("TabBarBackgroundView") else { continue }
                var nodes = [child]; var index = 0; var ownsContent = false
                while index < nodes.count && index < 64 {
                    let view = nodes[index]; index += 1
                    if view is UIControl || view is UILabel || view is UIImageView { ownsContent = true; break }
                    nodes.append(contentsOf: view.subviews)
                }
                guard !ownsContent, index >= nodes.count else { continue }
                state.hide(child)
            }
            ancestor = root.superview
        }
    }

}


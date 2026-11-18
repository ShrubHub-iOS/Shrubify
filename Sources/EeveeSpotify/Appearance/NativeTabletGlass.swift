import UIKit

/// Opt-in material behind the two native bottom bars. Only their layout hooks
/// supply hosts: no window discovery, cell lifecycle work or playback updates.
@MainActor
enum NativeTabletGlass {
    nonisolated static let preferenceKey = "ShrubifyNativeTabletGlass"
    enum Bar { case tabs, miniPlayer }

    private static let bars = NSMapTable<UIView, State>.weakToStrongObjects()
    private static var accessibilityObserver: NSObjectProtocol?
    private static var enabled = false

    @MainActor private final class State {
        let bar: Bar
        weak var owner: UIView?
        var plate: UIVisualEffectView?
        var restoreBacking: [() -> Void] = []
        init(_ bar: Bar) { self.bar = bar }

        func clearColor(_ view: UIView) {
            guard let color = view.backgroundColor, color.cgColor.alpha > 0 else { return }
            restoreBacking.append { [weak view] in
                if view?.backgroundColor == .clear { view?.backgroundColor = color }
            }
            view.backgroundColor = .clear
        }
        func clearBlur(_ view: UIVisualEffectView) {
            guard let blur = view.effect as? UIBlurEffect else { return }
            restoreBacking.append { [weak view] in if view?.effect == nil { view?.effect = blur } }
            view.effect = nil
        }
        func hide(_ view: UIView) {
            let alpha = view.alpha
            guard alpha > 0 else { return }
            restoreBacking.append { [weak view] in if view?.alpha == 0 { view?.alpha = alpha } }
            view.alpha = 0
        }
        func remove() {
            plate?.removeFromSuperview(); plate = nil
            restoreBacking.reversed().forEach { $0() }; restoreBacking.removeAll()
            owner = nil
        }
    }

    static func start() {
        guard #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad,
              accessibilityObserver == nil else { return }
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil, queue: .main
        ) { _ in onMainThreadSync { reapply() } }
        reapply()
    }

    static func reapply() {
        guard #available(iOS 26.0, *), accessibilityObserver != nil else { return }
        // A missing key means native. An explicit choice from an older install
        // still works, but even explicit ON means bars only.
        enabled = UserDefaults.standard.bool(forKey: preferenceKey) && !UIAccessibility.isReduceTransparencyEnabled
        for case let host as UIView in bars.keyEnumerator().allObjects {
            guard let state = bars.object(forKey: host) else { continue }
            if enabled, host.window != nil { update(host, state) } else { state.remove() }
        }
    }

    static func layout(_ bar: Bar, in host: UIView) {
        guard #available(iOS 26.0, *), accessibilityObserver != nil else { return }
        guard host.window != nil else {
            bars.object(forKey: host)?.remove()
            bars.removeObject(forKey: host)
            return
        }
        let state: State
        if let existing = bars.object(forKey: host) { state = existing }
        else { state = State(bar); bars.setObject(state, forKey: host) }
        // Remember the bar so Studio can apply a change immediately. When off,
        // don't inspect a single subview, allocate a material or mutate UIKit.
        if enabled { update(host, state) }
    }

    @available(iOS 26.0, *)
    private static func update(_ host: UIView, _ state: State) {
        // Never search a page-sized host, even if a future class name matches.
        guard (1...110).contains(host.bounds.height) else { state.remove(); return }
        let owner: UIView
        if let cached = state.owner, cached.isDescendant(of: host), matches(cached, state.bar) { owner = cached }
        else {
            state.remove()
            guard let found = findOwner(in: host, bar: state.bar) else { return }
            owner = found
            state.owner = found
        }
        let content: CGRect
        if state.bar == .tabs, let row = owner as? UIStackView {
            let items = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 }
            guard (2...6).contains(items.count) else { state.remove(); return }
            content = items.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: owner)) }
        } else { content = owner.bounds }
        guard let frame = NativeGlassGeometry.frame(bounds: owner.bounds, content: content, miniPlayer: state.bar == .miniPlayer)
        else { state.remove(); return }
        // Yield if Spotify supplies its own bar material, even after install.
        if owner.subviews.contains(where: { $0 !== state.plate && ($0 as? UIVisualEffectView)?.effect is UIGlassEffect }) {
            state.remove(); return
        }
        var ancestor: UIView? = owner
        while let view = ancestor {
            if (view as? UIVisualEffectView)?.effect is UIGlassEffect { state.remove(); return }
            if view === host { break }
            ancestor = view.superview
        }
        if let plate = state.plate {
            if plate.superview === owner {
                if plate.frame != frame { plate.frame = frame }
                return
            }
            state.remove() // Spotify replaced the backing; release our old edits.
            state.owner = owner
        }
        let glass = UIGlassEffect(style: .regular)
        glass.isInteractive = false
        let plate = UIVisualEffectView(effect: glass)
        plate.cornerConfiguration = .capsule()
        plate.accessibilityIdentifier = "shrubify.native.glass.material"
        plate.isUserInteractionEnabled = false
        plate.accessibilityElementsHidden = true
        plate.frame = frame
        owner.insertSubview(plate, at: 0)
        state.plate = plate
        // One-time installation, not per-layout repainting. Leave content and
        // hit testing alone, including if a future build has unfamiliar chrome.
        for case let effect as UIVisualEffectView in owner.subviews
        where effect !== plate && effect.frame == owner.bounds && effect.contentView.subviews.isEmpty {
            state.clearBlur(effect)
        }
        clearBarBacking(around: owner, within: host, state: state)
    }

    private static func matches(_ view: UIView, _ bar: Bar) -> Bool {
        if bar == .miniPlayer { return view.accessibilityIdentifier == "SPTNowPlayingBar" }
        guard let row = view as? UIStackView, row.axis == .horizontal,
              row.bounds.height <= 100, (2...6).contains(row.arrangedSubviews.count) else { return false }
        return row.accessibilityIdentifier == "tabs-container-view-identifier"
            || row.arrangedSubviews.filter { NSStringFromClass(type(of: $0)).contains("TabBarItem") }.count >= 2
    }

    private static func findOwner(in host: UIView, bar: Bar) -> UIView? {
        var nodes = [host]; var index = 0
        while index < nodes.count {
            let view = nodes[index]; index += 1
            if matches(view, bar) { return view }
            if !(view is UIScrollView || view is UIControl || view is UIImageView), nodes.count < 96 {
                nodes.append(contentsOf: view.subviews.prefix(96 - nodes.count))
            }
        }
        return nil
    }

    private static func clearBarBacking(around owner: UIView, within host: UIView, state: State) {
        var ancestor: UIView? = owner
        while let root = ancestor, root.bounds.height <= 110 {
            if let material = root as? UIVisualEffectView { state.clearBlur(material) }
            state.clearColor(root)
            for child in root.subviews {
                let name = NSStringFromClass(type(of: child))
                // Only empty decorative backings. Never hide an unfamiliar
                // container to force the glass to show through it.
                if child.subviews.isEmpty, name.hasSuffix(".TabBarGradientView") || name.hasSuffix(".TabBarBackgroundView") {
                    state.hide(child)
                }
            }
            if root === host { break }
            ancestor = root.superview
        }
    }
}

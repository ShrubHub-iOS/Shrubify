import UIKit

/// One native glass owner per recognized tablet bar. Only dedicated layout
/// hooks mount material; no window scanning or playback-control decoration.
@MainActor
enum NativeTabletGlass {
    nonisolated static let preferenceKey = "ShrubifyNativeTabletGlass"
    enum Bar { case tabs, miniPlayer }

    private static let bars = NSMapTable<UIView, State>.weakToStrongObjects()
    private static var accessibilityObserver: NSObjectProtocol?
    private static var glassObserver: NSObjectProtocol?
    private static var enabled = false

    @MainActor private final class State {
        let bar: Bar
        weak var owner: UIView?
        var plate: UIVisualEffectView?
        var fallback = false
        var compactRow: CompactRow?
        var restoreBacking: [() -> Void] = []
        init(_ bar: Bar) { self.bar = bar }

        func clearColor(_ view: UIView) {
            if let color = view.backgroundColor, color.cgColor.alpha > 0.001 {
                restoreBacking.append { [weak view] in
                    guard let view, view.backgroundColor == .clear else { return }
                    view.backgroundColor = color
                }
                view.backgroundColor = .clear
            } else if view.backgroundColor == nil,
                      let old = view.layer.backgroundColor, old.alpha > 0.001 {
                restoreBacking.append { [weak view] in
                    guard let view, view.backgroundColor == nil,
                          view.layer.backgroundColor == nil || view.layer.backgroundColor?.alpha == 0 else { return }
                    view.layer.backgroundColor = old
                }
                view.layer.backgroundColor = nil
            }
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
            compactRow?.restore(); compactRow = nil
            plate?.removeFromSuperview(); plate = nil
            restoreBacking.reversed().forEach { $0() }; restoreBacking.removeAll()
            owner = nil
        }
    }

    @MainActor private final class CompactRow {
        weak var row: UIStackView?
        let originalMargins: NSDirectionalEdgeInsets
        let originalRelative: Bool
        var appliedMargins: NSDirectionalEdgeInsets?
        init(_ row: UIStackView) {
            self.row = row
            originalMargins = row.directionalLayoutMargins
            originalRelative = row.isLayoutMarginsRelativeArrangement
        }
        func restore() {
            guard let row, let appliedMargins else { return }
            if row.directionalLayoutMargins == appliedMargins {
                row.directionalLayoutMargins = originalMargins
                row.isLayoutMarginsRelativeArrangement = originalRelative
            }
        }
    }

    static func start() {
        guard #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .pad,
              accessibilityObserver == nil else { return }
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil, queue: .main
        ) { _ in onMainThreadSync { reapply() } }
        // One material for the whole app: a change on the Liquid Glass page
        // must reach these bare bars without reopening the player.
        glassObserver = NotificationCenter.default.addObserver(
            forName: .shrubifyLiquidGlassDidChange, object: nil, queue: .main
        ) { _ in onMainThreadSync { reapply() } }
        reapply()
    }

    /// Default on for the native iPad bars; a stored choice still wins.
    nonisolated static var isOnForCurrentDevice: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    /// True when a recognized bottom bar has our sole live optical plate.
    static func owns(_ bar: Bar, in window: UIView? = nil) -> Bool {
        guard enabled, accessibilityObserver != nil else { return false }
        for case let host as UIView in bars.keyEnumerator().allObjects {
            guard let state = bars.object(forKey: host), state.bar == bar else { continue }
            if let plate = state.plate, let attached = plate.window,
               plate.superview === state.owner, !host.isHidden, !plate.isHidden,
               window == nil || attached === window { return true }
        }
        return false
    }

    /// A renamed host found through window discovery does not have its own
    /// layout hook. Reconcile only those fallback hosts when the window lays out.
    static func reconcileFallback(in window: UIView) {
        guard #available(iOS 26.0, *), enabled else { return }
        for case let host as UIView in bars.keyEnumerator().allObjects {
            guard let state = bars.object(forKey: host), state.fallback else { continue }
            guard let attached = host.window else {
                state.remove(); bars.removeObject(forKey: host); continue
            }
            if attached === window { update(host, state) }
        }
    }

    static func reapply() {
        guard #available(iOS 26.0, *), accessibilityObserver != nil else { return }
        // A missing key means native. An explicit choice from an older install
        // still works, but even explicit ON means bars only.
        enabled = ShrubifyLiquidGlass.isEnabled
            && isOnForCurrentDevice
            && !UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode")
            && !UIAccessibility.isReduceTransparencyEnabled
        for case let host as UIView in bars.keyEnumerator().allObjects {
            guard let state = bars.object(forKey: host) else { continue }
            if enabled, host.window != nil { update(host, state) } else { state.remove() }
        }
    }

    static func layout(_ bar: Bar, in host: UIView, fallback: Bool = false) {
        guard #available(iOS 26.0, *), accessibilityObserver != nil else { return }
        guard host.window != nil else {
            bars.object(forKey: host)?.remove()
            bars.removeObject(forKey: host)
            return
        }
        let state: State
        if let existing = bars.object(forKey: host) { state = existing }
        else { state = State(bar); state.fallback = fallback; bars.setObject(state, forKey: host) }
        if !fallback { state.fallback = false }
        // Remember the bar so Studio can apply a change immediately. When off,
        // don't inspect a single subview, allocate a material or mutate UIKit.
        if enabled { update(host, state) }
    }

    @available(iOS 26.0, *)
    private static func update(_ host: UIView, _ state: State) {
        // Never search a page-sized host, even if a future class name matches.
        guard (1...110).contains(host.bounds.height) else { state.remove(); return }
        let owner: UIView
        if let cached = state.owner, (cached === host || cached.isDescendant(of: host)), matches(cached, state.bar) { owner = cached }
        else {
            state.remove()
            guard let found = findOwner(in: host, bar: state.bar) else { return }
            owner = found
            state.owner = found
        }
        // Set layout margins before measuring the rendered capsule. UIKit
        // performs the actual row layout on its next normal layout pass.
        if state.bar == .tabs, let row = owner as? UIStackView {
            compactIfSupported(row, host: host, state: state)
        }
        let content: CGRect
        if state.bar == .tabs, let row = owner as? UIStackView {
            let items = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 }
            guard (2...6).contains(items.count) else { state.remove(); return }
            content = items.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: owner)) }
        } else { content = owner.bounds }
        guard let frame = NativeGlassGeometry.frame(bounds: owner.bounds, content: content, miniPlayer: state.bar == .miniPlayer)
        else { state.remove(); return }
        // A fallback and direct hook may discover the same owner. Restore the
        // outgoing backing before transfer, and never share ownership across windows.
        for case let otherHost as UIView in bars.keyEnumerator().allObjects {
            guard otherHost !== host, let other = bars.object(forKey: otherHost),
                  other.bar == state.bar, other.owner === owner else { continue }
            if state.fallback && !other.fallback {
                state.remove()
                return
            }
            other.remove()
            bars.removeObject(forKey: otherHost)
        }
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
        let plate = ShrubifyLiquidGlass.makePlate(radius: nil, interactive: false)
        plate.accessibilityIdentifier = "shrubify.native.glass.material"
        plate.isUserInteractionEnabled = false
        plate.accessibilityElementsHidden = true
        plate.frame = frame
        owner.insertSubview(plate, at: 0)
        state.plate = plate
        // Backing restoration is exact and reversible. Avoid painting a blur
        // underneath our single glass effect; that is the grey-slab failure.
        // Leave native hit regions and unrecognized content unchanged.
        for case let effect as UIVisualEffectView in owner.subviews
        where effect !== plate && effect.frame == owner.bounds && effect.contentView.subviews.isEmpty {
            state.clearBlur(effect)
        }
        clearBarBacking(around: owner, within: host, state: state)
    }

    /// Only the known native Spotify dock is eligible, and only when UIKit
    /// already owns equal-width arranged items. Unknown layouts stay untouched.
    private static func compactIfSupported(_ row: UIStackView, host: UIView, state: State) {
        let visible = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 }
        let hostName = NSStringFromClass(type(of: host))
        guard hostName.contains("TabBarView"), !hostName.contains("TabBarItem"),
              row.accessibilityIdentifier == "tabs-container-view-identifier",
              row.axis == .horizontal,
              row.distribution == .fillEqually,
              !row.traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
              (2...6).contains(visible.count) else {
            state.compactRow?.restore(); state.compactRow = nil; return
        }
        let inset = NativeGlassGeometry.compactHorizontalInset(width: row.bounds.width, count: visible.count)
        guard inset > 12 else { state.compactRow?.restore(); state.compactRow = nil; return }
        if state.compactRow?.row !== row {
            state.compactRow?.restore()
            state.compactRow = CompactRow(row)
        }
        guard let geometry = state.compactRow else { return }
        var margins = geometry.originalMargins
        margins.leading = max(margins.leading, inset)
        margins.trailing = max(margins.trailing, inset)
        // Do not compress hit targets in unusual layouts with large margins.
        guard row.bounds.width - margins.leading - margins.trailing >= CGFloat(visible.count) * 44 else {
            geometry.restore(); state.compactRow = nil; return
        }
        geometry.appliedMargins = margins
        if row.directionalLayoutMargins != margins { row.directionalLayoutMargins = margins }
        if !row.isLayoutMarginsRelativeArrangement { row.isLayoutMarginsRelativeArrangement = true }
        // Do not call layoutIfNeeded from a layout hook; next layout updates glass.
    }

    // A separate selected-item view was causing the huge grey oval, often
    // left at Home even when another page was active. The real Spotify
    // controls already have selected icon/label states. Don't draw an extra
    // backing until the tab-bar presenter can own selection atomically.

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
            if let material = root as? UIVisualEffectView {
                state.clearBlur(material)
                state.clearColor(material.contentView)
            }
            state.clearColor(root)
            for child in root.subviews where child !== state.plate && child !== owner {
                let name = NSStringFromClass(type(of: child))
                // Hide known tab-background elements even if their gradient
                // layers are wider than the bar. Do not suppress controls,
                // artwork, unknown SwiftUI containers, or unrelated content.
                let namedBackground = name.contains("TabBarGradientView")
                    || name.contains("TabBarBackgroundView")
                    || child.accessibilityIdentifier == "tabs-background-view-identifier"
                if namedBackground, !(child is UIControl), !(child is UIImageView) {
                    state.hide(child)
                }
            }
            if root === host { break }
            ancestor = root.superview
        }
    }
}

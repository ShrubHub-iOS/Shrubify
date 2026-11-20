import UIKit

/// Opt-in material behind the two native bottom bars. Only their layout hooks
/// supply hosts: no window discovery, cell lifecycle work or playback updates.
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
        var selection: UIView?
        var fallback = false
        var compactRow: CompactRow?
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
            compactRow?.restore(); compactRow = nil
            selection?.removeFromSuperview(); selection = nil
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

    /// True when this bar already carries a live native plate. The window-pass
    /// chrome asks this before mounting its fallback, because two owners on one
    /// bar double the material, the rim and the sheen — the "fake glass" look.
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
        if state.bar == .tabs, let row = owner as? UIStackView {
            compactIfSupported(row, host: host, state: state)
        }
        if let plate = state.plate {
            if plate.superview === owner {
                if plate.frame != frame { plate.frame = frame }
                updateSelection(in: owner, state: state)
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
        // One-time installation, not per-layout repainting. Leave content and
        // hit testing alone, including if a future build has unfamiliar chrome.
        for case let effect as UIVisualEffectView in owner.subviews
        where effect !== plate && effect.frame == owner.bounds && effect.contentView.subviews.isEmpty {
            state.clearBlur(effect)
        }
        clearBarBacking(around: owner, within: host, state: state)
        updateSelection(in: owner, state: state)
    }

    /// Only the known native Spotify dock is eligible, and only when UIKit
    /// already owns equal-width arranged items. Unknown layouts stay untouched.
    private static func compactIfSupported(_ row: UIStackView, host: UIView, state: State) {
        let visible = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 }
        guard NSStringFromClass(type(of: host)) == "NavigationUI_TabBarImpl.TabBarView",
              row.accessibilityIdentifier == "tabs-container-view-identifier",
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

    /// Track the real selected item without intercepting actions or adding
    /// another optical layer. When a build has no unique signal, remain neutral.
    private static func updateSelection(in owner: UIView, state: State) {
        guard state.bar == .tabs, let row = owner as? UIStackView else { return }
        let items = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 }
        let selected = items.filter {
            $0.accessibilityTraits.contains(.selected) || ($0 as? UIControl)?.isSelected == true
        }
        // Some Encore tabs signal selection only through a bright label.
        // Accept that signal only if exactly one item matches.
        let bright = selected.isEmpty ? items.filter { item in
            var nodes = [item]; var i = 0
            while i < nodes.count, i < 24 {
                let view = nodes[i]; i += 1
                if let label = view as? UILabel, let text = label.text, !text.isEmpty,
                   let color = label.textColor {
                    var white: CGFloat = 0; var alpha: CGFloat = 0
                    return color.resolvedColor(with: row.traitCollection).getWhite(&white, alpha: &alpha)
                        && white > 0.85 && alpha > 0.8
                }
                if nodes.count < 24 { nodes.append(contentsOf: view.subviews.prefix(24 - nodes.count)) }
            }
            return false
        } : []
        let picked = selected.count == 1 ? selected.first : (bright.count == 1 ? bright.first : nil)
        guard let item = picked else {
            state.selection?.removeFromSuperview(); state.selection = nil; return
        }
        let target = item.convert(item.bounds, to: row).insetBy(dx: 4, dy: 3)
        guard target.width > 0, target.height > 0 else { return }
        if let indicator = state.selection, indicator.superview === row {
            guard indicator.frame != target else { return }
            let update = { indicator.frame = target; indicator.layer.cornerRadius = min(target.height, target.width) / 2 }
            if UIAccessibility.isReduceMotionEnabled { update() }
            else { UIView.animate(withDuration: 0.23, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut], animations: update) }
        } else {
            let indicator = UIView(frame: target)
            indicator.accessibilityIdentifier = "shrubify.native.selection"
            indicator.isUserInteractionEnabled = false
            indicator.accessibilityElementsHidden = true
            indicator.backgroundColor = UIColor.label.withAlphaComponent(0.12)
            indicator.layer.cornerCurve = .continuous
            indicator.layer.cornerRadius = min(target.height, target.width) / 2
            row.insertSubview(indicator, at: min(1, row.subviews.count))
            state.selection = indicator
        }
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

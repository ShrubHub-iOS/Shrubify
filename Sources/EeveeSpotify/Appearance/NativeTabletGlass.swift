import UIKit

/// One native glass owner per recognized tablet bar. Only dedicated layout
/// hooks mount material; no window scanning or playback-control decoration.
@MainActor
enum NativeTabletGlass {
    nonisolated static let preferenceKey = "ShrubifyNativeTabletGlass"
    enum Bar { case tabs, miniPlayer }

    private static let bars = NSMapTable<UIView, State>.weakToStrongObjects()
    private static let wrapperBackings = NSMapTable<UIView, SharedBacking>.weakToStrongObjects()
    private static var accessibilityObserver: NSObjectProtocol?
    private static var glassObserver: NSObjectProtocol?
    private static var enabled = false

    @MainActor private final class SharedBacking {
        let bars = NSHashTable<State>.weakObjects()
        let state = State(.tabs)
    }

    @MainActor private final class State {
        let bar: Bar
        weak var owner: UIView?
        var plate: UIVisualEffectView?
        var selection: UIView?
        weak var glassContainer: UIView?
        weak var navigationRoot: UIView?
        weak var backingWrapper: UIView?
        var fallback = false
        weak var miniOwner: UIView?
        var compactRow: CompactRow?
        var geometryRetry: DispatchWorkItem?
        private weak var clippedHost: UIView?
        private var clippedFrame: CGRect?
        private var capsuleMask: CAShapeLayer?
        var restoreBacking: [() -> Void] = []
        // Repaint protection: Spotify sometimes redraws an already-cleared
        // background when switching tabs. The original state is captured once.
        private let colors = NSHashTable<UIView>.weakObjects()
        private let opacity = NSHashTable<UIView>.weakObjects()
        private let blurs = NSHashTable<UIVisualEffectView>.weakObjects()
        private let hidden = NSHashTable<UIView>.weakObjects()
        init(_ bar: Bar) { self.bar = bar }

        private static func hasFill(_ view: UIView) -> Bool {
            (view.backgroundColor?.cgColor.alpha ?? 0) > 0.001
                || (view.layer.backgroundColor?.alpha ?? 0) > 0.001
        }

        func clearColor(_ view: UIView) {
            guard Self.hasFill(view) else { return }
            if !colors.contains(view) {
                let originalColor = view.backgroundColor
                let originalLayer = view.layer.backgroundColor
                colors.add(view)
                restoreBacking.append { [weak view] in
                    guard let view, !Self.hasFill(view) else { return }
                    view.backgroundColor = originalColor
                    view.layer.backgroundColor = originalLayer
                }
            }
            view.backgroundColor = .clear
            if (view.layer.backgroundColor?.alpha ?? 0) > 0.001 {
                view.layer.backgroundColor = nil
            }
        }
        func clearOpacity(_ view: UIView) {
            if opacity.contains(view) {
                if view.isOpaque { view.isOpaque = false }
                return
            }
            guard view.isOpaque else { return }
            opacity.add(view)
            restoreBacking.append { [weak view] in
                guard let view, !view.isOpaque else { return }
                view.isOpaque = true
            }
            view.isOpaque = false
        }

        func clearBlur(_ view: UIVisualEffectView) {
            if blurs.contains(view) {
                if view.effect is UIBlurEffect { view.effect = nil }
                return
            }
            guard let blur = view.effect as? UIBlurEffect else { return }
            blurs.add(view)
            restoreBacking.append { [weak view] in if view?.effect == nil { view?.effect = blur } }
            view.effect = nil
        }
        func hide(_ view: UIView) {
            if hidden.contains(view) {
                if view.alpha != 0 { view.alpha = 0 }
                return
            }
            let alpha = view.alpha
            guard alpha > 0 else { return }
            hidden.add(view)
            restoreBacking.append { [weak view] in if view?.alpha == 0 { view?.alpha = alpha } }
            view.alpha = 0
        }
        func clip(_ host: UIView, to frame: CGRect) {
            if clippedHost !== host || host.layer.mask !== capsuleMask {
                restoreClip()
                // Spotify may already use a mask for a transition. Leave that
                // animation in charge rather than overwriting its shape.
                guard host.layer.mask == nil else { return }
                clippedHost = host
                let mask = CAShapeLayer()
                capsuleMask = mask
                host.layer.mask = mask
            }
            guard let capsuleMask, clippedFrame != frame || capsuleMask.frame != host.bounds else { return }
            clippedFrame = frame
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            capsuleMask.frame = host.bounds
            capsuleMask.path = UIBezierPath(roundedRect: frame,
                                            cornerRadius: min(frame.width, frame.height) / 2).cgPath
            CATransaction.commit()
        }

        private func restoreClip() {
            if let host = clippedHost, host.layer.mask === capsuleMask { host.layer.mask = nil }
            clippedHost = nil
            capsuleMask = nil
            clippedFrame = nil
        }

        func removeMaterial() {
            geometryRetry?.cancel()
            geometryRetry = nil
            restoreClip()
            plate?.removeFromSuperview(); plate = nil
            selection = nil
            glassContainer = nil
            NativeTabletGlass.releaseWrapper(for: self)
            restoreBacking.reversed().forEach { $0() }; restoreBacking.removeAll()
            colors.removeAllObjects(); opacity.removeAllObjects()
            blurs.removeAllObjects(); hidden.removeAllObjects()
        }
        func remove() {
            compactRow?.restore(); compactRow = nil
            removeMaterial()
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
            var margins = row.directionalLayoutMargins
            if margins.leading == appliedMargins.leading { margins.leading = originalMargins.leading }
            if margins.trailing == appliedMargins.trailing { margins.trailing = originalMargins.trailing }
            row.directionalLayoutMargins = margins
            row.isLayoutMarginsRelativeArrangement = originalRelative
            row.setNeedsLayout()
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

    static func materialSize(_ bar: Bar) -> CGSize? {
        guard #available(iOS 26.0, *), enabled, accessibilityObserver != nil else { return nil }
        for case let host as UIView in bars.keyEnumerator().allObjects {
            guard let state = bars.object(forKey: host), state.bar == bar else { continue }
            if let plate = state.plate, plate.window != nil,
               plate.superview === state.glassContainer, plate.effect is UIGlassEffect,
               !host.isHidden, !plate.isHidden { return plate.bounds.size }
        }
        return nil
    }

    /// Legacy fallback support remains bounded to explicit hosts; no window-scanning hooks are installed.
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
        // Use the effective preference so older installs keep their choice.
        enabled = ShrubifyLiquidGlass.isEnabled
            && isOnForCurrentDevice
            && !UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode")
            && !UIAccessibility.isReduceTransparencyEnabled
        for case let host as UIView in bars.keyEnumerator().allObjects {
            guard let state = bars.object(forKey: host) else { continue }
            if enabled, host.window != nil { update(host, state) } else { state.remove() }
        }
    }

    private static let navigationClass = NSClassFromString("_TtC23NavigationUI_TabBarImpl19TabBarContainerImpl")
    private static let tabViews = [
        "NavigationUI_TabBarImpl.TabBarView",
        "_TtC23NavigationUI_TabBarImpl10TabBarView",
        "NavigationUI_TabBarImpl.TabBarCompactView",
        "_TtC23NavigationUI_TabBarImpl17TabBarCompactView"
    ]

    static func layoutNavigation(in root: UIView) {
        guard root.window != nil else { return }
        var nodes = [root]
        var index = 0
        var compact: UIView?
        while index < nodes.count {
            let view = nodes[index]
            index += 1
            guard !view.isHidden, view.alpha > 0.5 else { continue }
            let name = NSStringFromClass(type(of: view))
            if tabViews.prefix(2).contains(name), (1...110).contains(view.bounds.height),
               findOwner(in: view, bar: .tabs) != nil {
                layout(.tabs, in: view, navigationRoot: root)
                return
            }
            if tabViews.suffix(2).contains(name), (1...110).contains(view.bounds.height),
               findOwner(in: view, bar: .tabs) != nil { compact = view }
            if !(view is UIScrollView || view is UIControl || view is UIImageView), nodes.count < 112 {
                nodes.append(contentsOf: view.subviews.prefix(112 - nodes.count))
            }
        }
        if let compact { layout(.tabs, in: compact, fallback: true, navigationRoot: root) }
    }

    static func layoutCompactTabs(in host: UIView) {
        guard enabled, let root = navigationRoot(for: host) else { return }
        if let tabBar = host.subviews.first(where: { tabViews.prefix(2).contains(NSStringFromClass(type(of: $0))) }) {
            layout(.tabs, in: tabBar, navigationRoot: root)
        } else {
            layout(.tabs, in: host, fallback: true, navigationRoot: root)
        }
    }

    static func layoutMiniControllerView(_ view: UIView) {
        // A content-controller callback and the page wrapper can both fire.
        // The wrapper owns the glass wherever it actually encloses this bar.
        let compactClassName = "_TtC22NowPlaying_BarPageImplP33_CCC0D2EEA6D4725EECD8965E8C38C86D20TouchPassthroughView"
        var node: UIView? = view
        for _ in 0..<5 {
            guard let candidate = node else { break }
            let name = NSStringFromClass(type(of: candidate))
            if name == compactClassName || name == "NowPlaying_BarPageImpl.TouchPassthroughView" {
                layout(.miniPlayer, in: candidate, miniOwner: view)
                return
            }
            node = candidate.superview
        }
        layout(.miniPlayer, in: view, fallback: true, miniOwner: view)
    }

    private static func navigationRoot(for host: UIView) -> UIView? {
        guard let navigationClass else { return nil }
        var responder: UIResponder? = host
        for _ in 0..<18 {
            guard let current = responder else { break }
            if let controller = current as? UIViewController, controller.isKind(of: navigationClass),
               let root = controller.viewIfLoaded, host.isDescendant(of: root) { return root }
            responder = current.next
        }
        return nil
    }

    static func layout(_ bar: Bar, in host: UIView, fallback: Bool = false, navigationRoot: UIView? = nil,
                       miniOwner: UIView? = nil) {
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
        if let miniOwner { state.miniOwner = miniOwner }
        if bar == .tabs, let root = navigationRoot ?? Self.navigationRoot(for: host),
           host.isDescendant(of: root) { state.navigationRoot = root }
        // Remember the bar so Studio can apply a change immediately. When off,
        // don't inspect a single subview, allocate a material or mutate UIKit.
        if enabled { update(host, state) }
    }

    @available(iOS 26.0, *)
    private static func update(_ host: UIView, _ state: State, canRetryGeometry: Bool = true) {
        // Never search a page-sized host, even if a future class name matches.
        guard !host.isHidden, host.alpha > 0.5,
              (1...110).contains(host.bounds.height) else { state.remove(); return }
        let owner: UIView
        if let cached = state.owner, (cached === host || cached.isDescendant(of: host)),
           !cached.isHidden, cached.alpha > 0.5,
           (matches(cached, state.bar) || cached === state.miniOwner) { owner = cached }
        else {
            state.remove()
            let controllerView = state.miniOwner.flatMap { candidate in
                (candidate === host || candidate.isDescendant(of: host)) && !candidate.isHidden
                    && (30...110).contains(candidate.bounds.height) ? candidate : nil
            }
            guard let found = findOwner(in: host, bar: state.bar) ?? controllerView else { return }
            owner = found
            state.owner = found
        }
        // Measure the same layout pass that applies the compact margins.
        // Waiting on a host callback can leave the old plate at split widths.
        if state.bar == .tabs, let row = owner as? UIStackView {
            compactIfSupported(row, host: host, state: state)
            row.layoutIfNeeded()
        }
        let content: CGRect
        let tabCount: Int?
        let tabs: [UIView]
        if state.bar == .tabs, let row = owner as? UIStackView {
            let items = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 1 }
            guard (2...6).contains(items.count) else {
                deferTabGeometry(in: host, state: state, canRetry: canRetryGeometry)
                return
            }
            let footprint = items.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: owner)) }
            if footprint.width <= CGFloat(items.count) * 82 + 40 {
                content = footprint
            } else if let visibleContent = visibleTabContent(items, in: owner) {
                content = visibleContent
            } else {
                deferTabGeometry(in: host, state: state, canRetry: canRetryGeometry)
                return
            }
            tabCount = items.count
            tabs = items
        } else {
            content = owner.bounds
            tabCount = nil
            tabs = []
        }
        guard let frame = NativeGlassGeometry.frame(
            bounds: owner.bounds, content: content, miniPlayer: state.bar == .miniPlayer,
            tabCount: tabCount
        ) else {
            // A just-compacted stack can report its pre-layout 825pt frames
            // for one pass. Do not tear down the margins before UIKit lays out.
            if state.bar == .tabs, state.compactRow != nil {
                deferTabGeometry(in: host, state: state, canRetry: canRetryGeometry)
                return
            }
            state.remove()
            return
        }
        state.geometryRetry?.cancel()
        state.geometryRetry = nil
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
        // Render below Spotify's entire native bar host, not inside its
        // internal UIStackView. This lets Liquid Glass sample the real page
        // rather than the host's opaque, prefrosted backdrop.
        let anchor = glassAnchor(for: host, in: state.navigationRoot)
        let container = anchor.superview ?? owner
        let converted = owner.convert(frame, to: container)
        guard converted.minX.isFinite, converted.minY.isFinite,
              converted.width.isFinite, converted.height.isFinite,
              converted.width >= 40, converted.height >= 20 else { state.remove(); return }
        let insertionSibling = anchor.superview === container ? anchor : nil
        if let plate = state.plate {
            if plate.superview === container {
                if plate.frame != converted { plate.frame = converted }
                if let sibling = insertionSibling, let index = container.subviews.firstIndex(of: plate),
                   container.subviews.dropFirst(index + 1).first !== sibling {
                    container.insertSubview(plate, belowSubview: sibling)
                }
                // Native Spotify backings may be repainted after navigation.
                // Clearing these views is idempotent and does not append
                // duplicate restoration closures across layout passes.
                clearBarBacking(around: owner, within: host, state: state)
                if state.bar == .tabs { state.clip(host, to: owner.convert(frame, to: host)) }
                placeSelection(in: plate, tabs: tabs, state: state)
                return
            }
            // A replaced bar must not retain the old glass or opaque backings.
            state.removeMaterial()
        }
        let plate = ShrubifyLiquidGlass.makePlate(radius: nil, interactive: false)
        plate.accessibilityIdentifier = "shrubify.native.glass.material"
        plate.isUserInteractionEnabled = false
        plate.accessibilityElementsHidden = true
        plate.frame = converted
        if let sibling = insertionSibling { container.insertSubview(plate, belowSubview: sibling) }
        else { container.insertSubview(plate, at: 0) }
        state.glassContainer = container
        state.plate = plate
        // Backing restoration is exact and reversible. Avoid painting a blur
        // underneath our single glass effect; that is the grey-slab failure.
        // Leave native hit regions and unrecognized content unchanged.
        clearBarBacking(around: owner, within: host, state: state)
        if state.bar == .tabs { state.clip(host, to: owner.convert(frame, to: host)) }
        placeSelection(in: plate, tabs: tabs, state: state)
    }

    @available(iOS 26.0, *)
    private static func deferTabGeometry(in host: UIView, state: State, canRetry: Bool) {
        guard canRetry else { state.removeMaterial(); return }
        guard state.geometryRetry == nil else { return }
        // UIKit can briefly report its pre-transition tab frames. Keep the
        // existing material through that pass, then require valid geometry.
        let retry = DispatchWorkItem { [weak host, weak state] in
            onMainThreadSync {
                guard let host, let state, host.window != nil, enabled else { return }
                state.geometryRetry = nil
                update(host, state, canRetryGeometry: false)
            }
        }
        state.geometryRetry = retry
        DispatchQueue.main.async(execute: retry)
    }

    /// Lift the plate out of compact wrappers owned by the tab controller.
    /// Stop before crossing into its scrolling content or another pane.
    private static func glassAnchor(for host: UIView, in root: UIView?) -> UIView {
        guard let root, host.isDescendant(of: root) else { return host }
        var anchor = host
        for _ in 0..<4 {
            guard let parent = anchor.superview, parent !== root,
                  !(parent is UIScrollView), parent.bounds.height <= 155,
                  parent.bounds.height >= anchor.bounds.height else { break }
            anchor = parent
        }
        return anchor
    }

    /// Only the known native Spotify dock is eligible, and only when UIKit
    /// already owns equal-width arranged items. Unknown layouts stay untouched.
    private static func compactIfSupported(_ row: UIStackView, host: UIView, state: State) {
        let visible = row.arrangedSubviews.filter { !$0.isHidden && $0.alpha > 0.01 }
        let hostName = NSStringFromClass(type(of: host))
        guard (hostName.contains("TabBarView") || hostName.contains("TabBarCompactView")),
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
        var margins = row.directionalLayoutMargins
        let symmetricInset = max(inset, max(geometry.originalMargins.leading, geometry.originalMargins.trailing))
        margins.leading = symmetricInset
        margins.trailing = symmetricInset
        // Do not compress hit targets in unusual layouts with large margins.
        guard row.bounds.width - margins.leading - margins.trailing >= CGFloat(visible.count) * 44 else {
            geometry.restore(); state.compactRow = nil; return
        }
        if row.directionalLayoutMargins != margins { row.directionalLayoutMargins = margins }
        if !row.isLayoutMarginsRelativeArrangement { row.isLayoutMarginsRelativeArrangement = true }
        geometry.appliedMargins = row.directionalLayoutMargins
        // The caller lays out only this verified child stack, never its host.
    }

    /// Some native rows keep wide layout slots after their icons and labels
    /// have already been centered. Measure those drawn items in that case.
    private static func visibleTabContent(_ items: [UIView], in row: UIView) -> CGRect? {
        var footprint = CGRect.null
        for item in items {
            var glyphs = CGRect.null
            var nodes = [item]
            var index = 0
            while index < nodes.count {
                let view = nodes[index]
                index += 1
                guard !view.isHidden, view.alpha > 0.01 else { continue }
                if (view is UILabel || view is UIImageView), view.bounds.width <= 128, view.bounds.height <= 64 {
                    let bounds = view.convert(view.bounds, to: row)
                    if bounds.width > 1, bounds.height > 1 { glyphs = glyphs.union(bounds) }
                }
                if nodes.count < 32 { nodes.append(contentsOf: view.subviews.prefix(32 - nodes.count)) }
            }
            guard !glyphs.isNull else { return nil }
            footprint = footprint.union(glyphs)
        }
        return footprint.insetBy(dx: -10, dy: -6).intersection(row.bounds)
    }

    private static func placeSelection(in plate: UIVisualEffectView, tabs: [UIView], state: State) {
        let signals = tabs.map { tab -> (UIView, Bool, Bool) in
            var nodes = [tab]
            var explicit = false
            var bright = false
            var index = 0
            while index < nodes.count {
                let node = nodes[index]
                index += 1
                guard !node.isHidden, node.alpha > 0.01 else { continue }
                explicit = explicit || node.accessibilityTraits.contains(.selected) || (node as? UIControl)?.isSelected == true
                if let label = node as? UILabel, let title = label.text, !title.isEmpty,
                   let color = label.textColor {
                    var white: CGFloat = 0
                    var alpha: CGFloat = 0
                    let resolved = color.resolvedColor(with: label.traitCollection)
                    bright = bright || (resolved.getWhite(&white, alpha: &alpha) && white >= 0.90 && alpha > 0.95)
                }
                if nodes.count < 28 { nodes.append(contentsOf: node.subviews.prefix(28 - nodes.count)) }
            }
            return (tab, explicit, bright)
        }
        let explicit = signals.filter { $0.1 }
        let candidates = explicit.isEmpty ? signals.filter { $0.2 } : explicit
        guard candidates.count == 1, let tab = candidates.first?.0 else {
            state.selection?.isHidden = true
            return
        }
        let item = tab.convert(tab.bounds, to: plate.contentView).intersection(plate.bounds)
        guard !item.isNull, item.width > 16, item.height > 16 else {
            state.selection?.isHidden = true
            return
        }
        let indicator = state.selection ?? UIView()
        if indicator.superview == nil {
            indicator.isUserInteractionEnabled = false
            indicator.accessibilityElementsHidden = true
            indicator.accessibilityIdentifier = "shrubify.native.selection"
            indicator.backgroundColor = UIColor.label.withAlphaComponent(0.16)
            indicator.layer.cornerCurve = .continuous
            plate.contentView.addSubview(indicator)
            state.selection = indicator
        }
        indicator.isHidden = false
        indicator.frame = item.insetBy(dx: 3, dy: 3)
        indicator.layer.cornerRadius = min(indicator.bounds.height, indicator.bounds.width) / 2
    }

    private static func matches(_ view: UIView, _ bar: Bar) -> Bool {
        if bar == .miniPlayer {
            let name = NSStringFromClass(type(of: view))
            return view.accessibilityIdentifier == "SPTNowPlayingBar"
                || (name.hasPrefix("NowPlaying_Bar") && name.hasSuffix(".NowPlayingBarView"))
        }
        guard let row = view as? UIStackView, row.axis == .horizontal,
              row.bounds.height <= 100, (2...6).contains(row.arrangedSubviews.count) else { return false }
        return row.accessibilityIdentifier == "tabs-container-view-identifier"
            || row.arrangedSubviews.filter { NSStringFromClass(type(of: $0)).contains("TabBarItem") }.count >= 2
    }

    private static func findOwner(in host: UIView, bar: Bar) -> UIView? {
        var nodes = [host]; var index = 0
        while index < nodes.count {
            let view = nodes[index]; index += 1
            guard !view.isHidden, view.alpha > 0.5 else { continue }
            if matches(view, bar) { return view }
            if !(view is UIScrollView || view is UIControl || view is UIImageView), nodes.count < 96 {
                nodes.append(contentsOf: view.subviews.prefix(96 - nodes.count))
            }
        }
        return nil
    }

    private static func clearBarBacking(around owner: UIView, within host: UIView, state: State) {
        for case let effect as UIVisualEffectView in owner.subviews
        where effect !== state.plate && effect.frame == owner.bounds && effect.contentView.subviews.isEmpty {
            state.clearBlur(effect)
        }
        var ancestor: UIView? = owner
        while let root = ancestor, root.bounds.height <= 110 {
            if let material = root as? UIVisualEffectView {
                state.clearBlur(material)
                state.clearColor(material.contentView)
                state.clearOpacity(material.contentView)
            }
            state.clearColor(root)
            state.clearOpacity(root)
            clearBackingChildren(of: root, protecting: owner, state: state)
            if root === host { break }
            ancestor = root.superview
        }
        if state.bar == .miniPlayer {
            var nodes = [owner]
            var index = 0
            while index < nodes.count {
                let view = nodes[index]
                index += 1
                let rect = view.convert(view.bounds, to: owner)
                guard rect.width >= owner.bounds.width * 0.82,
                      rect.height >= owner.bounds.height * 0.67,
                      rect.height <= 110, !(view is UIControl || view is UIImageView || view is UIScrollView)
                else { continue }
                state.clearColor(view)
                state.clearOpacity(view)
                if let effect = view as? UIVisualEffectView { state.clearBlur(effect) }
                clearBackingChildren(of: view, protecting: owner, state: state)
                if nodes.count < 24 {
                    nodes.append(contentsOf: view.subviews.filter { $0 !== state.plate }.prefix(24 - nodes.count))
                }
            }
        }
        // Some split layouts put the rectangular fill on a shared bar-height
        // wrapper that is wider than either bar. Clear its fill and known
        // decorative children without changing the sibling player controls.
        if let wrapper = host.superview,
           (30...130).contains(wrapper.bounds.height),
           wrapper.bounds.width >= host.bounds.width {
            if state.backingWrapper !== wrapper { releaseWrapper(for: state) }
            let backing = wrapperBackings.object(forKey: wrapper) ?? SharedBacking()
            wrapperBackings.setObject(backing, forKey: wrapper)
            backing.bars.add(state)
            state.backingWrapper = wrapper
            backing.state.clearColor(wrapper)
            backing.state.clearOpacity(wrapper)
            if let effect = wrapper as? UIVisualEffectView {
                backing.state.clearBlur(effect)
                backing.state.clearColor(effect.contentView)
            }
            clearBackingChildren(of: wrapper, protecting: host, state: backing.state)
        } else {
            releaseWrapper(for: state)
        }
        if let root = state.navigationRoot, host.isDescendant(of: root) {
            let hostFrame = host.convert(host.bounds, to: root)
            var branch = host
            for _ in 0..<6 {
                guard let parent = branch.superview else { break }
                if parent !== root, (1...155).contains(parent.bounds.height), parent !== host.superview {
                    state.clearColor(parent)
                    state.clearOpacity(parent)
                    if let material = parent as? UIVisualEffectView { state.clearBlur(material) }
                }
                for child in parent.subviews where child !== branch && child !== state.plate {
                    guard child.accessibilityIdentifier != "shrubify.native.glass.material" else { continue }
                    if #available(iOS 26.0, *), (child as? UIVisualEffectView)?.effect is UIGlassEffect { continue }
                    let frame = child.convert(child.bounds, to: root)
                    guard frame.intersects(hostFrame), frame.width >= hostFrame.width * 0.7 else { continue }
                    guard !(child is UIStackView || child is UIScrollView) else { continue }
                    let name = NSStringFromClass(type(of: child))
                    let named = name.contains("TabBarGradientView") || name.contains("TabBarBackgroundView")
                    let fillsBand = (child is UIVisualEffectView || type(of: child) == UIView.self)
                        && frame.height <= 155 && frame.height >= hostFrame.height * 0.7
                    if (named || fillsBand), !containsNativeContent(child) { state.hide(child) }
                }
                if parent === root { break }
                branch = parent
            }
        }
    }

    private static func releaseWrapper(for state: State) {
        guard let wrapper = state.backingWrapper else { return }
        state.backingWrapper = nil
        guard let backing = wrapperBackings.object(forKey: wrapper) else { return }
        backing.bars.remove(state)
        if backing.bars.allObjects.isEmpty {
            backing.state.removeMaterial()
            wrapperBackings.removeObject(forKey: wrapper)
        }
    }

    private static func clearBackingChildren(of root: UIView, protecting owner: UIView, state: State) {
        for child in root.subviews where child !== state.plate && child !== owner {
            let name = NSStringFromClass(type(of: child))
            let namedBackground = name.contains("TabBarGradientView")
                || name.contains("TabBarBackgroundView")
                || child.accessibilityIdentifier == "tabs-background-view-identifier"
            let occupiesBar = (child is UIVisualEffectView || type(of: child) == UIView.self)
                && child.bounds.width >= root.bounds.width * 0.8 && child.bounds.height >= root.bounds.height * 0.8
                && child.frame.intersects(root.bounds)
            if (namedBackground || occupiesBar), !owner.isDescendant(of: child), !containsNativeContent(child) {
                state.hide(child)
            }
        }
    }
    /// A private Spotify background wrapper can contain decorative subviews;
    /// never hide it if there is a real control or artwork inside.
    private static func containsNativeContent(_ view: UIView) -> Bool {
        var nodes = [view]
        var index = 0
        while index < nodes.count, index < 80 {
            let item = nodes[index]
            index += 1
            if item is UIControl || item is UIImageView || item is UILabel || item.isAccessibilityElement { return true }
            guard item.subviews.count <= 80 - nodes.count else { return true }
            nodes.append(contentsOf: item.subviews)
        }
        return false
    }

}

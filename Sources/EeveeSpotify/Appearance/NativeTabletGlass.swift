import UIKit
#if canImport(EeveeSpotifyC)
import EeveeSpotifyC
#endif

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
    private static var applyingLayout = false
    static let miniWrapperClass = "_TtC22NowPlaying_BarPageImplP33_CCC0D2EEA6D4725EECD8965E8C38C86D20TouchPassthroughView"

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
        var restoreBacking: [() -> Void] = []
        // Repaint protection: Spotify sometimes redraws an already-cleared
        // background when switching tabs. The original state is captured once.
        private let colors = NSHashTable<UIView>.weakObjects()
        private let opacity = NSHashTable<UIView>.weakObjects()
        private let blurs = NSHashTable<UIVisualEffectView>.weakObjects()
        private let hidden = NSHashTable<UIView>.weakObjects()
        private weak var roundedMini: UIView?
        private var restoreMiniCorners: (() -> Void)?
        private weak var miniProgress: UIView?
        private var originalProgressTransform: CGAffineTransform?
        private var appliedProgressTransform: CGAffineTransform?
#if canImport(EeveeSpotifyC)
        private let attemptedMiniFills = NSHashTable<UIView>.weakObjects()
        private var miniFills: [MiniFill] = []
#endif
        init(_ bar: Bar) { self.bar = bar }

        private static func hasFill(_ view: UIView) -> Bool {
            (view.backgroundColor?.cgColor.alpha ?? 0) > 0.001
                || (view.layer.backgroundColor?.alpha ?? 0) > 0.001
        }

        func clearColor(_ view: UIView) {
#if canImport(EeveeSpotifyC)
            if miniFills.contains(where: { $0.view === view }) { return }
#endif
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

        func suppressMiniFill(_ view: UIView) {
#if canImport(EeveeSpotifyC)
            // Spotify writes the artwork color after layout as well as within
            // it. Reuse the existing per-layer interceptor on the actual bar.
            guard let id = view.accessibilityIdentifier, id == "SPTNowPlayingBar" || id == "now-playing-bar-content",
                  !attemptedMiniFills.contains(view) else { return }
            attemptedMiniFills.add(view)
            miniFills.removeAll { $0.view == nil }
            let fill = MiniFill(view)
            if EeveeInterceptBackground(view, { fill.latest = $0 }) { miniFills.append(fill) }
#endif
        }

        func containMiniContent(in view: UIView) {
            if roundedMini !== view {
                restoreMiniCorners?()
                roundedMini = view
                let radius = view.layer.cornerRadius
                let curve = view.layer.cornerCurve
                let clipped = view.clipsToBounds
                restoreMiniCorners = { [weak view] in
                    view?.layer.cornerRadius = radius
                    view?.layer.cornerCurve = curve
                    view?.clipsToBounds = clipped
                }
            }
            let radius = NativeGlassGeometry.miniRadius(for: view.bounds.size)
            if view.layer.cornerRadius != radius { view.layer.cornerRadius = radius }
            if view.layer.cornerCurve != .continuous { view.layer.cornerCurve = .continuous }
            if !view.clipsToBounds { view.clipsToBounds = true }
        }

        func insetMiniProgress(_ rail: UIView) {
            if miniProgress !== rail {
                restoreProgress()
                miniProgress = rail
                originalProgressTransform = rail.transform
            }
            guard let originalProgressTransform, originalProgressTransform.isIdentity, rail.bounds.width > 64,
                  rail.transform.isIdentity || rail.transform == appliedProgressTransform else { return }
            let wideEnough = (rail.bounds.width - 34) / rail.bounds.width
            let transform = CGAffineTransform(translationX: 0, y: -4).scaledBy(x: wideEnough, y: 1)
            if rail.transform != transform { rail.transform = transform }
            appliedProgressTransform = transform
        }

        private func restoreProgress() {
            if let rail = miniProgress, let originalProgressTransform, rail.transform == appliedProgressTransform {
                rail.transform = originalProgressTransform
            }
            miniProgress = nil
            originalProgressTransform = nil
            appliedProgressTransform = nil
        }

        func removeMaterial() {
            geometryRetry?.cancel()
            geometryRetry = nil
            plate?.removeFromSuperview(); plate = nil
            restoreMiniCorners?()
            restoreMiniCorners = nil
            roundedMini = nil
            restoreProgress()
            selection = nil
            glassContainer = nil
            NativeTabletGlass.releaseWrapper(for: self)
            restoreBacking.reversed().forEach { $0() }; restoreBacking.removeAll()
#if canImport(EeveeSpotifyC)
            for fill in miniFills {
                guard let view = fill.view else { continue }
                EeveeRestoreBackground(view)
                view.backgroundColor = fill.latest
            }
            miniFills.removeAll()
            attemptedMiniFills.removeAllObjects()
#endif
            colors.removeAllObjects(); opacity.removeAllObjects()
            blurs.removeAllObjects(); hidden.removeAllObjects()
        }
        func remove() {
            compactRow?.restore(); compactRow = nil
            removeMaterial()
            owner = nil
        }
    }

#if canImport(EeveeSpotifyC)
    private final class MiniFill: @unchecked Sendable {
        weak var view: UIView?
        var latest: UIColor?

        @MainActor init(_ view: UIView) { self.view = view; latest = view.backgroundColor }
    }
#endif

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
        var standard: UIView?
        var compact: UIView?
        var mini: UIView?
        while index < nodes.count {
            let view = nodes[index]
            index += 1
            guard !view.isHidden, view.alpha > 0.5 else { continue }
            let name = NSStringFromClass(type(of: view))
            if standard == nil, tabViews.prefix(2).contains(name), (1...110).contains(view.bounds.height),
               findOwner(in: view, bar: .tabs) != nil {
                standard = view
            }
            if tabViews.suffix(2).contains(name), (1...110).contains(view.bounds.height),
               findOwner(in: view, bar: .tabs) != nil { compact = view }
            if mini == nil, view.accessibilityIdentifier == "SPTNowPlayingBar", matches(view, .miniPlayer) {
                mini = view
            }
            if standard != nil, mini != nil { break }
            if !(view is UIScrollView || view is UIControl || view is UIImageView), nodes.count < 112 {
                nodes.append(contentsOf: view.subviews.prefix(112 - nodes.count))
            }
        }
        if let standard { layout(.tabs, in: standard, navigationRoot: root) }
        else if let compact { layout(.tabs, in: compact, fallback: true, navigationRoot: root) }
        if let mini { layoutMiniControllerView(mini, isContentController: false) }
    }

    static func layoutCompactTabs(in host: UIView) {
        guard enabled, let root = navigationRoot(for: host) else { return }
        if let tabBar = host.subviews.first(where: { tabViews.prefix(2).contains(NSStringFromClass(type(of: $0))) }) {
            layout(.tabs, in: tabBar, navigationRoot: root)
        } else {
            layout(.tabs, in: host, fallback: true, navigationRoot: root)
        }
    }

    static func layoutMiniWrapper(_ view: UIView) {
        if view.window == nil {
            for case let host as UIView in bars.keyEnumerator().allObjects
            where host === view || host.isDescendant(of: view) {
                guard let state = bars.object(forKey: host), state.bar == .miniPlayer else { continue }
                state.remove()
                bars.removeObject(forKey: host)
            }
        } else if (30...110).contains(view.bounds.height) {
            layout(.miniPlayer, in: view)
        } else {
            layoutMiniControllerView(view, isContentController: false)
        }
    }

    static func layoutMiniControllerView(_ view: UIView, isContentController: Bool = true) {
        guard view.window != nil else { layout(.miniPlayer, in: view, fallback: true); return }
        let owner: UIView
        if let found = findOwner(in: view, bar: .miniPlayer) { owner = found }
        else if isContentController && (30...110).contains(view.bounds.height) { owner = view }
        else { return }
        // A content-controller callback and the page wrapper can both fire.
        // The wrapper owns glass only if it is itself bar-sized. The split
        // page can use the same passthrough class for the entire right pane.
        var node: UIView? = owner
        for _ in 0..<5 {
            guard let candidate = node else { break }
            let name = NSStringFromClass(type(of: candidate))
            if (name == miniWrapperClass || name == "NowPlaying_BarPageImpl.TouchPassthroughView"),
               (30...110).contains(candidate.bounds.height) {
                layout(.miniPlayer, in: candidate, miniOwner: owner)
                return
            }
            node = candidate.superview
        }
        layout(.miniPlayer, in: owner, fallback: true, miniOwner: owner)
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
#if canImport(EeveeSpotifyC)
        if bar == .miniPlayer, let source = state.owner ?? miniOwner ?? findOwner(in: host, bar: .miniPlayer) {
            ResponsivePlayer.rememberMiniArtwork(in: source)
        }
#endif
        if bar == .tabs, let root = navigationRoot ?? Self.navigationRoot(for: host),
           host.isDescendant(of: root) { state.navigationRoot = root }
        // Remember the bar so Studio can apply a change immediately. When off,
        // don't inspect a single subview, allocate a material or mutate UIKit.
        if enabled { update(host, state) }
    }

    @available(iOS 26.0, *)
    private static func update(_ host: UIView, _ state: State, canRetryGeometry: Bool = true) {
        guard !applyingLayout else { return }
        applyingLayout = true
        defer { applyingLayout = false }
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
        // Transfer ownership before capturing margins or reading geometry. A
        // second layout hook must never snapshot the first hook's compact row.
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
        // Measure the same layout pass that applies the compact margins.
        // Waiting on a host callback can leave the old plate at split widths.
        let external = (state.bar == .tabs ? owner as? UIStackView : nil).map { siblingTabItems(of: $0, host: host) }
        if state.bar == .tabs, let row = owner as? UIStackView, external?.items.isEmpty != false {
            compactIfSupported(row, host: host, state: state)
            row.layoutIfNeeded()
        } else if let compact = state.compactRow {
            compact.restore()
            state.compactRow = nil
        }
        let content: CGRect
        let tabCount: Int?
        let tabs: [UIView]
        let geometryOwner: UIView
        if state.bar == .tabs, let row = owner as? UIStackView {
            let extraItems = external?.items ?? []
            geometryOwner = extraItems.isEmpty ? owner : (external?.root ?? host)
            let items = (extraItems.isEmpty ? row.arrangedSubviews : row.arrangedSubviews.filter { !$0.isHidden }) + extraItems
            guard (2...6).contains(items.count) else {
                deferTabGeometry(in: host, state: state, canRetry: canRetryGeometry)
                return
            }
            let footprint = items.reduce(CGRect.null) { $0.union($1.convert($1.bounds, to: geometryOwner)) }
            if let margins = state.compactRow?.appliedMargins {
                content = owner.bounds.insetBy(dx: margins.leading, dy: 0)
            } else if !extraItems.isEmpty, let measured = visibleTabContent(items, in: geometryOwner) {
                content = measured
            } else if let centered = NativeGlassGeometry.centeredContent(footprint, in: owner.bounds),
                      centered.width <= CGFloat(items.count) * 82 + 40 {
                content = centered
            } else if let measured = visibleTabContent(items, in: owner),
                      let centered = NativeGlassGeometry.centeredContent(measured, in: owner.bounds) {
                content = centered
            } else {
                deferTabGeometry(in: host, state: state, canRetry: canRetryGeometry)
                return
            }
            tabCount = items.count
            tabs = items
        } else {
            geometryOwner = owner
            content = owner.bounds
            tabCount = nil
            tabs = []
        }
        guard let frame = NativeGlassGeometry.frame(
            bounds: geometryOwner.bounds, content: content, miniPlayer: state.bar == .miniPlayer,
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
        // The dock sits above the page and below its wrapper. The mini-player
        // has its own paint stack, so keep material inside the bar under its controls.
        let anchor = glassAnchor(for: host, in: state.navigationRoot)
        let container = state.bar == .miniPlayer ? owner : (anchor.superview ?? owner)
        let converted = geometryOwner.convert(frame, to: container)
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
                } else if state.bar == .miniPlayer, container.subviews.first !== plate {
                    container.insertSubview(plate, at: 0)
                }
                // Native Spotify backings may be repainted after navigation.
                // Clearing these views is idempotent and does not append
                // duplicate restoration closures across layout passes.
                clearBarBacking(around: owner, within: host, state: state)
                placeSelection(in: plate, tabs: tabs, state: state)
                return
            }
            // A replaced bar must not retain the old glass or opaque backings.
            state.removeMaterial()
        }
        let radius = state.bar == .miniPlayer ? NativeGlassGeometry.miniRadius(for: frame.size) : nil
        let plate = ShrubifyLiquidGlass.makePlate(radius: radius, interactive: false, prefersReadableGlass: true)
        if state.bar == .miniPlayer { plate.overrideUserInterfaceStyle = .dark }
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
        // Spotify temporarily hides Home while attaching Now Playing. Keep
        // the dock anchored to its full set of slots through that animation.
        let tabCount = row.arrangedSubviews.count
        let hostName = NSStringFromClass(type(of: host))
        guard (hostName.contains("TabBarView") || hostName.contains("TabBarCompactView")),
              row.axis == .horizontal,
              row.distribution == .fillEqually,
              !row.traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
              (2...6).contains(tabCount) else {
            state.compactRow?.restore(); state.compactRow = nil; return
        }
        let inset = NativeGlassGeometry.compactHorizontalInset(width: row.bounds.width, count: tabCount)
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
        guard row.bounds.width - margins.leading - margins.trailing >= CGFloat(tabCount) * 44 else {
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
            guard let glyphs = tabGlyphs(item, in: row) else { return nil }
            footprint = footprint.union(glyphs)
        }
        return footprint.insetBy(dx: -10, dy: -6).intersection(row.bounds)
    }

    private static func tabGlyphs(_ item: UIView, in parent: UIView) -> CGRect? {
        var footprint = CGRect.null
        var nodes = [item]
        var index = 0
        while index < nodes.count {
            let view = nodes[index]
            index += 1
            guard !view.isHidden, view.alpha > 0.5 else { continue }
            if (view is UILabel || view is UIImageView), view.bounds.width <= 128, view.bounds.height <= 64 {
                let bounds = view.convert(view.bounds, to: parent)
                if bounds.width > 1, bounds.height > 1 { footprint = footprint.union(bounds) }
            }
            nodes.append(contentsOf: view.subviews.prefix(32 - nodes.count))
        }
        return footprint.isNull ? nil : footprint
    }

    private static func placeSelection(in plate: UIVisualEffectView, tabs: [UIView], state: State) {
        let visible = tabs.filter { !$0.isHidden && $0.alpha > 0.5 }
        let selected = visible.filter { tab in
            var nodes = [tab]
            var index = 0
            while index < nodes.count {
                let node = nodes[index]
                index += 1
                guard !node.isHidden, node.alpha > 0.01 else { continue }
                if node.accessibilityTraits.contains(.selected) || (node as? UIControl)?.isSelected == true { return true }
                if nodes.count < 28 { nodes.append(contentsOf: node.subviews.prefix(28 - nodes.count)) }
            }
            return false
        }
        guard selected.count == 1, let tab = selected.first else {
            state.selection?.isHidden = true
            return
        }
        let center = tabGlyphs(tab, in: plate.contentView)?.midX ?? tab.convert(tab.bounds, to: plate.contentView).midX
        let width = min(78, plate.bounds.width / CGFloat(max(visible.count, 1))) - 6
        guard let item = NativeGlassGeometry.selectionFrame(centerX: center, width: width, in: plate.bounds) else {
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
        indicator.frame = item
        indicator.layer.cornerRadius = min(indicator.bounds.height, indicator.bounds.width) / 2
    }

    private static func siblingTabItems(of row: UIStackView, host: UIView) -> (root: UIView, items: [UIView]) {
        var root = host
        if let wrapper = host.superview, wrapper.bounds.height <= 120 { root = wrapper }
        var queue = [root]
        var index = 0
        var items: [UIView] = []
        let band = row.convert(row.bounds, to: root)
        while index < queue.count, items.count < 2 {
            let view = queue[index]; index += 1
            guard view !== row, !view.isHidden, view.alpha > 0.5 else { continue }
            let name = NSStringFromClass(type(of: view))
            let rect = view.convert(view.bounds, to: root)
            if name.contains("TabBarItem"), (34...180).contains(rect.width), (30...100).contains(rect.height),
               abs(rect.midY - band.midY) < 12, view.isUserInteractionEnabled {
                items.append(view)
                continue
            }
            if !(view is UIScrollView || view is UIImageView) { queue.append(contentsOf: view.subviews.prefix(100 - queue.count)) }
        }
        return (root, items)
    }

    private static func matches(_ view: UIView, _ bar: Bar) -> Bool {
        if bar == .miniPlayer {
            guard (30...110).contains(view.bounds.height), view.bounds.width >= 140 else { return false }
            let name = NSStringFromClass(type(of: view))
            return view.accessibilityIdentifier == "SPTNowPlayingBar"
                || (name.contains("NowPlaying_Bar")
                    && (name.hasSuffix("NowPlayingBarView") || name.hasSuffix("NowPlayingBarTopStack")))
        }
        guard let row = view as? UIStackView, row.axis == .horizontal,
              row.bounds.height <= 100, (2...6).contains(row.arrangedSubviews.count) else { return false }
        return row.accessibilityIdentifier == "tabs-container-view-identifier"
            || row.arrangedSubviews.filter { NSStringFromClass(type(of: $0)).contains("TabBarItem") }.count >= 2
    }

    private static func findOwner(in host: UIView, bar: Bar) -> UIView? {
        var nodes = [host]; var index = 0
        var miniCandidate: UIView?
        while index < nodes.count {
            let view = nodes[index]; index += 1
            guard !view.isHidden, view.alpha > 0.5 else { continue }
            if matches(view, bar) {
                if bar == .tabs || view.accessibilityIdentifier == "SPTNowPlayingBar" { return view }
                if miniCandidate == nil { miniCandidate = view }
            }
            if !(view is UIScrollView || view is UIControl || view is UIImageView), nodes.count < 96 {
                nodes.append(contentsOf: view.subviews.prefix(96 - nodes.count))
            }
        }
        return miniCandidate
    }

    private static func clearBarBacking(around owner: UIView, within host: UIView, state: State) {
        if state.bar == .miniPlayer {
            state.suppressMiniFill(owner)
            state.containMiniContent(in: owner)
        }
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
                if view.accessibilityIdentifier == "now-playing-bar-duration" {
                    state.insetMiniProgress(view)
                    continue
                }
                let rect = view.convert(view.bounds, to: owner)
                guard rect.width >= owner.bounds.width * 0.82,
                      rect.height >= owner.bounds.height * 0.67,
                      rect.height <= 110, !(view is UIControl || view is UIImageView || view is UIScrollView)
                else { continue }
                state.suppressMiniFill(view)
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

import UIKit
import QuartzCore

/// Liquid Glass for the surfaces Spotify still draws itself.
///
/// Three failures this file exists to prevent:
/// 1. the iPad player was deliberately left native, so custom-interface chrome
///    never reached it;
/// 2. a single class-name hook silently dies when Spotify renames a class; and
/// 3. two owners drawing the same bar double the material, the rim and the
///    specular sheen — which is what made the tab bar look like a plastic
///    imitation instead of glass.
///
/// So: the bottom bars are owned by `NativeTabletGlass` (real `UIGlassEffect`
/// at their own layout hooks) whenever it can mount; this pass only fills in
/// for them. The player is owned here, anchored on the transport keys, because
/// nothing else touches it on iPad.
///
/// Nothing Spotify owns is resized, cleared or given a different hit region:
/// every plate is decorative, hidden from accessibility and inserted below the
/// content it belongs to.
@MainActor
enum ShrubifyGlassChrome {

    enum Surface: CaseIterable {
        /// Fallbacks only: `NativeTabletGlass` gets first refusal on both bars.
        case tabs
        case miniPlayer
        /// One card behind the player's bottom block (title, progress, keys).
        case playerCard

        /// Also the plate's accessibility identifier, so the owners can
        /// recognise each other's work.
        var identifier: String {
            switch self {
            case .tabs: return "shrubify.glass.chrome.tabs"
            case .miniPlayer: return "shrubify.glass.chrome.mini"
            case .playerCard: return "shrubify.glass.chrome.player"
            }
        }

        var title: String {
            switch self {
            case .tabs: return "Tab bar"
            case .miniPlayer: return "Mini-player"
            case .playerCard: return "Player"
            }
        }

        var radius: CGFloat {
            switch self {
            case .tabs, .miniPlayer: return 30   // capsule: half of 60
            case .playerCard: return 34
            }
        }

        var isBottomBar: Bool {
            self == .tabs || self == .miniPlayer
        }
    }

    private struct Candidate {
        let host: UIView
        let anchors: [UIView]
        /// Positive shrinks, negative grows, in host coordinates.
        let inset: CGSize
    }

    private struct Mount {
        let surface: Surface
        let plate: ShrubifyGlassPlate
        weak var host: UIView?
        let anchors: [UIView]
        let inset: CGSize
        /// Spotify views this plate had to clear, with an exact undo for each.
        let restorations: [() -> Void]
    }

    /// One decorative circle per player control, so the keys carry glass too
    /// instead of one plate sitting behind the whole row.
    private struct KeyMount {
        let plate: ShrubifyGlassPlate
        weak var host: UIView?
        weak var control: UIView?
        let outset: CGFloat
    }

    /// The dedicated bar backing names its plate with this prefix.
    private static let nativeBarPlate = "shrubify.native.glass"
    private static let chromePrefix = "shrubify.glass.chrome."
    private static let keyPlatePrefix = "shrubify.glass.chrome.key."
    /// Spotify's chrome is near-black; the neutral material needs a nudge there.
    /// It used to be 1.85, which turned the whole plate into a white wash.
    private static let chromeBoost: CGFloat = 1.35
    private static let playerBoost: CGFloat = 1.15
    private static let keyBoost: CGFloat = 1.05

    private static let tabItemPrefix = "TabBar.Item."

    /// The transport keys keep their identifiers across redesigns, which is why
    /// they are the anchor for everything in the player.
    private static let playButtonID = "SPTNowPlayingPlayButton"
    private static let previousButtonID = "SPTNowPlayingPreviousTrackButton"
    private static let nextButtonID = "SPTNowPlayingNextTrackButton"
    private static let sliderID = "SPTNowPlayingSliderV2"
    private static let lyricsButtonID = "lyrics-expand-button"
    private static let minimizeButtonID = "now-playing-minimize-button"
    private static let contextMenuID = "Context menu"

    private static var mounts: [Mount] = []
    private static var keyMounts: [KeyMount] = []
    private static var observers: [NSObjectProtocol] = []
    private static var timer: Timer?
    private static var lastPass: CFTimeInterval = 0
    private static var lastPlayerPass: CFTimeInterval = 0
    private static var remainingScans = 12
    private static var didReport = false
    /// How many window scans may still run this session. The player has its own
    /// layout hook, so the scan is only a fallback and must not become a
    /// permanent background walk.
    private static var discoveryBudget = 40
    private static var pageScanAllowance = 60
    /// Card attempts are bounded too: a build whose control block never fits
    /// the shape guard must not keep the page scan alive forever.
    private static var cardAttempts = 80

    private static let maxNodes = 2600
    private static let maxPlayerNodes = 1800
    private static let maxDepth = 24
    private static let passInterval: CFTimeInterval = 0.5
    private static let playerPassInterval: CFTimeInterval = 0.35
    private static let tickInterval: TimeInterval = 2.0

    static var isSupported: Bool { EvolvedInterfaceAvailability.usesNativeTabletInterface }

    static func start() {
        registerObserversIfNeeded()
        guard timer == nil else { return }
        // The bars exist at launch; the player only after it opens. A slow tick
        // keeps the plates in step and stops walking the tree once the bars are
        // settled (the player has its own layout hook).
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            onMainThreadSync { tick() }
        }
    }

    private static func registerObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        for name in [
            Notification.Name.shrubifyLiquidGlassDidChange,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIApplication.didBecomeActiveNotification,
            UIScene.didActivateNotification,
        ] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { _ in
                    onMainThreadSync { rearm() }
                }
            )
        }
    }

    /// Look again: a surface may have just appeared (new player, new window).
    static func rearm() {
        guard isSupported else { return }
        remainingScans = max(remainingScans, 6)
        discoveryBudget = max(discoveryBudget, 20)
        cardAttempts = max(cardAttempts, 20)
        refresh()
        start()
    }

    private static func tick() {
        guard isSupported else { return }
        guard ShrubifyLiquidGlass.isEnabled, !UIAccessibility.isReduceTransparencyEnabled else {
            removeAll()
            return
        }
        prune()
        relayout()
        // Nothing missing: no tree walk, just keep the plates in step.
        guard needsDiscovery, discoveryBudget > 0 else { return }
        remainingScans = max(remainingScans, 1)
        guard let window = keyWindow() else { return }
        pass(in: window)
    }

    /// A surface that is neither mounted nor owned natively is still missing.
    private static var needsDiscovery: Bool {
        Surface.allCases.contains { surface in
            guard !isOwned(surface) else { return false }
            return !mounts.contains { $0.surface == surface && $0.host?.window != nil }
        }
    }

    /// The native bottom bars have first refusal: one material per bar.
    private static func isOwned(_ surface: Surface) -> Bool {
        switch surface {
        case .tabs: return NativeTabletGlass.owns(.tabs)
        case .miniPlayer: return NativeTabletGlass.owns(.miniPlayer)
        case .playerCard: return false
        }
    }

    /// Called from the window's layout hook. Cheap unless the interval elapsed.
    static func pass(in window: UIView) {
        guard isSupported, window.bounds.width > 200 else { return }
        let now = CACurrentMediaTime()
        guard now - lastPass >= passInterval else { return }
        lastPass = now

        guard ShrubifyLiquidGlass.isEnabled, !UIAccessibility.isReduceTransparencyEnabled else {
            removeAll()
            return
        }

        if remainingScans > 0, discoveryBudget > 0 {
            remainingScans -= 1
            discoveryBudget -= 1
            var nodes: [UIView] = []
            collect(window, limit: maxNodes, into: &nodes)
            for surface in Surface.allCases where !isOwned(surface) && surface.isBottomBar {
                guard !mounts.contains(where: { $0.surface == surface && $0.host?.window != nil })
                else { continue }
                mount(surface, with: candidate(surface, in: nodes))
            }
            mountPlayer(from: nodes)
        }
        relayout()
    }

    /// Called from the player's own layout hook — no window walk, so the player
    /// is found even on a build whose tree is deeper than the window scan.
    static func playerLayout(in unit: UIView) {
        guard isSupported, unit.window != nil else { return }
        guard ShrubifyLiquidGlass.isEnabled, !UIAccessibility.isReduceTransparencyEnabled else {
            removeAll()
            return
        }
        let now = CACurrentMediaTime()
        guard now - lastPlayerPass >= playerPassInterval else { return }
        lastPlayerPass = now

        let page = pageRoot(from: unit)
        mountPlayer(in: unit, page: page)
        relayout()
    }

    /// Settings or accessibility changed: relayout now, and look again once.
    static func refresh() {
        if !ShrubifyLiquidGlass.isEnabled || UIAccessibility.isReduceTransparencyEnabled {
            removeAll()
            return
        }
        remainingScans = max(remainingScans, 6)
        relayout()
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow && !$0.isHidden }
    }

    // MARK: - Discovery

    /// Breadth-first on purpose: the full-screen player is a modal *sibling* of
    /// the home page, so a depth-first walk spends the whole node budget inside
    /// the feed and never reaches it.
    private static func collect(_ root: UIView, limit: Int, into nodes: inout [UIView]) {
        var queue: [(view: UIView, depth: Int)] = [(root, 0)]
        var index = 0
        while index < queue.count, nodes.count < limit {
            let item = queue[index]
            index += 1
            nodes.append(item.view)
            guard item.depth < maxDepth else { continue }
            for sub in item.view.subviews {
                queue.append((sub, item.depth + 1))
            }
        }
    }

    private static func first(withID identifier: String, in root: UIView) -> UIView? {
        var queue: [(view: UIView, depth: Int)] = [(root, 0)]
        var index = 0
        var visited = 0
        while index < queue.count, visited < maxPlayerNodes {
            let item = queue[index]
            index += 1
            visited += 1
            if item.view.accessibilityIdentifier == identifier { return item.view }
            guard item.depth < maxDepth else { continue }
            for sub in item.view.subviews { queue.append((sub, item.depth + 1)) }
        }
        return nil
    }

    private static func candidate(_ surface: Surface, in nodes: [UIView]) -> Candidate? {
        switch surface {
        case .tabs:
            return anchored(
                nodes.filter { isTabItem($0) },
                inset: CGSize(width: -12, height: -10),
                limit: 8
            ) ?? rowCandidate(nodes)
        case .miniPlayer:
            return miniPlayerCandidate(in: nodes)
        case .playerCard:
            return nil   // mounted by `mountPlayer`, never from the shape scan
        }
    }

    // MARK: - Mini-player

    /// The compact bar exists on every build, but its names do not: the iPhone
    /// tree calls the content `SPTNowPlayingBar`, the iPad one has used plain
    /// containers around the artwork and the play key. Three passes, cheapest
    /// identity first, all bounded by shape so a page-sized view can never win.
    private static func miniPlayerCandidate(in nodes: [UIView]) -> Candidate? {
        let names = ["sptnowplayingbar", "now-playing-bar", "mini-player-bar", "miniplayerbar"]
        if let bar = nodes.first(where: { view in
            guard let id = view.accessibilityIdentifier?.lowercased() else { return false }
            guard view.bounds.height >= 26, view.bounds.width >= 120 else { return false }
            return names.contains(where: { id.contains($0) })
        }) {
            return Candidate(host: bar, anchors: [bar], inset: CGSize(width: 2, height: 2))
        }
        if let bar = nodes.first(where: { view in
            let name = className(view)
            guard name.contains("NowPlayingBar") || name.contains("MiniPlayer") || name.contains("MiniBar")
            else { return false }
            return view.bounds.width >= 150 && (24...180).contains(view.bounds.height)
        }) {
            return Candidate(host: bar, anchors: [bar], inset: CGSize(width: 2, height: 2))
        }
        // Last resort: the compact bar wrapped around the transport's play key.
        guard let play = nodes.first(where: { isTransport($0) && category(of: $0) == .play }),
              let bar = compactBar(around: play) else { return nil }
        return Candidate(host: bar, anchors: [bar], inset: CGSize(width: 2, height: 2))
    }

    /// Walk up from a control to the first bar-shaped ancestor. The full player
    /// page is taller than the cap, so this can only land on a compact bar.
    private static func compactBar(around view: UIView) -> UIView? {
        var node: UIView? = view.superview
        var levels = 0
        while let current = node, levels < 6 {
            guard current.bounds.height <= 170 else { return nil }
            if current.bounds.width >= 180, current.bounds.height >= 34 { return current }
            node = current.superview
            levels += 1
        }
        return nil
    }

    // MARK: - Player

    private enum TransportKey: Equatable { case previous, play, next }

    private static func isTransport(_ view: UIView) -> Bool {
        category(of: view) != nil
    }

    /// Identity comes from the accessibility identifier, matched by containment
    /// so a renamed prefix (`SPTNowPlaying…`, `Encore…`) still lands.
    private static func category(of view: UIView) -> TransportKey? {
        guard let id = view.accessibilityIdentifier?.lowercased() else { return nil }
        if id.contains("playbutton") || id.contains("playpause") { return .play }
        if id.contains("nexttrack") || id.contains("skipforward") { return .next }
        if id.contains("previoustrack") || id.contains("skipbackward") || id.contains("previousbutton") {
            return .previous
        }
        return nil
    }

    /// The player page: the largest non-window ancestor of the transport row.
    private static func pageRoot(from view: UIView) -> UIView {
        var node = view
        var levels = 0
        while let parent = node.superview, levels < 12, !(parent is UIWindow),
              parent.window != nil, parent.bounds.height >= 480 {
            node = parent
            levels += 1
        }
        return node
    }

    /// Mount the card behind the player's bottom block and a circle on every
    /// key. Idempotent; only new elements cost a tree walk.
    private static func mountPlayer(from nodes: [UIView]) {
        // The mini-player carries a play key too; the full player's is bigger.
        let play = nodes
            .filter { $0.accessibilityIdentifier == playButtonID && $0.window != nil }
            .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
        guard let play, play.bounds.width >= 36 else { return }
        let unit = playerUnit(from: play, in: nodes) ?? play
        mountPlayer(in: unit, page: pageRoot(from: play))
    }

    /// The transport row's own container: the closest ancestor that still holds
    /// two of the three keys.
    private static func playerUnit(from play: UIView, in nodes: [UIView]) -> UIView? {
        var node: UIView? = play.superview
        var levels = 0
        while let current = node, levels < 6 {
            let keys = nodes.filter { $0.isDescendant(of: current) && isTransport($0) }
            if keys.count >= 2 { return current }
            node = current.superview
            levels += 1
        }
        return play.superview
    }

    private static func mountPlayer(in unit: UIView, page: UIView) {
        guard unit.window != nil else { return }

        // The compact bar carries one play key and no previous/next pair, so
        // this is also what stops the Home mini-player from getting key rings.
        let trio = [previousButtonID, playButtonID, nextButtonID]
            .compactMap { first(withID: $0, in: unit) }
        guard trio.count >= 2 else { return }

        if mounts.contains(where: { $0.surface == .playerCard && $0.host?.window != nil }) == false {
            mountPlayerCard(page: page, unit: unit)
        }

        // Transport row: the three keys plus whatever sits beside them
        // (shuffle and repeat) so the whole row carries glass.
        let row = commonAncestor(of: trio) ?? unit.subviews.first
        if let row { mountKeyPlates(in: row, outset: 6) }

        // The footer (share / queue / lyrics) and the two top keys need one
        // scan of the page; afterwards they are tracked by reference.
        let haveLyrics = keyMounts.contains { $0.control?.accessibilityIdentifier == lyricsButtonID }
        let haveMinimize = keyMounts.contains { $0.control?.accessibilityIdentifier == minimizeButtonID }
        let haveMenu = keyMounts.contains { $0.control?.accessibilityIdentifier == contextMenuID }
        guard !(haveLyrics && haveMinimize && haveMenu), pageScanAllowance > 0 else { return }
        pageScanAllowance -= 1

        if let lyrics = first(withID: lyricsButtonID, in: page) {
            if let footer = keyRow(around: lyrics) {
                mountKeyPlates(in: footer, outset: 7)
            } else {
                mountKeyPlate(for: lyrics, outset: 7)
            }
        }

        for identifier in [minimizeButtonID, contextMenuID] {
            if let control = first(withID: identifier, in: page) {
                mountKeyPlate(for: control, outset: 6)
            }
        }
    }

    /// The card: one rounded plate behind the block that holds the title, the
    /// progress bar and the transport row. Mounted in the block's *parent* so
    /// the block's own clipping cannot cut the corners off.
    private static func mountPlayerCard(page: UIView, unit: UIView) {
        guard cardAttempts > 0 else { return }
        cardAttempts -= 1
        let play = first(withID: playButtonID, in: unit) ?? first(withID: playButtonID, in: page)
        let slider = first(withID: sliderID, in: page)
        let previous = first(withID: previousButtonID, in: unit)
        let next = first(withID: nextButtonID, in: unit)

        var block: UIView?
        if let play, let slider {
            block = commonAncestor(of: [play, slider])
        }
        if block == nil {
            let anchors = [previous, play, next].compactMap { $0 }
            if anchors.count >= 2 { block = commonAncestor(of: anchors) }
        }
        guard let block, let container = block.superview, container.window != nil else { return }
        guard block.bounds.width >= 240, (60...760).contains(block.bounds.height),
              container.bounds.height >= block.bounds.height else { return }
        // Never wrap the whole page in one plate.
        guard container.bounds.height <= 1600 else { return }

        var frame = block.convert(block.bounds, to: container)
            .insetBy(dx: -10, dy: -12)
        frame = frame.intersection(container.bounds)
        guard frame.width >= 200, frame.height >= 80 else { return }

        let plate = ShrubifyLiquidGlass.makePlate(
            radius: Surface.playerCard.radius,
            interactive: false,
            boost: playerBoost
        )
        plate.accessibilityIdentifier = Surface.playerCard.identifier
        plate.frame = frame
        container.insertSubview(plate, belowSubview: block)

        // The block is the anchor: when the player goes away its window does
        // too, which is what prunes the card.
        mounts.append(
            Mount(
                surface: .playerCard,
                plate: plate,
                host: container,
                anchors: [block],
                inset: CGSize(width: -10, height: -12),
                restorations: clearCardBacking(block)
            )
        )
        if !didReport {
            didReport = true
            writeDebugLog(
                "[GlassChrome] player card on \(className(block))"
                    + " (\(Int(block.bounds.width))x\(Int(block.bounds.height)))"
            )
        }
    }

    private static func mountKeyPlates(in container: UIView, outset: CGFloat) {
        var nodes: [UIView] = []
        collect(container, limit: 400, into: &nodes)
        for view in nodes where isGlassKey(view) {
            // A button often wraps another control; nesting two circles inside
            // one key would draw a second rim. The outer view wins (BFS order).
            let nested = keyMounts.contains { mount in
                guard let existing = mount.control, existing !== view else { return false }
                return view.isDescendant(of: existing)
            }
            guard !nested else { continue }
            let size = max(view.bounds.width, view.bounds.height)
            mountKeyPlate(for: view, outset: size >= 52 ? outset + 2 : outset)
        }
    }

    /// A control that should carry its own circle: button-shaped, not a slider
    /// and not one of our own plates.
    private static func isGlassKey(_ view: UIView) -> Bool {
        guard view.window != nil, !view.isHidden, view.alpha > 0.01 else { return false }
        guard !(view is UISlider), !(view is UISwitch), !(view is UISegmentedControl) else {
            return false
        }
        let name = className(view)
        guard view is UIControl || name.contains("Button") else { return false }
        guard !name.contains("ShrubifyGlassPlate") else { return false }
        let size = view.bounds.size
        guard size.width >= 24, size.height >= 24,
              size.width <= 96, size.height <= 96,
              abs(size.width - size.height) <= 14 else { return false }
        return true
    }

    private static func mountKeyPlate(for control: UIView, outset: CGFloat) {
        guard control.window != nil, !control.isHidden, control.alpha > 0.01,
              control.bounds.width >= 20, control.bounds.height >= 20,
              control.bounds.width <= 110, control.bounds.height <= 110,
              let host = control.superview else { return }
        if let existing = keyMounts.first(where: { $0.control === control }) {
            if existing.plate.superview !== host {
                existing.plate.removeFromSuperview()
                host.insertSubview(existing.plate, belowSubview: control)
            }
            return
        }
        let plate = ShrubifyLiquidGlass.makePlate(
            radius: nil,
            interactive: false,
            boost: keyBoost
        )
        plate.accessibilityIdentifier = keyPlatePrefix
            + (control.accessibilityIdentifier ?? className(control))
        plate.frame = control.frame.insetBy(dx: -outset, dy: -outset)
        // Below the control: a glass ring around the key. Above it the
        // material's blur would smear the glyph itself.
        host.insertSubview(plate, belowSubview: control)
        keyMounts.append(KeyMount(plate: plate, host: host, control: control, outset: outset))
        writeDebugLog(
            "[GlassChrome] key glass on \(control.accessibilityIdentifier ?? className(control))"
        )
    }

    /// The row the footer keys live in: the first ancestor that holds two or
    /// more button-shaped views.
    private static func keyRow(around control: UIView) -> UIView? {
        var node = control.superview
        var levels = 0
        while let current = node, levels < 3 {
            if current.subviews.filter({ isGlassKey($0) }).count >= 2 { return current }
            node = current.superview
            levels += 1
        }
        return nil
    }

    private static func commonAncestor(of views: [UIView]) -> UIView? {
        guard let first = views.first else { return nil }
        var candidate: UIView? = first.superview
        var levels = 0
        while let current = candidate, levels < 40, !(current is UIWindow) {
            if views.allSatisfy({ $0.isDescendant(of: current) }) { return current }
            candidate = current.superview
            levels += 1
        }
        return nil
    }

    private static func isTabItem(_ view: UIView) -> Bool {
        if let id = view.accessibilityIdentifier, id.hasPrefix(tabItemPrefix) { return true }
        return className(view).contains("TabBarItemElementView")
    }

    /// The union of the anchors' frames is the material's shape even when
    /// Spotify draws the bar with SwiftUI. The host is their common ancestor:
    /// items wrapped one-per-view still form one capsule.
    private static func anchored(_ views: [UIView], inset: CGSize, limit: Int) -> Candidate? {
        let unique = views.reduce(into: [UIView]()) { result, view in
            guard result.count < limit, !result.contains(where: { $0 === view }) else { return }
            result.append(view)
        }
        guard unique.count >= 2, let host = commonAncestor(of: unique) else { return nil }
        return Candidate(host: host, anchors: unique, inset: inset)
    }

    /// Fallback when the items are hosted outside UIKit: the icon row itself.
    private static func rowCandidate(_ nodes: [UIView]) -> Candidate? {
        for view in nodes {
            if view.accessibilityIdentifier == "tabs-container-view-identifier" {
                return Candidate(host: view, anchors: [view], inset: CGSize(width: -14, height: -9))
            }
        }
        for view in nodes where className(view).contains("TabBarView") {
            guard !className(view).contains("Item"),
                  (40...130).contains(view.bounds.height),
                  view.bounds.width > 200 else { continue }
            return Candidate(host: view, anchors: [view], inset: CGSize(width: -8, height: -6))
        }
        return nil
    }

    // MARK: - Mounting

    private static func mount(_ surface: Surface, with candidate: Candidate?) {
        prune()
        guard let candidate else { return }
        let host = candidate.host
        guard host.window != nil, !host.isHidden, host.alpha > 0.01 else { return }
        guard !isOwned(surface) else { return }
        guard !mounts.contains(where: { $0.host === host && $0.surface == surface }) else { return }
        // Spotify's own build may already supply real glass here; a second
        // material would double the rim exactly like the old duplicate owners.
        guard !hasSystemGlass(in: host) else { return }
        // One material per surface: yield to a native bar plate already there.
        if host.subviews.contains(where: { subview in
            guard let id = subview.accessibilityIdentifier else { return false }
            return id.hasPrefix(nativeBarPlate)
                || (id.hasPrefix(chromePrefix) && !id.hasPrefix(keyPlatePrefix))
        }) { return }

        let plate = ShrubifyLiquidGlass.makePlate(
            radius: surface.radius,
            interactive: false,
            boost: chromeBoost
        )
        plate.accessibilityIdentifier = surface.identifier
        let mount = Mount(
            surface: surface,
            plate: plate,
            host: host,
            anchors: candidate.anchors,
            inset: candidate.inset,
            restorations: []
        )
        guard let frame = plateFrame(for: mount) else { return }
        plate.frame = frame
        insert(plate, into: host)
        // The bars are the only surfaces Spotify paints opaque; clearing that
        // backing is what turns the plate into real glass over the page.
        mounts.append(
            Mount(
                surface: surface,
                plate: plate,
                host: host,
                anchors: candidate.anchors,
                inset: candidate.inset,
                restorations: clearBacking(around: host)
            )
        )

        if !didReport {
            didReport = true
            writeDebugLog(
                "[GlassChrome] mounted \(surface.identifier) on \(className(host))"
                    + " (\(candidate.anchors.count) anchor(s))"
            )
        }
    }

    /// Real `UIGlassEffect` already inside this host (Spotify's own chrome, or
    /// another module). Ours never counts: those plates carry our identifier.
    private static func hasSystemGlass(in view: UIView, depth: Int = 0) -> Bool {
        if #available(iOS 26.0, *) {
            if let material = view as? UIVisualEffectView, material.effect is UIGlassEffect {
                let id = material.accessibilityIdentifier ?? ""
                if !id.hasPrefix(chromePrefix) { return true }
            }
        }
        guard depth < 3 else { return false }
        return view.subviews.contains { hasSystemGlass(in: $0, depth: depth + 1) }
    }

    /// Never bury the plate under Spotify's own opaque backing.
    private static func insert(_ plate: UIView, into host: UIView) {
        var index = 0
        for (offset, sub) in host.subviews.enumerated() where sub !== plate {
            if isOpaqueBacking(sub, in: host) { index = offset + 1 }
        }
        host.insertSubview(plate, at: min(index, host.subviews.count))
    }

    private static func isOpaqueBacking(_ view: UIView, in host: UIView) -> Bool {
        let covers = view.frame.width >= host.bounds.width * 0.8
        if let colour = view.backgroundColor, colour.cgColor.alpha >= 0.5, covers, view.frame.height >= 20 {
            return true
        }
        let name = className(view)
        let decorative = name.contains("Gradient") || name.contains("Backdrop") || name.contains("Background")
        return decorative && covers
    }

    /// The player block's own fill (album-art tint) would hide the card.
    private static func clearCardBacking(_ block: UIView) -> [() -> Void] {
        guard let colour = block.backgroundColor, colour.cgColor.alpha > 0.01 else { return [] }
        block.backgroundColor = .clear
        return [{ [weak block] in
            guard let block, block.backgroundColor == .clear else { return }
            block.backgroundColor = colour
        }]
    }

    /// Capture-then-clear, exactly like `NativeTabletGlass`: every change gets a
    /// matching undo so turning the switch off restores Spotify byte for byte.
    private static func clearBacking(around host: UIView) -> [() -> Void] {
        var restorations: [() -> Void] = []
        var node: UIView? = host
        var levels = 0
        while let current = node, levels < 4, current.bounds.height <= 150 {
            if let colour = current.backgroundColor, colour.cgColor.alpha > 0.01 {
                restorations.append { [weak current] in
                    guard let current, current.backgroundColor == .clear else { return }
                    current.backgroundColor = colour
                }
                current.backgroundColor = .clear
            }
            if let material = current as? UIVisualEffectView, let effect = material.effect {
                restorations.append { [weak material] in
                    guard let material, material.effect == nil else { return }
                    material.effect = effect
                }
                material.effect = nil
            }
            for child in current.subviews where child.subviews.isEmpty {
                let name = className(child)
                guard name.hasSuffix("TabBarGradientView") || name.hasSuffix("TabBarBackgroundView"),
                      child.alpha > 0 else { continue }
                let alpha = child.alpha
                restorations.append { [weak child] in
                    guard let child, child.alpha == 0 else { return }
                    child.alpha = alpha
                }
                child.alpha = 0
            }
            node = current.superview
            levels += 1
        }
        return restorations
    }

    private static func relayout() {
        prune()
        for mount in mounts {
            // The player card tracks the block it sits behind, not its own host.
            let target: CGRect?
            if mount.surface == .playerCard {
                target = cardFrame(for: mount)
            } else {
                target = plateFrame(for: mount)
            }
            guard let target else {
                mount.plate.isHidden = true
                continue
            }
            mount.plate.isHidden = false
            if mount.plate.frame != target { mount.plate.frame = target }
        }
        for mount in keyMounts {
            guard let control = mount.control, control.window != nil else { continue }
            let frame = control.frame.insetBy(dx: -mount.outset, dy: -mount.outset)
            if mount.plate.frame != frame { mount.plate.frame = frame }
        }
    }

    private static func prune() {
        var survivors: [Mount] = []
        for mount in mounts {
            guard let host = mount.host,
                  host.window != nil,
                  mount.plate.superview === host,
                  mount.anchors.contains(where: { $0 === host || ($0.isDescendant(of: host) && $0.window != nil) })
            else {
                mount.plate.removeFromSuperview()
                if !isOwned(mount.surface) { mount.restorations.reversed().forEach { $0() } }
                continue
            }
            survivors.append(mount)
        }
        mounts = survivors

        keyMounts = keyMounts.filter { mount in
            guard let host = mount.host, let control = mount.control,
                  mount.plate.superview === host,
                  control.superview === host, control.window != nil else {
                mount.plate.removeFromSuperview()
                return false
            }
            return true
        }
    }

    private static func removeAll() {
        for mount in mounts {
            mount.plate.removeFromSuperview()
            mount.restorations.reversed().forEach { $0() }
        }
        mounts.removeAll()
        for mount in keyMounts { mount.plate.removeFromSuperview() }
        keyMounts.removeAll()
    }

    /// What the settings page shows: which surfaces this Spotify build exposes.
    static var statusLines: [String] {
        guard isSupported else { return ["Liquid Glass chrome: iPhone uses its own custom chrome."] }
        guard ShrubifyLiquidGlass.isEnabled else { return ["Liquid Glass chrome: switched off."] }
        if UIAccessibility.isReduceTransparencyEnabled {
            return ["Liquid Glass chrome: paused by Reduce Transparency."]
        }
        let mounted = Set(mounts.map { $0.surface })
        var lines = Surface.allCases.map { surface -> String in
            if isOwned(surface) { return "\(surface.title): native glass" }
            return "\(surface.title): \(mounted.contains(surface) ? "glass on" : "not found yet — open it once")"
        }
        lines.append("Player buttons: \(keyMounts.count) with glass")
        return lines
    }

    // MARK: - Geometry

    /// The card's rectangle, recomputed from the block it covers.
    private static func cardFrame(for mount: Mount) -> CGRect? {
        guard let host = mount.host,
              let block = mount.anchors.first(where: { $0.window != nil }),
              block.isDescendant(of: host) else { return nil }
        let blockFrame = block.superview === host
            ? block.frame
            : block.convert(block.bounds, to: host)
        let frame = blockFrame.insetBy(dx: mount.inset.width, dy: mount.inset.height)
            .intersection(host.bounds)
        guard frame.width >= 160, frame.height >= 60 else { return nil }
        return frame
    }

    private static func plateFrame(for mount: Mount) -> CGRect? {
        guard let host = mount.host, host.bounds.width > 60, host.bounds.height > 18 else { return nil }
        let rects = mount.anchors.compactMap { anchor -> CGRect? in
            guard anchor === host || (anchor.isDescendant(of: host) && anchor.window != nil) else { return nil }
            let rect = anchor.convert(anchor.bounds, to: host)
            return rect.width > 0.5 && rect.height > 0.5 ? rect : nil
        }
        guard let first = rects.first else { return nil }
        let union = rects.dropFirst().reduce(first) { $0.union($1) }
        let frame = union.insetBy(dx: mount.inset.width, dy: mount.inset.height)
        guard frame.width >= 44, frame.height >= 18,
              frame.width <= host.bounds.width * 1.4,
              frame.minY >= host.bounds.minY - 40,
              frame.maxY <= host.bounds.maxY + 40 else { return nil }
        return frame
    }

    private static func className(_ view: UIView) -> String {
        NSStringFromClass(type(of: view))
    }
}

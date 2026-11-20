import UIKit
import QuartzCore

/// Liquid Glass for the surfaces Spotify still draws itself.
///
/// Two failures this file exists to prevent:
/// 1. the iPad player is deliberately left native, so custom-interface chrome
///    never reached it; and
/// 2. a single class-name hook silently dies when Spotify renames a class.
///
/// So the pass anchors on the *controls* — the tab items and the transport
/// buttons, which keep their accessibility identifiers across redesigns — and
/// mounts one plate per surface inside their common superview, above whatever
/// opaque backing Spotify draws there. Nothing Spotify owns is resized, cleared
/// or given a different hit region.
///
/// Bounded (fixed depth, node cap), idempotent, and it stops walking the tree
/// as soon as every surface is mounted.
@MainActor
enum ShrubifyGlassChrome {

    enum Surface: CaseIterable {
        case tabs
        case miniPlayer
        case playerControls

        /// Also the plate's accessibility identifier, so the two glass owners
        /// can recognise each other's work.
        var identifier: String {
            switch self {
            case .tabs: return "shrubify.glass.chrome.tabs"
            case .miniPlayer: return "shrubify.glass.chrome.mini"
            case .playerControls: return "shrubify.glass.chrome.controls"
            }
        }

        var radius: CGFloat? {
            switch self {
            case .tabs, .miniPlayer: return nil      // capsule
            case .playerControls: return 26
            }
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

    /// The dedicated bar backing names its plate with this prefix.
    private static let nativeBarPlate = "shrubify.native.glass"
    /// Spotify's chrome is near-black; the neutral material needs help there.
    private static let chromeBoost: CGFloat = 1.85

    private static let tabItemPrefix = "TabBar.Item."
    private static let transportIdentifiers = [
        "SPTNowPlayingPreviousTrackButton",
        "SPTNowPlayingPlayButton",
        "SPTNowPlayingNextTrackButton",
    ]

    private static var mounts: [Mount] = []
    private static var observers: [NSObjectProtocol] = []
    private static var timer: Timer?
    private static var lastPass: CFTimeInterval = 0
    private static var remainingScans = 12
    private static var didReport = false

    private static let maxNodes = 2600
    private static let maxDepth = 18
    private static let passInterval: CFTimeInterval = 0.5
    private static let tickInterval: TimeInterval = 2.0

    static var isSupported: Bool { EvolvedInterfaceAvailability.usesNativeTabletInterface }

    static func start() {
        registerObserversIfNeeded()
        guard timer == nil else { return }
        // The bars exist at launch; the transport row only after the player
        // opens. A slow tick keeps looking while any surface is missing and
        // stops walking the tree as soon as all of them are mounted.
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
        // Nothing missing: no tree walk, just keep the plates in step.
        guard mounts.count < Surface.allCases.count else {
            relayout()
            return
        }
        remainingScans = max(remainingScans, 1)
        guard let window = keyWindow() else { return }
        pass(in: window)
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

        if remainingScans > 0 {
            remainingScans -= 1
            var nodes: [UIView] = []
            var visited = 0
            collect(window, depth: 0, visited: &visited, into: &nodes)
            for surface in Surface.allCases {
                guard !mounts.contains(where: { $0.surface == surface && $0.host?.window != nil })
                else { continue }
                mount(surface, with: candidate(surface, in: nodes))
            }
        }
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

    private static func collect(
        _ node: UIView,
        depth: Int,
        visited: inout Int,
        into nodes: inout [UIView]
    ) {
        guard visited < maxNodes, depth <= maxDepth else { return }
        visited += 1
        nodes.append(node)
        for sub in node.subviews { collect(sub, depth: depth + 1, visited: &visited, into: &nodes) }
    }

    private static func candidate(_ surface: Surface, in nodes: [UIView]) -> Candidate? {
        switch surface {
        case .tabs:
            return anchored(
                nodes.filter { isTabItem($0) },
                inset: CGSize(width: -12, height: -10),
                limit: 8
            ) ?? rowCandidate(nodes)
        case .playerControls:
            return anchored(
                nodes.filter {
                    guard let id = $0.accessibilityIdentifier else { return false }
                    return transportIdentifiers.contains(id)
                },
                inset: CGSize(width: -12, height: -14),
                limit: 3
            ) ?? anchored(
                nodes.filter { className($0).contains("PlaybackControlsElementsUnit") },
                inset: CGSize(width: -14, height: -10),
                limit: 1
            )
        case .miniPlayer:
            guard let bar = nodes.first(where: {
                $0.accessibilityIdentifier == "SPTNowPlayingBar"
                    || (className($0).contains("NowPlayingBar") && (34...110).contains($0.bounds.height))
            }) else { return nil }
            return Candidate(host: bar, anchors: [bar], inset: CGSize(width: 2, height: 2))
        }
    }

    private static func isTabItem(_ view: UIView) -> Bool {
        if let id = view.accessibilityIdentifier, id.hasPrefix(tabItemPrefix) { return true }
        return className(view).contains("TabBarItemElementView")
    }

    /// The tab/transport buttons share one superview; the union of their frames
    /// is the material's shape even when Spotify draws the bar with SwiftUI.
    private static func anchored(_ views: [UIView], inset: CGSize, limit: Int) -> Candidate? {
        let unique = views.reduce(into: [UIView]()) { result, view in
            guard result.count < limit, !result.contains(where: { $0 === view }) else { return }
            result.append(view)
        }
        guard unique.count >= 2, let host = unique.first?.superview,
              unique.allSatisfy({ $0.superview === host }) else { return nil }
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
        guard !mounts.contains(where: { $0.host === host && $0.surface == surface }) else { return }
        // One material per surface: yield to whichever owner got there first.
        if host.subviews.contains(where: {
            $0 is ShrubifyGlassPlate
                || ($0.accessibilityIdentifier?.hasPrefix(nativeBarPlate) ?? false)
                || ($0.accessibilityIdentifier?.hasPrefix("shrubify.glass.chrome.") ?? false)
        }) { return }

        let plate = ShrubifyLiquidGlass.makePlate(
            radius: surface.radius,
            interactive: false,
            boost: chromeBoost
        )
        plate.accessibilityIdentifier = surface.identifier
        var mount = Mount(
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
        if surface != .playerControls {
            mount = Mount(
                surface: surface,
                plate: plate,
                host: host,
                anchors: candidate.anchors,
                inset: candidate.inset,
                restorations: clearBacking(around: host)
            )
        }
        mounts.append(mount)

        if !didReport {
            didReport = true
            writeDebugLog(
                "[GlassChrome] mounted \(surface.identifier) on \(className(host))"
                    + " (\(candidate.anchors.count) anchor(s))"
            )
        }
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
            guard let frame = plateFrame(for: mount) else {
                mount.plate.isHidden = true
                continue
            }
            mount.plate.isHidden = false
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
                mount.restorations.reversed().forEach { $0() }
                continue
            }
            survivors.append(mount)
        }
        mounts = survivors
    }

    private static func removeAll() {
        for mount in mounts {
            mount.plate.removeFromSuperview()
            mount.restorations.reversed().forEach { $0() }
        }
        mounts.removeAll()
    }

    /// What the settings page shows: which surfaces this Spotify build exposes.
    static var statusLines: [String] {
        guard isSupported else { return ["Liquid Glass chrome: iPhone uses its own custom chrome."] }
        guard ShrubifyLiquidGlass.isEnabled else { return ["Liquid Glass chrome: switched off."] }
        if UIAccessibility.isReduceTransparencyEnabled {
            return ["Liquid Glass chrome: paused by Reduce Transparency."]
        }
        let mounted = Set(mounts.map { $0.surface })
        return Surface.allCases.map { surface in
            let name: String
            switch surface {
            case .tabs: name = "Tab bar"
            case .miniPlayer: name = "Mini-player"
            case .playerControls: name = "Player controls"
            }
            return "\(name): \(mounted.contains(surface) ? "glass on" : "not found yet — open the bar once")"
        }
    }

    // MARK: - Geometry

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

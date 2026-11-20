import UIKit
import QuartzCore

/// Liquid Glass for the surfaces Spotify still draws itself.
///
/// The iPad player is deliberately left native (Shrubify repairs navigation and
/// page layouts there instead of replacing them), and a renamed Spotify class
/// silently drops a hook. So instead of trusting one class name, this pass finds
/// the tab bar, the mini-player and the player's transport controls in the
/// window that is already laying out — by accessibility identifier *and* class
/// name — and mounts one decorative plate per surface.
///
/// Rules kept from the rest of this folder:
/// · never change Spotify's frames, colours or hit testing — the plate is a
///   non-interactive, accessibility-hidden sibling at subview index 0;
/// · stay idempotent: a pass may run many times per second;
/// · respect the master Liquid Glass switch, the iPad bar switch and Reduce
///   Transparency, and never stack on top of `NativeTabletGlass`;
/// · bounded work only (fixed depth, node cap, one scan per pass).
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
    }

    private struct Mount {
        weak var host: UIView?
        let plate: ShrubifyGlassPlate
        let surface: Surface
    }

    /// The dedicated bar backing names its plate with this prefix.
    private static let nativeBarPlate = "shrubify.native.glass"

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
        // The bars exist at launch; the player's controls only after the player
        // opens. A slow tick keeps looking while any surface is missing and
        // stops walking the tree as soon as all three are mounted.
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
        remainingScans = max(remainingScans, 4)
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
            var found: [Surface: UIView] = [:]
            var visited = 0
            scan(window, depth: 0, visited: &visited, into: &found)
            for surface in Surface.allCases {
                if let host = found[surface] { mount(surface, in: host) }
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
        remainingScans = max(remainingScans, 4)
        relayout()
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow && !$0.isHidden }
    }

    // MARK: - Discovery

    private static func scan(
        _ node: UIView,
        depth: Int,
        visited: inout Int,
        into found: inout [Surface: UIView]
    ) {
        guard visited < maxNodes, depth <= maxDepth else { return }
        visited += 1

        if found[.tabs] == nil, isTabsRow(node) { found[.tabs] = node }
        if found[.miniPlayer] == nil, node.accessibilityIdentifier == "SPTNowPlayingBar" {
            found[.miniPlayer] = node
        }
        if found[.playerControls] == nil, className(node).contains("PlaybackControlsElementsUnit") {
            found[.playerControls] = node
        }
        guard found.count < Surface.allCases.count else { return }

        for sub in node.subviews { scan(sub, depth: depth + 1, visited: &visited, into: &found) }
    }

    /// The icon row is the real host on a device dump (`tabs-container-view-identifier`);
    /// the bar class is the fallback when Spotify renames the row.
    private static func isTabsRow(_ view: UIView) -> Bool {
        if view.accessibilityIdentifier == "tabs-container-view-identifier" { return true }
        let name = className(view)
        guard name.contains("TabBarView"), !name.contains("Item") else { return false }
        return (40...130).contains(view.bounds.height) && view.bounds.width > 200
    }

    // MARK: - Mounting

    private static func mount(_ surface: Surface, in host: UIView) {
        prune()
        guard host.window != nil, !host.isHidden, host.alpha > 0.01 else { return }
        guard !mounts.contains(where: { $0.host === host }) else { return }
        if surface != .playerControls, !NativeTabletGlass.isOnForCurrentDevice { return }
        // One material per surface: yield to whichever owner got there first.
        if host.subviews.contains(where: {
            $0 is ShrubifyGlassPlate
                || ($0.accessibilityIdentifier?.hasPrefix(nativeBarPlate) ?? false)
                || ($0.accessibilityIdentifier?.hasPrefix("shrubify.glass.chrome.") ?? false)
        }) { return }
        guard let frame = plateFrame(for: surface, in: host) else { return }

        let plate = ShrubifyLiquidGlass.makePlate(
            radius: surface == .playerControls ? 28 : nil,
            interactive: false
        )
        plate.accessibilityIdentifier = surface.identifier
        plate.frame = frame
        host.insertSubview(plate, at: 0)
        mounts.append(Mount(host: host, plate: plate, surface: surface))

        guard !didReport else { return }
        didReport = true
        writeDebugLog("[GlassChrome] mounted \(surface.identifier) on \(className(host))")
    }

    private static func relayout() {
        prune()
        for mount in mounts {
            guard let host = mount.host, mount.plate.superview === host else { continue }
            guard let frame = plateFrame(for: mount.surface, in: host) else {
                mount.plate.isHidden = true
                continue
            }
            mount.plate.isHidden = host.isHidden || host.alpha < 0.01
            if mount.plate.frame != frame { mount.plate.frame = frame }
        }
    }

    private static func prune() {
        mounts.removeAll { $0.host == nil || $0.plate.superview !== $0.host }
    }

    private static func removeAll() {
        for mount in mounts { mount.plate.removeFromSuperview() }
        mounts.removeAll()
    }

    // MARK: - Geometry

    private static func plateFrame(for surface: Surface, in host: UIView) -> CGRect? {
        let bounds = host.bounds
        guard bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 60, bounds.height > 18 else { return nil }

        switch surface {
        case .tabs:
            // A stack row does not clip, so the plate can breathe around the icons.
            let slack: CGFloat = host.clipsToBounds ? 2 : 14
            let vertical: CGFloat = host.clipsToBounds ? 2 : 9
            return CGRect(
                x: bounds.minX - slack,
                y: bounds.minY - vertical,
                width: bounds.width + slack * 2,
                height: bounds.height + vertical * 2
            )
        case .miniPlayer:
            let inset = bounds.insetBy(dx: 2, dy: 2)
            return inset.width > 60 && inset.height > 18 ? inset : nil
        case .playerControls:
            let inset = bounds.insetBy(dx: 14, dy: 10)
            return inset.width > 80 && inset.height > 30 ? inset : nil
        }
    }

    private static func className(_ view: UIView) -> String {
        NSStringFromClass(type(of: view))
    }
}

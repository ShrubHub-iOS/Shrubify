import UIKit
import QuartzCore

/// Bounded discovery for renamed tablet bars. NativeTabletGlass is the sole
/// renderer and restoration owner. Never decorate the expanded player.
@MainActor
enum ShrubifyGlassChrome {
    private final class ScanState {
        var remaining = 20
        var lastPass: CFTimeInterval = 0
    }
    private static let windows = NSMapTable<UIView, ScanState>.weakToStrongObjects()
    private static var observers: [NSObjectProtocol] = []
    static var isSupported: Bool { EvolvedInterfaceAvailability.usesNativeTabletInterface }

    static func start() {
        guard #available(iOS 26.0, *), isSupported, observers.isEmpty else { return }
        for name in [Notification.Name.shrubifyLiquidGlassDidChange,
                     UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                     UIApplication.didBecomeActiveNotification, UIScene.didActivateNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                onMainThreadSync { rearm() }
            })
        }
    }

    static func rearm() {
        for case let window as UIView in windows.keyEnumerator().allObjects {
            if let state = windows.object(forKey: window) {
                state.remaining = 20
                state.lastPass = 0
            }
            pass(in: window)
        }
    }

    static func refresh() {
        NativeTabletGlass.reapply()
        rearm()
    }

    static func pass(in window: UIView) {
        guard #available(iOS 26.0, *), isSupported,
              window.bounds.width > 200, !window.isHidden,
              ShrubifyLiquidGlass.isEnabled, NativeTabletGlass.isOnForCurrentDevice,
              !UIAccessibility.isReduceTransparencyEnabled,
              !UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode") else { return }
        let state: ScanState
        if let existing = windows.object(forKey: window) { state = existing }
        else { state = ScanState(); windows.setObject(state, forKey: window) }
        let missingTabs = !NativeTabletGlass.owns(.tabs, in: window)
        let missingMini = !NativeTabletGlass.owns(.miniPlayer, in: window)
        guard missingTabs || missingMini else { return }
        let now = CACurrentMediaTime()
        guard state.remaining > 0, now - state.lastPass >= 0.5 else { return }
        state.remaining -= 1
        state.lastPass = now
        var queue = [window]
        var index = 0
        var tabs: UIView?
        var mini: UIView?
        while index < queue.count, index < 1800 {
            let view = queue[index]
            index += 1
            guard !view.isHidden, view.alpha > 0.01 else { continue }
            let id = view.accessibilityIdentifier
            let name = NSStringFromClass(type(of: view))
            if missingTabs, tabs == nil, (20...110).contains(view.bounds.height),
               name == "NavigationUI_TabBarImpl.TabBarView" || id == "tabs-container-view-identifier" {
                tabs = view
            }
            if missingMini, mini == nil, (20...110).contains(view.bounds.height), id == "SPTNowPlayingBar" {
                mini = view
            }
            if (!missingTabs || tabs != nil) && (!missingMini || mini != nil) { break }
            if !(view is UIScrollView || view is UIImageView || view is UIControl), queue.count < 1800 {
                queue.append(contentsOf: view.subviews.prefix(1800 - queue.count))
            }
        }
        if let tabs { NativeTabletGlass.layout(.tabs, in: tabs, fallback: true) }
        if let mini { NativeTabletGlass.layout(.miniPlayer, in: mini, fallback: true) }
    }

    static var statusLines: [String] {
        guard isSupported else { return ["iPhone uses its own navigation appearance."] }
        guard ShrubifyLiquidGlass.isEnabled, NativeTabletGlass.isOnForCurrentDevice else {
            return ["Bottom bar glass: switched off."]
        }
        guard !UIAccessibility.isReduceTransparencyEnabled else { return ["Bottom bar glass: Reduce Transparency."] }
        guard !UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode") else { return ["Bottom bar glass: Stability Mode."] }
        return [
            "Tab bar: " + (NativeTabletGlass.owns(.tabs) ? "native glass" : "native interface — glass host not found"),
            "Mini-player: " + (NativeTabletGlass.owns(.miniPlayer) ? "native glass" : "native interface — glass host not found"),
            "Player: clean native controls (no glass rings or transport card)."
        ]
    }
}

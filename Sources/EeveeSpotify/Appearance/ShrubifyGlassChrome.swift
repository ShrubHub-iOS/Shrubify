import UIKit

/// Tablet chrome diagnostics. Known bar hosts are handled by NativeTabletGlass
/// through their own exact-class lifecycle hooks. A broad UIWindow scan is not
/// an appropriate fallback: it can confuse background views with controls,
/// compete with the real owner and cause layout hitches on Home.
@MainActor
enum ShrubifyGlassChrome {
    static var isSupported: Bool { EvolvedInterfaceAvailability.usesNativeTabletInterface }

    static func start() {}
    static func rearm() { NativeTabletGlass.reapply() }
    static func refresh() { NativeTabletGlass.reapply() }

    static var statusLines: [String] {
        guard isSupported else { return ["iPhone has its own navigation presentation."] }
        guard ShrubifyLiquidGlass.isEnabled, NativeTabletGlass.isOnForCurrentDevice else {
            return ["Bottom bar glass: switched off."]
        }
        if UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode") {
            return ["Bottom bar glass: Stability Mode keeps native backings."]
        }
        if UIAccessibility.isReduceTransparencyEnabled {
            return ["Bottom bar glass: Reduce Transparency keeps native backings."]
        }
        return [
            "Tab bar: " + materialDescription(.tabs),
            "Mini-player: " + materialDescription(.miniPlayer),
            "Player layout: " + (ResponsivePlayer.tabletEnabled ? "Artwork-led" : "Spotify")
        ]
    }

    private static func materialDescription(_ bar: NativeTabletGlass.Bar) -> String {
        guard let size = NativeTabletGlass.materialSize(bar) else { return "no attached effect" }
        return "System effect, \(Int(size.width.rounded())) × \(Int(size.height.rounded())) pt"
    }
}

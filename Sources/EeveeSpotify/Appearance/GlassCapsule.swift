import UIKit

/// One shared material per capsule, kept in sync with the Liquid Glass settings.
enum GlassCapsule {
    static let height: CGFloat = 60
    static var cornerRadius: CGFloat { height / 2 }
    static var hasSystemGlass: Bool { if #available(iOS 26.0, *) { return true }; return false }

    @MainActor
    static func makeGlassView(wantsInteractive: Bool, cornerRadius: CGFloat? = nil) -> (view: UIVisualEffectView, isInteractive: Bool) {
        let view = ShrubifyLiquidGlass.makePlate(radius: cornerRadius, interactive: wantsInteractive)
        return (view, hasSystemGlass && wantsInteractive && !UIAccessibility.isReduceTransparencyEnabled)
    }
}

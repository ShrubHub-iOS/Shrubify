import UIKit

/// The materials Shrubify's Liquid Glass can use.
enum ShrubifyGlassStyle: String, CaseIterable, Identifiable {
    case clear
    case regular
    case tinted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: return "Clear"
        case .regular: return "Regular"
        case .tinted: return "Tinted"
        }
    }

    var detail: String {
        switch self {
        case .clear: return "Thinnest material — the cover shows through the most."
        case .regular: return "Apple's balanced Liquid Glass."
        case .tinted: return "A soft accent tint through the glass."
        }
    }

    /// Base tint alpha; scaled by the user's intensity setting.
    var baseTintAlpha: CGFloat {
        switch self {
        case .clear: return 0.03
        case .regular: return 0.09
        case .tinted: return 0.22
        }
    }

    /// Fallback material below iOS 26, where `UIGlassEffect` does not exist.
    var blurStyle: UIBlurEffect.Style {
        switch self {
        case .clear: return .systemUltraThinMaterial
        case .regular: return .systemThinMaterial
        case .tinted: return .systemThickMaterial
        }
    }
}

extension Notification.Name {
    /// Posted when any Liquid Glass setting changes; every live plate refreshes.
    static let shrubifyLiquidGlassDidChange = Notification.Name("ShrubifyLiquidGlassDidChange")
}

/// One place that decides how Liquid Glass looks across the whole app.
///
/// Every surface — tab bar, mini-player, player footer, lyrics button, iPad
/// bottom bars — uses the same material so the look stays consistent. iOS 26
/// gets the real `UIGlassEffect` (interactive only where a surface asks for it);
/// older systems get a simple system blur. Reduce Transparency uses a solid fill.
enum ShrubifyLiquidGlass {
    static let enabledKey = "ShrubifyLiquidGlass"
    static let styleKey = "ShrubifyLiquidGlassStyle"
    static let intensityKey = "ShrubifyLiquidGlassIntensity"

    static let allKeys = [enabledKey, styleKey, intensityKey]

    /// Master switch. Default on: Shrubify ships glass, not flat panels.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var style: ShrubifyGlassStyle {
        guard let raw = UserDefaults.standard.string(forKey: styleKey),
              let style = ShrubifyGlassStyle(rawValue: raw) else { return .clear }
        return style
    }

    /// 0…1. Controls the optional accent tint.
    static var intensity: CGFloat {
        let stored = UserDefaults.standard.object(forKey: intensityKey) as? Double ?? 0.55
        return CGFloat(min(max(stored, 0), 1))
    }

    /// Only an explicitly selected accent colors the glass.
    ///
    /// Read directly rather than through `Theme`: this file is also compiled
    /// into the isolated lyrics-interaction harness, which has no Theme or
    /// settings extension.
    static var accent: UIColor? {
        let stored = UserDefaults.standard.object(forKey: "accentColorRGB") as? Int ?? -1
        guard stored >= 0 else { return nil }
        return UIColor(
            red: CGFloat((stored >> 16) & 0xFF) / 255,
            green: CGFloat((stored >> 8) & 0xFF) / 255,
            blue: CGFloat(stored & 0xFF) / 255,
            alpha: 1
        )
    }

    /// A fresh plate. `radius == nil` means a capsule.
    ///
    /// `boost` remains accepted for source compatibility; UIKit controls optical strength.
    @MainActor
    static func makePlate(
        radius: CGFloat? = nil,
        interactive: Bool = false,
        boost: CGFloat = 1
    ) -> ShrubifyGlassPlate {
        ShrubifyGlassPlate(radius: radius, interactive: interactive, boost: boost)
    }

    /// Call after changing any key above so mounted surfaces update immediately.
    static func notifyChange() {
        onMainThreadSync {
            NotificationCenter.default.post(name: .shrubifyLiquidGlassDidChange, object: nil)
        }
    }
}

/// System-owned optical material; no synthetic borders or sheen.
@MainActor
final class ShrubifyGlassPlate: UIVisualEffectView {
    private let radius: CGFloat?
    private let interactive: Bool
    private var observers: [NSObjectProtocol] = []
    private var lastMaterial: Material?
    private struct Material: Equatable {
        let enabled: Bool
        let opaque: Bool
        let style: ShrubifyGlassStyle
        let tint: UIColor?
    }

    init(radius: CGFloat?, interactive: Bool, boost: CGFloat = 1) {
        self.radius = radius
        self.interactive = interactive
        super.init(effect: nil)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        layer.cornerCurve = .continuous
        if #available(iOS 26.0, *) {
            if let radius { cornerConfiguration = .corners(radius: .fixed(Double(radius))) }
            else { cornerConfiguration = .capsule() }
        } else {
            clipsToBounds = true
        }
        for name in [UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                     UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
                     .shrubifyLiquidGlassDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                onMainThreadSync { self?.refresh() }
            })
        }
        refresh()
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #unavailable(iOS 26.0) {
            let half = min(bounds.width, bounds.height) / 2
            layer.cornerRadius = min(radius ?? half, half)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }

    func refresh() {
        let style = ShrubifyLiquidGlass.style
        let intensity = ShrubifyLiquidGlass.intensity
        let tint = style == .tinted && intensity > 0
            ? ShrubifyLiquidGlass.accent?.withAlphaComponent(intensity * 0.20)
            : nil
        let material = Material(enabled: ShrubifyLiquidGlass.isEnabled,
                                opaque: UIAccessibility.isReduceTransparencyEnabled,
                                style: style, tint: tint)
        guard lastMaterial != material else { return }
        lastMaterial = material
        contentView.backgroundColor = .clear
        if !material.enabled {
            // Disabling Liquid Glass must never leave a grey replacement fill.
            effect = nil
            backgroundColor = .clear
            return
        }
        if material.opaque {
            effect = nil
            backgroundColor = .secondarySystemBackground
            return
        }
        backgroundColor = .clear
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: style == .clear ? .clear : .regular)
            glass.isInteractive = interactive
            glass.tintColor = tint
            effect = glass
        } else {
            effect = UIBlurEffect(style: style.blurStyle)
            if let tint { contentView.backgroundColor = tint.withAlphaComponent(0.08) }
        }
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
}

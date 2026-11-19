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
/// older supported versions get a tuned blur with the same rim and specular
/// sheen. Reduce Transparency still swaps in an opaque fill, and the rim gets
/// stronger with Increase Contrast.
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
              let style = ShrubifyGlassStyle(rawValue: raw) else { return .regular }
        return style
    }

    /// 0…1. Drives tint, sheen and rim strength together.
    static var intensity: CGFloat {
        let stored = UserDefaults.standard.object(forKey: intensityKey) as? Double ?? 0.55
        return CGFloat(min(max(stored, 0), 1))
    }

    /// The user's accent colour, or Shrubify green when none is set.
    ///
    /// Read directly rather than through `Theme`: this file is also compiled
    /// into the isolated lyrics-interaction harness, which has no Theme or
    /// settings extension.
    static var accent: UIColor {
        let stored = UserDefaults.standard.object(forKey: "accentColorRGB") as? Int ?? -1
        guard stored >= 0 else {
            return UIColor(red: 0.114, green: 0.725, blue: 0.329, alpha: 1)
        }
        return UIColor(
            red: CGFloat((stored >> 16) & 0xFF) / 255,
            green: CGFloat((stored >> 8) & 0xFF) / 255,
            blue: CGFloat(stored & 0xFF) / 255,
            alpha: 1
        )
    }

    /// A fresh plate. `radius == nil` means a capsule.
    @MainActor
    static func makePlate(radius: CGFloat? = nil, interactive: Bool = false) -> ShrubifyGlassPlate {
        ShrubifyGlassPlate(radius: radius, interactive: interactive)
    }

    /// Call after changing any key above so mounted surfaces update immediately.
    static func notifyChange() {
        onMainThreadSync {
            NotificationCenter.default.post(name: .shrubifyLiquidGlassDidChange, object: nil)
        }
    }
}

/// The material itself.
///
/// - Note: The specular sheen and rim are drawn in the layer, not as subviews,
///   so content added by callers keeps its order and hit testing.
@MainActor
final class ShrubifyGlassPlate: UIVisualEffectView {
    private let radius: CGFloat?
    private let interactive: Bool
    private let sheen = CAGradientLayer()
    private var observers: [NSObjectProtocol] = []

    init(radius: CGFloat?, interactive: Bool) {
        self.radius = radius
        self.interactive = interactive
        super.init(effect: nil)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        sheen.startPoint = CGPoint(x: 0.5, y: 0)
        sheen.endPoint = CGPoint(x: 0.5, y: 1)
        sheen.locations = [0, 0.42, 1]
        layer.addSublayer(sheen)
        if #available(iOS 26.0, *) {
            if let radius {
                cornerConfiguration = .corners(radius: .fixed(Double(radius)))
            } else {
                cornerConfiguration = .capsule()
            }
        }
        observe()
        refresh()
    }

    required init?(coder: NSCoder) { return nil }

    private func observe() {
        let center = NotificationCenter.default
        for name in [
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.increaseContrastStatusDidChangeNotification,
            Notification.Name.shrubifyLiquidGlassDidChange,
        ] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    onMainThreadSync { self?.refresh() }
                }
            )
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheen.frame = bounds
        if #unavailable(iOS 26.0) {
            layer.cornerRadius = radius ?? min(bounds.width, bounds.height) / 2
        }
        CATransaction.commit()
    }

    /// Rebuilds the material from the current settings. Idempotent and cheap.
    func refresh() {
        let style = ShrubifyLiquidGlass.style
        let intensity = ShrubifyLiquidGlass.intensity
        let contrast = UIAccessibility.isIncreaseContrastEnabled

        guard ShrubifyLiquidGlass.isEnabled else {
            effect = nil
            backgroundColor = UIColor.white.withAlphaComponent(0.12)
            contentView.backgroundColor = .clear
            sheen.isHidden = true
            layer.borderWidth = 0
            return
        }

        guard !UIAccessibility.isReduceTransparencyEnabled else {
            effect = nil
            backgroundColor = .secondarySystemBackground
            contentView.backgroundColor = .clear
            sheen.isHidden = true
            layer.borderWidth = contrast ? 1 : 0
            layer.borderColor = UIColor.label.withAlphaComponent(0.2).cgColor
            return
        }

        backgroundColor = .clear
        let tint: UIColor
        switch style {
        case .tinted:
            tint = ShrubifyLiquidGlass.accent.withAlphaComponent(
                style.baseTintAlpha * (0.4 + intensity)
            )
        case .clear, .regular:
            tint = UIColor.white.withAlphaComponent(
                style.baseTintAlpha * (0.35 + intensity * 0.9)
            )
        }

        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = interactive
            glass.tintColor = tint
            effect = glass
            contentView.backgroundColor = .clear
        } else {
            effect = UIBlurEffect(style: style.blurStyle)
            // A blur cannot carry a tint; a translucent fill over it can.
            contentView.backgroundColor = tint.withAlphaComponent(
                min(0.32, tint.cgColor.alpha * 0.6)
            )
        }

        let sheenAlpha = min(0.42, 0.10 + intensity * 0.32)
        sheen.isHidden = false
        sheen.colors = [
            UIColor.white.withAlphaComponent(sheenAlpha).cgColor,
            UIColor.white.withAlphaComponent(sheenAlpha * 0.22).cgColor,
            UIColor.clear.cgColor,
        ]
        layer.borderWidth = contrast ? 1.2 : 0.75
        layer.borderColor = UIColor.white
            .withAlphaComponent(contrast ? 0.42 : 0.16 + intensity * 0.12)
            .cgColor
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
}

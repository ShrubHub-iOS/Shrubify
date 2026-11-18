import UIKit

/// One native material per capsule, rebuilt for accessibility preference changes.
enum GlassCapsule {
    static let height: CGFloat = 60
    static var cornerRadius: CGFloat { height / 2 }
    static var hasSystemGlass: Bool { if #available(iOS 26.0, *) { return true }; return false }

    @MainActor
    static func makeGlassView(wantsInteractive: Bool, cornerRadius: CGFloat? = nil) -> (view: UIVisualEffectView, isInteractive: Bool) {
        let view = AdaptiveCapsuleGlass(interactive: wantsInteractive, radius: cornerRadius)
        return (view, hasSystemGlass && wantsInteractive && !UIAccessibility.isReduceTransparencyEnabled)
    }
}

@MainActor
private final class AdaptiveCapsuleGlass: UIVisualEffectView {
    private let radius: CGFloat?
    private let interactive: Bool
    private var observer: NSObjectProtocol?

    init(interactive: Bool, radius: CGFloat?) {
        self.radius = radius
        self.interactive = interactive
        super.init(effect: nil)
        if #available(iOS 26.0, *) {
            cornerConfiguration = radius.map { .corners(radius: .fixed(Double($0))) } ?? .capsule()
        }
        clipsToBounds = true
        layer.cornerCurve = .continuous
        refreshMaterial()
        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in onMainThreadSync { self?.refreshMaterial() } }
    }

    required init?(coder: NSCoder) { return nil }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshMaterial()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #unavailable(iOS 26.0) {
            layer.cornerRadius = radius ?? min(bounds.width, bounds.height) / 2
        }
    }

    private func refreshMaterial() {
        layer.borderWidth = UIAccessibility.isReduceTransparencyEnabled ? 0 : 0.75
        layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        if UIAccessibility.isReduceTransparencyEnabled {
            effect = nil
            backgroundColor = .secondarySystemBackground
        } else {
            backgroundColor = .clear
            if #available(iOS 26.0, *) {
                let glass = UIGlassEffect(style: .regular)
                glass.isInteractive = interactive
                glass.tintColor = UIColor.white.withAlphaComponent(0.06)
                effect = glass
            } else { effect = UIBlurEffect(style: .systemThinMaterial) }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

import UIKit

/// One native material per capsule, rebuilt for accessibility preference changes.
enum GlassCapsule {
    static let height: CGFloat = 60
    static var cornerRadius: CGFloat { height / 2 }
    static var hasSystemGlass: Bool { if #available(iOS 26.0, *) { return true }; return false }

    @MainActor
    static func makeGlassView(wantsInteractive: Bool) -> (view: UIVisualEffectView, isInteractive: Bool) {
        let view = AdaptiveCapsuleGlass(interactive: wantsInteractive)
        return (view, hasSystemGlass && wantsInteractive && !UIAccessibility.isReduceTransparencyEnabled)
    }
}

@MainActor
private final class AdaptiveCapsuleGlass: UIVisualEffectView {
    private let interactive: Bool
    private var observer: NSObjectProtocol?

    init(interactive: Bool) {
        self.interactive = interactive
        super.init(effect: nil)
        clipsToBounds = true
        layer.cornerCurve = .continuous
        refreshMaterial()
        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refreshMaterial() }
    }

    required init?(coder: NSCoder) { return nil }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshMaterial()
    }

    private func refreshMaterial() {
        layer.borderWidth = 0
        if UIAccessibility.isReduceTransparencyEnabled {
            effect = nil
            backgroundColor = .secondarySystemBackground
        } else {
            backgroundColor = .clear
            if #available(iOS 26.0, *) {
                let glass = UIGlassEffect(style: .regular)
                glass.isInteractive = interactive
                effect = glass
            } else { effect = UIBlurEffect(style: .systemThinMaterial) }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

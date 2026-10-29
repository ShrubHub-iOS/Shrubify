import EeveeSpotifyC
import UIKit

@available(iOS 26.0, *)
enum GlassKit {
    private static var paneKey: UInt8 = 0
    private static var adaptedBlurKey: UInt8 = 0
    private static var chromeKey: UInt8 = 0
    // Read once at startup. Changing modes in Settings offers Restart Now.
    static let vitrineEnabled = LiquidGlass.launchOptions.vitrineMaterial == true

    static func material() -> UIVisualEffect {
        vitrineEnabled ? ShrubVitrineGlassEffect() : UIGlassEffect(style: .regular)
    }

    static func shape(_ glass: UIView, radius: CGFloat = 16, capsule: Bool = true) {
        if vitrineEnabled {
            ShrubVitrineShapeGlass(glass, radius, capsule)
        } else if let pane = glass as? UIVisualEffectView {
            pane.cornerConfiguration = capsule ? .capsule() : .uniformCorners(radius: .fixed(radius))
        } else {
            glass.layer.cornerRadius = capsule ? glass.bounds.height / 2 : radius
            glass.layer.cornerCurve = .continuous
        }
        if let pane = glass as? UIVisualEffectView {
            applyChrome(to: pane, radius: radius, capsule: capsule)
        }
    }

    static func pane(in host: UIView, key: UnsafeRawPointer = UnsafeRawPointer(&paneKey)) -> UIVisualEffectView {
        if let pane = objc_getAssociatedObject(host, key) as? UIVisualEffectView {
            if pane.superview !== host { host.insertSubview(pane, at: 0) }
            else if host.subviews.first !== pane { host.sendSubviewToBack(pane) }
            return pane
        }
        // Vitrine's newer control-layer guidance keeps the pane first in the
        // subview tree instead of forcing a negative zPosition (which can ghost icons).
        let reduceTransparency = vitrineEnabled && UIAccessibility.isReduceTransparencyEnabled
        let pane = UIVisualEffectView(effect: reduceTransparency ? nil : material())
        if reduceTransparency { pane.contentView.backgroundColor = UIColor(white: 0.12, alpha: 0.96) }
        pane.isUserInteractionEnabled = false
        pane.overrideUserInterfaceStyle = .dark
        pane.accessibilityElementsHidden = true
        objc_setAssociatedObject(host, key, pane, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        host.insertSubview(pane, at: 0)
        applyChrome(to: pane)
        return pane
    }

    static func tint(_ pane: UIVisualEffectView, _ color: UIColor?) {
        guard let glass = pane.effect as? UIGlassEffect, glass.tintColor != color else {
            applyChrome(to: pane)
            return
        }
        // Preserve the chosen Vitrine factory when the album color changes.
        guard let effect = material() as? UIGlassEffect else { return }
        effect.tintColor = color
        pane.effect = effect
        applyChrome(to: pane)
    }

    private static func applyChrome(to pane: UIVisualEffectView, radius: CGFloat? = nil, capsule: Bool = true) {
        let overlay: UIView = {
            if let existing = objc_getAssociatedObject(pane, &chromeKey) as? UIView { return existing }
            let view = UIView()
            view.isUserInteractionEnabled = false
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            objc_setAssociatedObject(pane, &chromeKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            pane.contentView.insertSubview(view, at: 0)
            return view
        }()
        overlay.frame = pane.contentView.bounds
        let effectTint = (pane.effect as? UIGlassEffect)?.tintColor
        let fill = effectTint?.withAlphaComponent(vitrineEnabled ? 0.12 : 0.04)
            ?? UIColor.white.withAlphaComponent(vitrineEnabled ? 0.05 : 0.02)
        let stroke = effectTint?.withAlphaComponent(vitrineEnabled ? 0.28 : 0.10)
            ?? UIColor.white.withAlphaComponent(vitrineEnabled ? 0.16 : 0.08)
        overlay.backgroundColor = fill
        overlay.layer.borderColor = stroke.cgColor
        overlay.layer.borderWidth = vitrineEnabled ? 1.0 : 0.6
        overlay.layer.cornerCurve = .continuous
        let corner = capsule ? pane.bounds.height / 2 : (radius ?? pane.layer.cornerRadius)
        if corner > 0 {
            overlay.layer.cornerRadius = corner
        }
        pane.clipsToBounds = false
        pane.contentView.clipsToBounds = true
        pane.contentView.layer.cornerRadius = overlay.layer.cornerRadius
        pane.contentView.layer.cornerCurve = .continuous
        if vitrineEnabled {
            pane.layer.shadowColor = UIColor.black.cgColor
            pane.layer.shadowOpacity = 0.20
            pane.layer.shadowRadius = 20
            pane.layer.shadowOffset = CGSize(width: 0, height: 8)
        } else {
            pane.layer.shadowOpacity = 0
            pane.layer.shadowRadius = 0
            pane.layer.shadowOffset = .zero
        }
    }

    // Many Encore controls already carry a blur view; swap once, never repeatedly per layout pass.
    @discardableResult
    static func glassBlur(in view: UIView) -> Bool {
        guard let blur = view.subviews.first(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView else { return false }
        let adapted = objc_getAssociatedObject(blur, &adaptedBlurKey) as? Bool == true
        if !adapted {
            if vitrineEnabled || !(blur.effect is UIGlassEffect) {
                blur.effect = material()
            }
            shape(blur)
            objc_setAssociatedObject(blur, &adaptedBlurKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        view.backgroundColor = .clear
        return true
    }
}

enum AlbumColor {
    static private(set) var current: UIColor?

    static func publish(_ color: UIColor) {
        guard color != current else { return }
        current = color
        NotificationCenter.default.post(name: .eeveeAlbumColorChanged, object: nil)
    }
}

extension Notification.Name {
    static let eeveeAlbumColorChanged = Notification.Name("EeveeAlbumColorChanged")
}

extension UIView {
    func eeveeStripBackgrounds() {
        if self is UIVisualEffectView || self is GradientView { return }
        layer.backgroundColor = nil
        if layer is CAGradientLayer || NSStringFromClass(type(of: self)).contains("GradientView") { isHidden = true }
        layer.sublayers?.forEach { if $0 is CAGradientLayer, !($0.delegate is GradientView) { $0.isHidden = true } }
        subviews.forEach { $0.eeveeStripBackgrounds() }
    }

    func eeveeFirst<T: UIView>(_ type: T.Type, where match: (T) -> Bool = { _ in true }) -> T? {
        var queue: [UIView] = [self]
        var index = 0
        while index < queue.count {
            let next = queue[index]
            index += 1
            if let view = next as? T, match(view) { return view }
            queue += next.subviews
        }
        return nil
    }
}

extension UIColor {
    var isWhite: Bool {
        var white: CGFloat = 0, alpha: CGFloat = 0
        if getWhite(&white, alpha: &alpha) { return white > 0.95 && alpha > 0.5 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        return getRed(&r, green: &g, blue: &b, alpha: &alpha) && min(r, g, b) > 0.95 && alpha > 0.5
    }

    var isBaseSurface: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return abs(r - 0.071) < 0.02 && abs(g - 0.071) < 0.02 && abs(b - 0.071) < 0.02
    }

    var isOpaqueish: Bool {
        cgColor.alpha > 0.5
    }
}

import UIKit
import ObjectiveC.runtime

/// Public UIKit rendering operations shared with the simulator regression app.
@MainActor
enum NavigationCapsuleSurface {
    private static var key: UInt8 = 0
    private final class Clip {
        let original: CALayer?
        let mask = CAShapeLayer()
        var frame = CGRect.null
        var bounds = CGRect.null
        init(_ view: UIView) { original = view.layer.mask }
    }

    static func configure(_ bar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.backgroundColor = .clear
        bar.isTranslucent = true
    }

    static func clearMaterial(in view: UIView) {
        if let material = view as? UIVisualEffectView, material.effect != nil { material.effect = nil }
    }

    static func layout(host: UIView, systemBar: UITabBar, nativeBar: UIView, target: CGRect) {
        let proposal = target.intersection(nativeBar.bounds)
        guard !proposal.isNull, proposal.width > 0, proposal.height > 0 else { return }
        // Enforce bounds here too: an unresolved native measurement may pass the
        // entire tablet-width bar as its fallback target.
        let frame = NavigationCapsuleLayout.frame(in: nativeBar.bounds, band: proposal,
                                                  itemCount: systemBar.items?.count ?? 4)
        host.clipsToBounds = true
        host.layer.cornerRadius = frame.height / 2
        if host.frame != frame { host.frame = frame }
        if systemBar.frame != host.bounds { systemBar.frame = host.bounds }
        let clip: Clip
        if let existing = objc_getAssociatedObject(nativeBar, &key) as? Clip { clip = existing }
        else {
            clip = Clip(nativeBar)
            objc_setAssociatedObject(nativeBar, &key, clip, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        if clip.frame != frame || clip.bounds != nativeBar.bounds || nativeBar.layer.mask !== clip.mask {
            clip.frame = frame; clip.bounds = nativeBar.bounds
            clip.mask.frame = nativeBar.bounds
            clip.mask.path = UIBezierPath(roundedRect: frame, cornerRadius: frame.height / 2).cgPath
            nativeBar.layer.mask = clip.mask
        }
    }

    static func restore(_ nativeBar: UIView) {
        guard let clip = objc_getAssociatedObject(nativeBar, &key) as? Clip else { return }
        if nativeBar.layer.mask === clip.mask { nativeBar.layer.mask = clip.original }
        objc_setAssociatedObject(nativeBar, &key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Decorative geometry only: never changes Spotify's own frames or hit regions.
enum NativeGlassGeometry {
    static func miniRadius(for size: CGSize) -> CGFloat { min(22, size.width / 2, size.height / 2) }
    static func centeredContent(_ content: CGRect, in bounds: CGRect) -> CGRect? {
        guard bounds.contains(content) else { return nil }
        let half = max(bounds.midX - content.minX, content.maxX - bounds.midX)
        return CGRect(x: bounds.midX - half, y: content.minY, width: half * 2, height: content.height)
    }
    /// A compact dock may change only the margins of a verified fill-equally
    /// tab row. Reserve at least 44pt per item and keep all content reachable.
    static func compactHorizontalInset(width: CGFloat, count: Int) -> CGFloat {
        guard width.isFinite, width > 0, (2...6).contains(count) else { return 0 }
        let preferred = CGFloat(count) * 82 + 24
        return max(0, floor((width - preferred) / 2))
    }

    static func frame(bounds: CGRect, content: CGRect, miniPlayer: Bool, tabCount: Int? = nil) -> CGRect? {
        let limit = bounds.width
        guard bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              content.minX.isFinite, content.minY.isFinite,
              content.width.isFinite, content.height.isFinite,
              bounds.width > 0, bounds.height > 0,
              content.width >= 40, content.width <= limit,
              content.height >= 30, content.height <= 110 else { return nil }
        // Inset vertically so the glass capsule never touches or leaks
        // through the rectangular bar host. Allow a small horizontal lip
        // around tab content without using the full host as the shape.
        if !miniPlayer, let tabCount {
            // Do not draw a full-width slab while UIKit is still recomputing
            // the compact row's arranged-subview frames.
            guard (2...6).contains(tabCount),
                  content.width <= CGFloat(tabCount) * 82 + 40 else { return nil }
        }
        let verticalInset = max(5, (content.height - 60) / 2)
        let proposed = miniPlayer
            ? content
            : content.insetBy(dx: -6, dy: verticalInset)
        let clipped = proposed.intersection(bounds)
        guard !clipped.isNull, clipped.width >= 40, clipped.height >= 20,
              clipped.width <= limit, clipped.height <= (miniPlayer ? 110 : 88) else { return nil }
        return clipped
    }
}

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Decorative geometry only: never changes Spotify's own frames or hit regions.
enum NativeGlassGeometry {
    /// A compact dock may change only the margins of a verified fill-equally
    /// tab row. Reserve at least 44pt per item and keep all content reachable.
    static func compactHorizontalInset(width: CGFloat, count: Int) -> CGFloat {
        guard width.isFinite, width > 0, (2...6).contains(count) else { return 0 }
        let preferred = CGFloat(count) * 82 + 24
        return max(0, floor((width - preferred) / 2))
    }

    static func frame(bounds: CGRect, content: CGRect, miniPlayer: Bool) -> CGRect? {
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
        let proposed = miniPlayer
            ? content.insetBy(dx: 3, dy: 3)
            : content.insetBy(dx: -6, dy: 5)
        let clipped = proposed.intersection(bounds)
        guard !clipped.isNull, clipped.width >= 40, clipped.height >= 20,
              clipped.width <= limit, clipped.height <= 88 else { return nil }
        return clipped
    }
}

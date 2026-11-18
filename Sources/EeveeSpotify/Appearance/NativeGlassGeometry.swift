import Foundation

/// Decorative geometry only: never changes Spotify's own frames or hit regions.
enum NativeGlassGeometry {
    static func frame(bounds: CGRect, content: CGRect, miniPlayer: Bool) -> CGRect? {
        let limit: CGFloat = miniPlayer ? 680 : 560
        guard bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              content.minX.isFinite, content.minY.isFinite,
              content.width.isFinite, content.height.isFinite,
              bounds.width > 0, bounds.height > 0,
              content.width >= 40, content.width <= limit,
              content.height >= 20, content.height <= 88 else { return nil }
        let proposed = miniPlayer ? content : content.insetBy(dx: -10, dy: -4)
        let clipped = proposed.intersection(bounds)
        guard !clipped.isNull, clipped.width >= 40, clipped.height >= 20,
              clipped.width <= limit + 20, clipped.height <= 96 else { return nil }
        return clipped
    }
}

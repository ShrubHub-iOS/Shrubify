import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The navigation surface is sized by its tabs, never by tablet-wide hit slots.
struct NavigationCapsuleLayout {
    static func frame(in bounds: CGRect, band: CGRect, itemCount: Int) -> CGRect {
        let count = min(4, max(1, itemCount))
        let width = max(0, min(bounds.width - 16, CGFloat(count) * 76 + 48))
        let height = max(0, min(60, bounds.height))
        let center = min(bounds.maxX - width / 2, max(bounds.minX + width / 2, band.midX))
        let y = min(bounds.maxY - height, max(bounds.minY, band.midY - height / 2))
        return CGRect(x: center - width / 2, y: y, width: width, height: height)
    }
}

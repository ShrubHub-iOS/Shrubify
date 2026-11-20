import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
for size in [CGSize(width: 1280, height: 889), CGSize(width: 1024, height: 1366),
             CGSize(width: 421, height: 818), CGSize(width: 320, height: 568),
             CGSize(width: 390, height: 844), CGSize(width: 844, height: 390),
             CGSize(width: 700, height: 500)] {
    for large in [false, true] {
        let layout = PlayerLayout(size: size, top: 24, bottom: 21, largeText: large)
        check(layout.artwork.width == layout.artwork.height, "Foreground artwork must be square")
        check(layout.artwork.minX >= 0 && layout.artwork.maxX <= size.width, "Artwork fits container width")
        check(layout.artwork.minY >= 0 && layout.artwork.maxY <= layout.contentHeight, "Artwork fits scrollable content")
        check(layout.content.minX >= 0 && layout.content.maxX <= size.width, "Controls fit the actual pane")
        check(layout.footer.maxY <= layout.contentHeight, "Footer remains reachable")
        if layout.wide {
            check(layout.artwork.maxX < layout.content.minX, "Wide player columns must not overlap")
        } else {
            check(layout.artwork.maxY < layout.content.minY, "Vertical player metadata must not overlap art")
        }
    }
}
let tablet = PlayerLayout(size: CGSize(width: 1280, height: 889), top: 24, bottom: 21)
check(tablet.wide && tablet.artwork.height <= 560, "Landscape iPad cannot create 1280-point-tall artwork")
let resized = PlayerLayout(size: CGSize(width: 421, height: 818), top: 24, bottom: 21)
check(!resized.wide && resized.artwork.width < tablet.artwork.width, "Resizing recomputes geometry without cached device assumptions")
print("Responsive player geometry checks passed")

for width in [CGFloat(320), 414, 847, 1008, 1280] {
    for count in [3, 4] {
        let bounds = CGRect(x: 0, y: 0, width: width, height: 83)
        let rect = NavigationCapsuleLayout.frame(in: bounds, band: bounds, itemCount: count)
        check(rect.width <= 352 && rect.height <= 60, "Tablet slots cannot create an oversized navigation backing")
        check(bounds.contains(rect), "Navigation capsule stays in its own container")
        check(abs(rect.midX - bounds.midX) < 0.01, "Navigation remains centered after resizing")
    }
}
print("Bounded navigation surface checks passed")

for width in [CGFloat(320), 414, 847, 1008, 1280] {
    for count in 2...6 {
        let inset = NativeGlassGeometry.compactHorizontalInset(width: width, count: count)
        check(inset >= 0 && inset * 2 < width, "Dock margins must fit the container")
        if inset > 0 {
            check(width - inset * 2 >= CGFloat(count) * 44, "Every compact tab retains its tap target")
            check(width - inset * 2 <= CGFloat(count) * 82 + 26, "Wide tabs are content-sized")
        }
    }
}
print("Adaptive native dock geometry checks passed")

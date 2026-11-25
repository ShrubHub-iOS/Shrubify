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
for size in [CGSize(width: 1280, height: 889), CGSize(width: 421, height: 818),
             CGSize(width: 280, height: 655), CGSize(width: 1024, height: 1366),
             CGSize(width: 1024, height: 510), CGSize(width: 320, height: 290)] {
    let header = TabletPlayerLayout.headerHeight(safeTop: 24)
    let body = CGSize(width: size.width, height: size.height - header)
    for titleHeight in [CGFloat(38), 94] {
        let layout = TabletPlayerLayout(size: body, bottom: 21, titleHeight: titleHeight, artistHeight: 29)
        check(layout.artwork.width == layout.artwork.height, "iPad artwork is square")
        check(layout.lyric.height >= 44 && layout.lyric.minY > layout.artwork.maxY
            && layout.lyric.midX == layout.artwork.midX, "Live lyric stays directly under the cover")
        check(layout.lyric.maxY <= layout.contentHeight, "Live lyric stays reachable")
        check(layout.artwork.minX > 0 && layout.artwork.maxX < size.width, "iPad artwork stays inside the pane")
        check(layout.title.width <= 440 && layout.footer.width <= 292, "iPad control groups stay compact")
        check(layout.footer.width >= 220, "Five iPad footer actions retain at least 44 points each")
        check(layout.footer.minY - layout.volume.maxY == 9, "The footer remains attached to the playback controls")
        check(layout.footer.maxY + 21 < layout.contentHeight, "The whole footer remains reachable above the bottom inset")
        if body.height >= 510 {
            check(layout.footer.maxY + 21 < body.height, "The footer fits without scrolling in normal iPad panes")
        }
        if layout.wide {
            check(layout.artwork.maxX < layout.title.minX, "Wide iPad columns have a clear gutter")
        } else {
            check(layout.lyric.maxY < layout.title.minY, "Stacked iPad live lyric does not cover the title")
        }
    }
}
let fade = TabletPlayerLayout.headerFade(end: 82, height: 800)
check(fade[1] * 800 == 78 && fade[2] * 800 == 82, "The native body must be covered by the end of the header")
check(zip(fade, fade.dropFirst()).allSatisfy { $0 <= $1 }, "Fade locations remain ordered")
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

let dock = CGRect(x: 0, y: 0, width: 760, height: 76)
let shifted = CGRect(x: 242, y: 0, width: 350, height: 76)
let centered = NativeGlassGeometry.centeredContent(shifted, in: dock)!
check(centered.midX == dock.midX && centered.contains(shifted), "A temporary off-center tab footprint must not move the glass center")

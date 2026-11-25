import ObjectiveC.runtime
import SwiftUI
import UIKit

@MainActor
enum ArtworkInspector {
    private static let rejectedImages = NSHashTable<UIImage>.weakObjects()
    private static let checkedImages = NSHashTable<UIImage>.weakObjects()
    private static let coverClass = NSClassFromString(
        "_TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView"
    )

    static func isNativeCover(_ view: UIView) -> Bool {
        guard let coverClass else { return false }
        return view.isKind(of: coverClass) && NowPlayingLyricsPlate.isInsideCoverCell(view)
    }

    static func isNativeCoverCell(_ view: UIView) -> Bool {
        if let type = NowPlayingLyricsPlate.coverCellClass, view.isKind(of: type) { return true }
        let name = NSStringFromClass(type(of: view))
        return name.contains("NowPlaying_ContentLayersImpl") && name.hasSuffix("CoverArtCellImpl")
    }

    static func isCanvasCover(_ view: UIView) -> Bool {
        guard view.accessibilityIdentifier == NowPlayingLyricsPlate.coverImageIdentifier,
              view.bounds.width >= 160, view.bounds.height >= 160 else { return false }
        var parent = view.superview
        for _ in 0..<8 {
            guard let current = parent else { break }
            if current.accessibilityIdentifier?.contains("nowplaying-contentlayer-cell-5") == true
                || NSStringFromClass(type(of: current)).hasSuffix("CanvasNowPlayingCell") { return true }
            parent = current.superview
        }
        return false
    }

    static func nativeImage(in cover: UIView) -> UIImage? {
        var nodes = [cover]
        var index = 0
        while index < nodes.count {
            let view = nodes[index]
            index += 1
            let name = NSStringFromClass(type(of: view))
            guard view === cover || !view.isHidden else { continue }
            guard !name.localizedCaseInsensitiveContains("placeholder"),
                  view.accessibilityIdentifier?.localizedCaseInsensitiveContains("placeholder") != true else { continue }
            if let image = (view as? UIImageView)?.image, usableFallback(image) { return image }
            nodes.append(contentsOf: view.subviews.prefix(64 - nodes.count))
        }
        return nil
    }

    static func usableImage(_ image: UIImage) -> Bool {
        !image.isSymbolImage && NowPlayingLyricsPlate.isUsableArtwork(image)
    }

    static func usableFallback(_ image: UIImage, thumbnail: Bool = false) -> Bool {
        guard !image.isSymbolImage,
              thumbnail ? min(image.size.width, image.size.height) * image.scale >= 48 : usableImage(image)
        else { return false }
        if !checkedImages.contains(image) {
            checkedImages.add(image)
            if looksLikePlaceholder(image) { rejectedImages.add(image) }
        }
        return !rejectedImages.contains(image)
    }

    static func miniImage(in bar: UIView, title: String) -> UIImage? {
        guard bar.accessibilityIdentifier == "SPTNowPlayingBar", !title.isEmpty else { return nil }
        var nodes = [bar]
        var index = 0
        var artwork: UIImage?
        var titleMatches = false
        while index < nodes.count {
            let view = nodes[index]
            index += 1
            guard !view.isHidden, view.alpha > 0.1 else { continue }
            let label = (view as? UILabel)?.text ?? view.accessibilityLabel ?? ""
            if label == title || label.hasPrefix(title + ", ") || label.hasPrefix(title + "\n") {
                titleMatches = true
            }
            if artwork == nil, let value = (view as? UIImageView)?.image {
                let rect = view.convert(view.bounds, to: bar)
                if (30...85).contains(rect.width), abs(rect.width - rect.height) < 2,
                   rect.minX >= 0, rect.maxX <= 100, usableFallback(value, thumbnail: true) {
                    artwork = value
                }
            }
            if let artwork, titleMatches { return artwork }
            nodes.append(contentsOf: view.subviews.prefix(120 - nodes.count))
        }
        return nil
    }

    private static func looksLikePlaceholder(_ image: UIImage) -> Bool {
        guard let bitmap = image.cgImage else { return false }
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(bitmap, in: CGRect(x: 0, y: 0, width: side, height: side))
            var dark = 0
            var bright = 0
            for y in 0..<side {
                for x in 0..<side {
                    let offset = (y * side + x) * 4
                    let red = Int(bytes[offset]), green = Int(bytes[offset + 1]), blue = Int(bytes[offset + 2])
                    guard max(red, green, blue) - min(red, green, blue) < 10 else { return false }
                    if (19...44).contains(red) { dark += 1 }
                    if red >= 113 {
                        guard (4...19).contains(x), (4...19).contains(y) else { return false }
                        bright += 1
                    }
                }
            }
            return dark >= 430 && (12...108).contains(bright)
        }
    }

    /// Spotify 9.2.0 exposes handleTap as a no-argument Objective-C
    /// method on the cover. Require the same live view and enabled gesture
    /// that Spotify uses for its own tap.
    static func openNative(from cover: UIView) -> Bool {
        let action = NSSelectorFromString("handleTap")
        guard isNativeCover(cover),
              let tap = cover.gestureRecognizers?.compactMap({ $0 as? UITapGestureRecognizer }).first(where: {
                  $0.isEnabled && $0.numberOfTapsRequired == 1 && $0.numberOfTouchesRequired == 1
              }),
              let method = class_getInstanceMethod(type(of: cover), action),
              method_getNumberOfArguments(method) == 2 else { return false }
        let returnType = method_copyReturnType(method)
        defer { free(returnType) }
        guard String(cString: returnType) == "v" else { return false }
        return UIApplication.shared.sendAction(action, to: cover, from: tap, for: nil)
    }

    @available(iOS 15.0, *)
    static func present(_ image: UIImage, from source: UIView) {
        guard let target = WindowHelper.shared.viewController(for: source),
              target.viewIfLoaded?.window === source.window, target.presentedViewController == nil,
              !target.isBeingDismissed else { return }
        let modal = KaraokeModal.make(onDismiss: {}) { close in
            ArtworkDetail(image: image, close: close)
        }
        target.present(modal, animated: true)
    }
}

@available(iOS 15.0, *)
private struct ArtworkDetail: View {
    let image: UIImage
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var tilt: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let side = max(0, min(geometry.size.width - 56, geometry.size.height - 96, 680))
            VStack {
                HStack {
                    Spacer()
                    Button("Done", action: close)
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(KaraokeControlSurface())
                }
                Spacer()
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Album cover")
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(min(14, max(-14, tilt.width / 9)))), axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(min(14, max(-14, -tilt.height / 9)))), axis: (x: 1, y: 0, z: 0))
                    .gesture(DragGesture().updating($tilt) { drag, state, _ in state = drag.translation })
                Spacer()
            }
            .padding(20)
        }
        .foregroundColor(.white)
        .background(Color(white: 0.06).ignoresSafeArea())
    }
}

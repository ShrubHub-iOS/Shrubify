import ObjectiveC.runtime
import SwiftUI
import UIKit

@MainActor
enum ArtworkInspector {
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
            if let image = (view as? UIImageView)?.image, usableImage(image) { return image }
            nodes.append(contentsOf: view.subviews.prefix(64 - nodes.count))
        }
        return nil
    }

    static func usableImage(_ image: UIImage) -> Bool {
        !image.isSymbolImage && NowPlayingLyricsPlate.isUsableArtwork(image)
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

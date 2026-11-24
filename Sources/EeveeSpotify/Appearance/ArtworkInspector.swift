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

    /// The Spotify cover is still in the active page. Forward only its own
    /// enabled single-tap action, with the same sender and checked signature.
    static func openNative(from cover: UIView) -> Bool {
        guard isNativeCover(cover),
              let targets = class_getInstanceVariable(UIGestureRecognizer.self, "_targets") else { return false }
        for case let tap as UITapGestureRecognizer in cover.gestureRecognizers ?? []
        where tap.isEnabled && tap.numberOfTapsRequired == 1 && tap.numberOfTouchesRequired == 1 {
            guard let pairs = object_getIvar(tap, targets) as? [AnyObject], pairs.count <= 4 else { continue }
            for pair in pairs {
                guard let target = class_getInstanceVariable(type(of: pair), "_target"),
                      let targetEncoding = ivar_getTypeEncoding(target), targetEncoding.pointee == 64,
                      let owner = object_getIvar(pair, target), (owner as AnyObject) === cover,
                      let action = class_getInstanceVariable(type(of: pair), "_action"),
                      let encoding = ivar_getTypeEncoding(action), String(cString: encoding) == ":" else { continue }
                let pointer = Unmanaged.passUnretained(pair).toOpaque().advanced(by: ivar_getOffset(action))
                guard let raw = pointer.load(as: UnsafeRawPointer?.self) else { continue }
                let selector = unsafeBitCast(raw, to: Selector.self)
                guard let method = class_getInstanceMethod(type(of: cover), selector),
                      let returnType = method_copyReturnType(method) else { continue }
                defer { free(returnType) }
                guard String(cString: returnType) == "v" else { continue }
                switch method_getNumberOfArguments(method) {
                case 2:
                    if UIApplication.shared.sendAction(selector, to: cover, from: tap, for: nil) { return true }
                case 3:
                    guard let argument = method_copyArgumentType(method, 2) else { continue }
                    defer { free(argument) }
                    guard argument.pointee == 64 else { continue } // Objective-C object
                    if UIApplication.shared.sendAction(selector, to: cover, from: tap, for: nil) { return true }
                default:
                    continue
                }
            }
        }
        return false
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

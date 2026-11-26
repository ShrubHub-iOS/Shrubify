import ObjectiveC.runtime
import CoreMotion
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

    private static func usableFallback(_ image: UIImage) -> Bool {
        guard usableImage(image) else { return false }
        if !checkedImages.contains(image) {
            checkedImages.add(image)
            if looksLikePlaceholder(image) { rejectedImages.add(image) }
        }
        return !rejectedImages.contains(image)
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
            ArtworkDetail(image: image, close: close) { [weak source] in
                source?.window?.windowScene?.interfaceOrientation ?? .portrait
            }
        }
        target.present(modal, animated: true)
    }
}

@available(iOS 15.0, *)
private struct ArtworkDetail: View {
    let image: UIImage
    let close: () -> Void
    let orientation: () -> UIInterfaceOrientation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTilt: CGSize = .zero
    @State private var motionTilt: CGSize = .zero
    @State private var motion = CMMotionManager()
    @State private var referenceGravity: CMAcceleration?
    @State private var referenceOrientation: UIInterfaceOrientation?
    private let motionClock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    private var tilt: CGSize {
        guard !reduceMotion else { return .zero }
        return CGSize(width: limit(dragTilt.width + motionTilt.width, to: 14),
                      height: limit(dragTilt.height + motionTilt.height, to: 14))
    }

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
                    .overlay { reflection(side: side) }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Album cover")
                    .rotation3DEffect(.degrees(Double(tilt.width)), axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(.degrees(Double(-tilt.height)), axis: (x: 1, y: 0, z: 0))
                    .gesture(DragGesture()
                        .onChanged { drag in
                            guard !reduceMotion else { return }
                            dragTilt = CGSize(width: drag.translation.width / 9, height: drag.translation.height / 9)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { dragTilt = .zero }
                        })
                Spacer()
            }
            .padding(20)
        }
        .foregroundColor(.white)
        .background(Color(white: 0.06).ignoresSafeArea())
        .onAppear(perform: updateMotion)
        .onChange(of: reduceMotion) { _ in updateMotion() }
        .onReceive(motionClock) { _ in sampleMotion() }
        .onDisappear { motion.stopDeviceMotionUpdates() }
    }

    private func reflection(side: CGFloat) -> some View {
        let x = tilt.width / 14
        let y = tilt.height / 14
        let strength = Double(min(1, hypot(x, y)))
        return RadialGradient(
            colors: [.white.opacity(0.24 * strength), .white.opacity(0.07 * strength), .clear],
            center: UnitPoint(x: 0.48 - 0.54 * x, y: 0.27 - 0.52 * y),
            startRadius: 0, endRadius: side * 0.65
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func updateMotion() {
        if reduceMotion {
            motion.stopDeviceMotionUpdates()
            referenceGravity = nil
            motionTilt = .zero
            dragTilt = .zero
        } else if motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive {
            motion.deviceMotionUpdateInterval = 1.0 / 30
            motion.startDeviceMotionUpdates()
        }
    }

    private func sampleMotion() {
        guard !reduceMotion, let gravity = motion.deviceMotion?.gravity else { return }
        let current = orientation()
        guard let reference = referenceGravity, referenceOrientation == current else {
            referenceGravity = gravity
            referenceOrientation = current
            motionTilt = .zero
            return
        }
        let x = CGFloat(gravity.x - reference.x)
        let y = CGFloat(gravity.y - reference.y)
        let horizontal: CGFloat
        let vertical: CGFloat
        switch current {
        case .landscapeLeft: (horizontal, vertical) = (y, x)
        case .landscapeRight: (horizontal, vertical) = (-y, -x)
        case .portraitUpsideDown: (horizontal, vertical) = (-x, y)
        default: (horizontal, vertical) = (x, -y)
        }
        let targetX = limit(horizontal * 36, to: 11)
        let targetY = limit(vertical * 36, to: 11)
        guard abs(targetX - motionTilt.width) > 0.12 || abs(targetY - motionTilt.height) > 0.12 else { return }
        motionTilt = CGSize(width: 0.72 * motionTilt.width + 0.28 * targetX,
                            height: 0.72 * motionTilt.height + 0.28 * targetY)
    }

    private func limit(_ value: CGFloat, to range: CGFloat) -> CGFloat {
        min(range, max(-range, value))
    }
}

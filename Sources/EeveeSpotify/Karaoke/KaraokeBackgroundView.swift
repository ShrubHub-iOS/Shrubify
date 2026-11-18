import SwiftUI
import MetalKit

/// Animated backdrop behind the karaoke lyrics. Prefers the real
/// Metal-based domain-warp renderer (KaraokeMetalBackgroundView, the
/// native analog of the real extension's Kawarp WebGL warp/blur) when the
/// album art image itself is available and Metal is supported on-device.
/// Falls back to a simpler animated gradient using extracted dominant
/// colors (AlbumArtColorExtractor) — or fixed placeholder colors if even
/// that fails, e.g. if Spotify hasn't published artwork to
/// MPNowPlayingInfoCenter yet and the UIView-walking fallback also comes
/// up empty, or if Metal itself is unavailable (e.g. simulator).
@available(iOS 15.0, *)
struct KaraokeBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = UIApplication.shared.applicationState == .active
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var artworkGeneration = UUID()
    @State private var albumArtImage: UIImage?
    @State private var colors: [Color] = KaraokeBackgroundView.placeholderColors

    private static let placeholderColors: [Color] = [
        Color(red: 0.07, green: 0.35, blue: 0.45),
        Color(red: 0.10, green: 0.55, blue: 0.40),
        Color(red: 0.05, green: 0.20, blue: 0.55),
    ]

    private static let metalRendererSupported: Bool = {
        guard let device = MTLCreateSystemDefaultDevice() else { return false }
        return KaraokeBackgroundRenderer(device: device) != nil
    }()

    var body: some View {
        Group {
            if let albumArtImage = albumArtImage,
               albumArtImage.size.width > 1, albumArtImage.size.height > 1,
               KaraokeBackgroundView.metalRendererSupported, active, !reduceMotion, !lowPower {
                KaraokeMetalBackgroundView(albumArt: albumArtImage)
                    .ignoresSafeArea()
            } else {
                gradientFallback
            }
        }
        .onAppear {
            let generation = UUID()
            artworkGeneration = generation
            loadAlbumArt()
            // Now Playing artwork can arrive slightly after the track transition.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if artworkGeneration == generation { loadAlbumArt() }
            }
        }
        .onDisappear { artworkGeneration = UUID() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in active = false }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in active = true }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
    }

    @ViewBuilder private var gradientFallback: some View {
        if reduceMotion || lowPower || !active {
            gradient(at: 0)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
                gradient(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func gradient(at time: TimeInterval) -> some View {
        RadialGradient(colors: colors, center: animatedCenter(t: time), startRadius: 20, endRadius: 500)
            .ignoresSafeArea().background(Color.black)
    }

    /// AlbumArtLocator now checks MPNowPlayingInfoCenter's published artwork
    /// first (reliable, no view-hierarchy timing concerns) and only falls
    /// back to walking the Now Playing UIView tree if that's unavailable.
    /// Reading NowPlayingInfo must happen on the main thread, which
    /// AlbumArtLocator itself already handles — this call stays on
    /// .onAppear's (main-thread) caller for that reason. If found, we both
    /// keep the raw image (for the Metal path) and kick off color
    /// extraction in the background (for the gradient fallback path, in
    /// case Metal setup fails downstream even though the image itself was
    /// found).
    private func loadAlbumArt() {
        guard let image = AlbumArtLocator.currentAlbumArt() else {
            writeDebugLog("[Karaoke] no album art view found — using placeholder gradient")
            return
        }
        albumArtImage = image
        extractColors(from: image)
    }

    private func extractColors(from image: UIImage) {
        let generation = artworkGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            let extracted = AlbumArtColorExtractor.dominantColors(from: image, count: 3)
            guard extracted.count >= 2 else {
                writeDebugLog("[Karaoke] album art color extraction returned too few colors (\(extracted.count)) — using placeholder gradient")
                return
            }
            let swiftUIColors = extracted.map { Color($0) }
            DispatchQueue.main.async {
                if generation == artworkGeneration { colors = swiftUIColors }
            }
        }
    }

    private func animatedCenter(t: TimeInterval) -> UnitPoint {
        // Slow Lissajous-style drift so the gradient feels alive without
        // being distracting behind moving text.
        let x = 0.5 + 0.3 * sin(t * 0.13)
        let y = 0.5 + 0.3 * cos(t * 0.09)
        return UnitPoint(x: x, y: y)
    }
}

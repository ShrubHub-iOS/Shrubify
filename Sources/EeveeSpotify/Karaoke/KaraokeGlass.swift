import SwiftUI
import UIKit

/// Glass belongs only to the standalone lyrics modal, never to Spotify's player.
enum KaraokeGlass {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "ShrubifyCustomLyricsGlass") as? Bool ?? true
    }
}

@available(iOS 15.0, *)
struct KaraokeGlassCapsule: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = GlassCapsule.makeGlassView(wantsInteractive: false).view
        view.overrideUserInterfaceStyle = .dark
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }
    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.layer.cornerRadius = min(view.bounds.width, view.bounds.height) / 2
    }
}

@available(iOS 15.0, *)
struct KaraokeControlSurface: View {
    var body: some View {
        Group {
            if KaraokeGlass.isEnabled { KaraokeGlassCapsule() }
            else { Capsule().fill(Color.white.opacity(0.10)) }
        }.allowsHitTesting(false)
    }
}

@available(iOS 15.0, *)
struct KaraokePlaybackSurface: View {
    var body: some View {
        KaraokeControlSurface().allowsHitTesting(false)
    }
}

@available(iOS 15.0, *)
struct KaraokeTimingControls: View {
    @Binding var offset: Int
    var body: some View {
        HStack(spacing: 0) {
            Button { offset = KaraokeTiming.adjustedOffset(offset, step: -100) } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }.accessibilityLabel("Lyrics earlier by 0.1 seconds").disabled(offset <= -5000)
            Button { offset = 0 } label: {
                Text(offset == 0 ? "0.0 s" : String(format: "%+.1f s", Double(offset) / 1000))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .frame(width: 66, height: 44)
            }.accessibilityLabel("Lyrics delay, reset to zero").accessibilityValue("\(offset) milliseconds")
            Button { offset = KaraokeTiming.adjustedOffset(offset, step: 100) } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }.accessibilityLabel("Lyrics later by 0.1 seconds").disabled(offset >= 5000)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white).buttonStyle(.plain)
        .background(KaraokeControlSurface())
    }
}

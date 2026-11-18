import SwiftUI
import UIKit

/// Glass belongs only to the standalone lyrics modal, never to Spotify's player.
enum KaraokeGlass {
    static var isEnabled: Bool {
        if #available(iOS 26.0, *) {
            return UserDefaults.standard.object(forKey: "ShrubifyCustomLyricsGlass") as? Bool ?? true
        }
        return false
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *), KaraokeGlass.isEnabled, !reduceTransparency {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .glassEffect(.regular.tint(.black.opacity(0.35)), in: .rect(cornerRadius: 26))
                .allowsHitTesting(false)
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(reduceTransparency ? 1 : 0.55))
                .allowsHitTesting(false)
        }
    }
}

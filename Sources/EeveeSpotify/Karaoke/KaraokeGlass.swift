import SwiftUI
import UIKit

/// Glass belongs only to the standalone lyrics modal, never to Spotify's player.
enum KaraokeGlass {
    static var isEnabled: Bool {
        if #available(iOS 26.0, *) {
            return UserDefaults.standard.bool(forKey: "ShrubifyCustomLyricsGlass")
        }
        return false
    }
}

@available(iOS 15.0, *)
struct KaraokeGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        view.overrideUserInterfaceStyle = .dark
        view.isUserInteractionEnabled = false
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.tintColor = UIColor.black.withAlphaComponent(0.25)
            view.effect = effect
        }
        return view
    }
    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

@available(iOS 15.0, *)
struct KaraokeGlassCapsule: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = KaraokeCapsuleEffectView(effect: nil)
        view.overrideUserInterfaceStyle = .dark
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        if #available(iOS 26.0, *) { view.effect = UIGlassEffect(style: .regular) }
        return view
    }
    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.layer.cornerRadius = min(view.bounds.width, view.bounds.height) / 2
    }
}

private final class KaraokeCapsuleEffectView: UIVisualEffectView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

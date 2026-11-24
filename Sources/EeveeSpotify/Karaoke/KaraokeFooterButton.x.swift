import Foundation
import Orion
import UIKit
import ObjectiveC.runtime

struct KaraokeFooterGroup: HookGroup {}

class KaraokeFooterUnitHook: ClassHook<UIViewController> {
    typealias Group = KaraokeFooterGroup
    static let targetName = "_TtC20NowPlaying_ModesImpl18FooterElementsUnit"
    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard let root = target.viewIfLoaded else { return }
        KaraokeFooterButton.attach(to: root)
    }
}

/// The custom lyrics entry. It joins the native footer row when one can be
/// recognised (iPhone), and falls back to a floating Liquid Glass button on the
/// player root (iPad, where the native footer layout differs). Every host owns
/// its own button; no synthetic hit testing or stolen touches.
enum KaraokeFooterButton {
    private static var key: UInt8 = 0
    private static let hosts = NSHashTable<UIView>.weakObjects()
    private static let observer = NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged,
        object: nil, queue: .main) { _ in hosts.allObjects.forEach { attach(to: $0) } }

    static func attach(to root: UIView) {
        _ = observer
        hosts.add(root)
        onMainThreadSync { attachOnMain(root) }
    }

    @MainActor
    private static func attachOnMain(_ root: UIView) {
        guard root.bounds.width > 1, root.bounds.height > 1 else { return }

        let button: UIButton
        if let old = objc_getAssociatedObject(root, &key) as? UIButton {
            button = old
        } else {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: "quote.bubble.fill")
            config.baseForegroundColor = .white
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            // A 44pt touch target without fixed constraints, so the button can
            // move between a stack row and the floating position without conflicts.
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            button = UIButton(configuration: config)
            button.accessibilityLabel = "Custom lyrics"
            button.accessibilityHint = "Open fullscreen custom lyrics"
            button.accessibilityIdentifier = "shrubify-custom-lyrics-button"
            button.backgroundColor = .clear
            button.addAction(UIAction { _ in KaraokeOverlayPresenter.present() }, for: .primaryActionTriggered)
            objc_setAssociatedObject(root, &key, button, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        let available = KaraokeOverlayPresenter.canOpenForCurrentTrack()
        button.isHidden = !available
        guard available else { return }
        if attachToFooterRow(button, in: root) { return }
        attachAsFloating(button, in: root)
    }

    /// The existing behaviour: join a wide horizontal footer row.
    @MainActor
    private static func attachToFooterRow(_ button: UIButton, in root: UIView) -> Bool {
        var queue = [root]; var index = 0
        while index < queue.count && index < 128 {
            let candidate = queue[index]; index += 1
            if let row = candidate as? UIStackView, row.axis == .horizontal,
               row.arrangedSubviews.filter({ $0 !== button }).count >= 2,
               row.bounds.width >= 176 {
                if button.superview !== row {
                    button.removeFromSuperview()
                    button.autoresizingMask = []
                    button.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(button)
                }
                return true
            }
            queue.append(contentsOf: candidate.subviews)
        }
        return false
    }

    /// iPad's native footer has no matching stack on every build. Keep the
    /// entry visible instead of silently dropping the button.
    @MainActor
    private static func attachAsFloating(_ button: UIButton, in root: UIView) {
        guard button.superview !== root else { return }
        button.removeFromSuperview()
        button.translatesAutoresizingMaskIntoConstraints = true
        // Bottom-leading, where Apple Music keeps its lyrics key — it stays
        // clear of Spotify's share and queue buttons on the trailing side.
        button.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
        button.frame = CGRect(
            x: 16,
            y: max(0, root.bounds.height - 56),
            width: 44,
            height: 44
        )
        root.addSubview(button)
    }
}

func activateKaraokeFooterButton() {
    guard UserDefaults.shouldReplaceLyrics,
          let cls = NSClassFromString("_TtC20NowPlaying_ModesImpl18FooterElementsUnit") as? UIViewController.Type,
          class_getInstanceMethod(cls, #selector(UIViewController.viewDidLayoutSubviews)) != nil else { return }
    KaraokeFooterGroup().activate()
}

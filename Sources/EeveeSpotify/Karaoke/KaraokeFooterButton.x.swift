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

/// An additional arranged button gets its own space; it never overlays AirPlay,
/// queue or native lyrics controls. Each footer/window owns its own button.
enum KaraokeFooterButton {
    private static var key: UInt8 = 0
    private static let hosts = NSHashTable<UIView>.weakObjects()
    private static let observer = NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged,
        object: nil, queue: .main) { _ in hosts.allObjects.forEach { attach(to: $0) } }

    static func attach(to root: UIView) {
        _ = observer
        hosts.add(root)
        let button: UIButton
        if let old = objc_getAssociatedObject(root, &key) as? UIButton { button = old }
        else {
            var config = UIButton.Configuration.plain()
            config.title = "Custom lyrics"
            config.baseForegroundColor = .white
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6)
            button = UIButton(configuration: config)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.accessibilityIdentifier = "shrubify-custom-lyrics-button"
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(UIAction { _ in KaraokeOverlayPresenter.present() }, for: .primaryActionTriggered)
            objc_setAssociatedObject(root, &key, button, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let available = KaraokeOverlayPresenter.isAvailableForCurrentTrack()
        button.isHidden = !available
        guard available else { return }
        var queue = [root]; var index = 0
        while index < queue.count && index < 128 {
            let candidate = queue[index]; index += 1
            if let row = candidate as? UIStackView, row.axis == .horizontal,
               row.arrangedSubviews.filter({ $0 !== button }).count >= 2,
               row.bounds.width >= 280 {
                if button.superview !== row { button.removeFromSuperview(); row.addArrangedSubview(button) }
                return
            }
            queue.append(contentsOf: candidate.subviews)
        }
    }
}

func activateKaraokeFooterButton() {
    guard UserDefaults.shouldReplaceLyrics,
          let cls = NSClassFromString(KaraokeFooterUnitHook.targetName) as? UIViewController.Type,
          class_getInstanceMethod(cls, #selector(UIViewController.viewDidLayoutSubviews)) != nil else { return }
    KaraokeFooterGroup().activate()
}

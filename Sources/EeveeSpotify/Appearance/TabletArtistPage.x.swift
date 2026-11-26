import Orion
import UIKit

struct TabletArtistPageHookGroup: HookGroup {}

class TabletArtistPageHook: ClassHook<UIView> {
    typealias Group = TabletArtistPageHookGroup
    static let targetName = "_TtC32CreativeWorkPlatform_TemplateKit12TemplateView"

    func layoutSubviews() {
        orig.layoutSubviews()
        let page = target
        onMainThreadSync { TabletArtistPage.update(page) }
    }
}

@MainActor
private enum TabletArtistPage {
    static func update(_ page: UIView) {
        guard page.accessibilityIdentifier == "creator-page", page.window != nil,
              page.bounds.width > 240 else { return }
        var nodes = [page]
        var index = 0
        var feed: UIScrollView?
        var header: UIView?
        while index < nodes.count {
            let view = nodes[index]
            index += 1
            guard !view.isHidden else { continue }
            let frame = view.convert(view.bounds, to: page)
            if feed == nil, let scroll = view as? UIScrollView, frame.width >= page.bounds.width * 0.85,
               frame.height >= page.bounds.height * 0.6 {
                feed = scroll
                continue
            }
            let name = NSStringFromClass(type(of: view))
            if frame.width >= page.bounds.width * 0.8, (35...134).contains(frame.height),
               frame.minY <= page.safeAreaInsets.top + 16,
               view is UINavigationBar || name.contains("HeaderNavigationBar") {
                header = view
            }
            nodes.append(contentsOf: view.subviews.prefix(140 - nodes.count))
        }
        guard let feed else { return }
        let controller = WindowHelper.shared.viewController(for: page)
        if let bar = header ?? controller?.navigationController?.navigationBar {
            let ID = "shrubify.artist.header.contrast"
            let scrim = bar.subviews.first { $0.accessibilityIdentifier == ID } ?? UIView()
            if scrim.superview == nil {
                scrim.accessibilityIdentifier = ID
                scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                scrim.isUserInteractionEnabled = false
                scrim.accessibilityElementsHidden = true
                scrim.frame = bar.bounds
                scrim.backgroundColor = UIColor(white: 0.055, alpha: 0.96)
                bar.insertSubview(scrim, at: 0)
            }
            scrim.isHidden = feed.contentOffset.y + feed.adjustedContentInset.top < 62
        }
        // Reserve room to scroll the last artist sections above the floating dock.
        if NativeTabletGlass.isOnForCurrentDevice, ShrubifyLiquidGlass.isEnabled,
           feed.adjustedContentInset.bottom < 82 {
            var insets = feed.contentInset
            insets.bottom += 82 - feed.adjustedContentInset.bottom
            feed.contentInset = insets
        }
    }
}

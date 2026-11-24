import UIKit
import Orion
import ObjectiveC.runtime

/// Adds a restrained readability scrim to an actual Canvas video layer on
/// iPad, never to album artwork or Spotify controls. Native playback remains
/// in charge of presentation, gestures, and state.
@MainActor
enum NativeTabletCanvasReadability {
    private final class PageState {
        weak var cell: UIView?
        weak var overlay: UIView?
        weak var videoRoot: UIView?
        var lastLookup: TimeInterval = 0
    }

    private static let pages = NSMapTable<UIView, PageState>.weakToStrongObjects()
    private static let overlayID = "shrubify.canvas.readability"

    static func layout(in page: UIView) {
        let state: PageState
        if let existing = pages.object(forKey: page) { state = existing }
        else {
            state = PageState()
            pages.setObject(state, forKey: page)
        }

        guard EvolvedInterfaceAvailability.usesNativeTabletInterface,
              UserDefaults.nowPlayingIOS27,
              !UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode"),
              page.window != nil else {
            remove(state)
            state.lastLookup = 0
            return
        }

        if let cell = state.cell, let overlay = state.overlay,
           let video = state.videoRoot,
           overlay.superview === cell, video.superview === cell,
           isCanvasCell(cell, in: page), isVisible(cell, in: page),
           !video.isHidden, video.alpha > 0.01, video.layer.zPosition == 0,
           let videoIndex = cell.subviews.firstIndex(of: video) {
            let now = ProcessInfo.processInfo.systemUptime
            if now - state.lastLookup < 1 || videoRoot(in: cell) === video {
                if now - state.lastLookup >= 1 { state.lastLookup = now }
                if cell.subviews.dropFirst(videoIndex + 1).first !== overlay {
                    cell.insertSubview(overlay, aboveSubview: video)
                }
                resize(overlay, in: cell)
                return
            }
        }
        let hadOverlay = state.overlay != nil
        remove(state)
        let now = ProcessInfo.processInfo.systemUptime
        guard hadOverlay || now - state.lastLookup >= 0.5 else { return }
        state.lastLookup = now

        guard let (cell, video) = canvas(in: page) else { return }

        let overlay = UIView(frame: cell.bounds)
        overlay.accessibilityIdentifier = overlayID
        overlay.isUserInteractionEnabled = false
        overlay.isAccessibilityElement = false
        overlay.accessibilityElementsHidden = true
        overlay.backgroundColor = .clear
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Artwork remains colorful. Darkening grows only toward the track
        // metadata and transport region so bright Canvas frames don't wash out
        // white text. The scrim sits directly above VIDEO, not above controls.
        let shade = CAGradientLayer()
        shade.name = "shrubify.canvas.readability.gradient"
        shade.frame = overlay.bounds
        shade.startPoint = CGPoint(x: 0.5, y: 0)
        shade.endPoint = CGPoint(x: 0.5, y: 1)
        shade.locations = [0, 0.30, 0.68, 1]
        shade.colors = [
            UIColor.black.withAlphaComponent(0.27).cgColor,
            UIColor.black.withAlphaComponent(0.06).cgColor,
            UIColor.black.withAlphaComponent(0.47).cgColor,
            UIColor.black.withAlphaComponent(0.65).cgColor,
        ]
        overlay.layer.addSublayer(shade)
        cell.insertSubview(overlay, aboveSubview: video)
        state.cell = cell
        state.overlay = overlay
        state.videoRoot = video
    }

    private static func resize(_ overlay: UIView, in cell: UIView) {
        if overlay.frame != cell.bounds { overlay.frame = cell.bounds }
        if let gradient = overlay.layer.sublayers?.first as? CAGradientLayer,
           gradient.frame != overlay.bounds {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = overlay.bounds
            CATransaction.commit()
        }
    }

    private static func remove(_ state: PageState) {
        state.overlay?.removeFromSuperview()
        state.cell = nil
        state.overlay = nil
        state.videoRoot = nil
    }

    private static func canvas(in page: UIView) -> (cell: UIView, video: UIView)? {
        var nodes = [page]
        var index = 0
        while index < nodes.count, index < 1400 {
            let view = nodes[index]
            index += 1
            guard !view.isHidden, view.alpha > 0.01 else { continue }
            if isCanvasCell(view, in: page), let video = videoRoot(in: view) {
                return (view, video)
            }
            if nodes.count < 1400 {
                nodes.append(contentsOf: view.subviews.prefix(1400 - nodes.count))
            }
        }
        return nil
    }

    private static func isCanvasCell(_ view: UIView, in page: UIView) -> Bool {
        guard let identifier = view.accessibilityIdentifier,
              identifier.contains("nowplaying-contentlayer-cell-5") else { return false }
        return view.bounds.width > 180 && view.bounds.height > 280
            && view.window === page.window
            && view.convert(view.bounds, to: page).intersects(page.bounds)
    }

    private static func isVisible(_ view: UIView, in page: UIView) -> Bool {
        var ancestor: UIView? = view
        while let node = ancestor, !node.isHidden, node.alpha > 0.01 {
            if node === page { return true }
            ancestor = node.superview
        }
        return false
    }

    /// Find the direct child that actually owns AV playback. This strict
    /// predicate intentionally leaves unfamiliar Spotify versions untouched.
    private static func videoRoot(in cell: UIView) -> UIView? {
        for child in cell.subviews {
            guard !child.isHidden, child.alpha > 0.01, child.layer.zPosition == 0,
                  child.bounds.width >= cell.bounds.width * 0.7,
                  child.bounds.height >= cell.bounds.height * 0.7,
                  !containsControls(in: child) else { continue }
            var nodes = [child]
            var index = 0
            while index < nodes.count, index < 90 {
                let node = nodes[index]
                index += 1
                if hasPlaybackLayer(node.layer, depth: 0) { return child }
                if nodes.count < 90 {
                    nodes.append(contentsOf: node.subviews.prefix(90 - nodes.count))
                }
            }
        }
        return nil
    }

    /// A video root containing text or buttons must not be shaded, because
    /// we cannot prove the overlay would sit below those native controls.
    private static func containsControls(in root: UIView) -> Bool {
        var nodes = [root]
        var index = 0
        while index < nodes.count, index < 100 {
            let view = nodes[index]
            index += 1
            if view is UILabel || view is UIControl || view.isAccessibilityElement { return true }
            guard view.subviews.count <= 100 - nodes.count else { return true }
            nodes.append(contentsOf: view.subviews)
        }
        return false
    }

    private static func hasPlaybackLayer(_ layer: CALayer, depth: Int) -> Bool {
        guard !layer.isHidden, layer.opacity > 0.01 else { return false }
        let name = NSStringFromClass(type(of: layer))
        if name.contains("AVPlayerLayer") || name.contains("AVSampleBufferDisplayLayer") {
            return true
        }
        guard depth < 5 else { return false }
        for child in layer.sublayers ?? [] where hasPlaybackLayer(child, depth: depth + 1) {
            return true
        }
        return false
    }
}

struct NativeTabletCanvasReadabilityGroup: HookGroup {}

class NativeTabletCanvasReadabilityHook: ClassHook<UIViewController> {
    typealias Group = NativeTabletCanvasReadabilityGroup
    static let targetName = "NowPlaying_ScrollImpl.NPVScrollViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        let controller = target
        onMainThreadSync {
            guard let page = controller.viewIfLoaded else { return }
            NativeTabletCanvasReadability.layout(in: page)
        }
    }
}

func activateNativeTabletCanvasReadability() {
    guard EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    let name = NativeTabletCanvasReadabilityHook.targetName
    guard let cls = NSClassFromString(name) as? UIViewController.Type,
          class_getInstanceMethod(cls, #selector(UIViewController.viewDidLayoutSubviews)) != nil
    else { return }
    NativeTabletCanvasReadabilityGroup().activate()
}

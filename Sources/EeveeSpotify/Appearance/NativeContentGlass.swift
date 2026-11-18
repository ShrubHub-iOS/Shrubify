import UIKit
import ObjectiveC.runtime

/// Materials for native iPad content. Identification is by Spotify view identity,
/// never by a translated label or a button-sized rectangle somewhere on screen.
@MainActor
enum NativeContentGlass {
    enum Surface {
        case shortcut, card, artwork, row, control, tabIcon

        func accepts(_ size: CGSize) -> Bool {
            guard size.width.isFinite, size.height.isFinite else { return false }
            switch self {
            case .shortcut: return (80...600).contains(size.width) && (36...220).contains(size.height)
            case .card: return (80...480).contains(size.width) && (60...520).contains(size.height)
            case .artwork: return (40...680).contains(size.width) && (0.8...1.25).contains(size.width / max(1, size.height))
            case .row: return size.width >= 100 && (32...112).contains(size.height)
            case .tabIcon: return size.width >= 28 && (24...96).contains(size.height)
            case .control: return (22...240).contains(size.width) && (22...96).contains(size.height)
            }
        }

        var radius: CGFloat? {
            switch self {
            case .shortcut, .row: return 12
            case .card, .artwork: return 16
            case .control, .tabIcon: return nil // pill or circle, according to the native control
            }
        }
    }

    private static let ids: [String: Surface] = [
        "Shortcut.Card.Home": .shortcut, "Components.UI.CardLibrary": .card,
        "Album.Row.Library": .row, "Playlist.Row.Library": .row, "Podcast.Row.Library": .row,
        "Components.UI.LikedSongs.Row": .row, "Components.UI.CardLibrary.Artwork": .artwork,
        "CreativeWorkPlatform.Components.UI.ArtWorkElement.WithCoverArt": .artwork,
        "Components.Header.UI.ArtworkImage": .artwork,
        "SPTNowPlayingPreviousTrackButton": .control, "SPTNowPlayingPlayButton": .control,
        "SPTNowPlayingNextTrackButton": .control, "Nowplaying-RepeatButton": .control,
        "QueueButtonNowPlaying": .control, "ShareButtonNowPlayingView": .control,
        "now-playing-minimize-button": .control, "lyrics-expand-button": .control,
        "Components.ConnectButtonOutputSwitcher": .control, "header-play-button": .control,
        "Components.UI.ShuffleButton": .control, "Components.UI.AddToButton": .control,
        "Components.UI.SideDrawerButton": .control
    ]
    private static let classes: [String: Surface] = [
        "EncoreConsumerMobile_BaseKit.FilterChipView": .control,
        "EncoreConsumerMobile_BaseKit.NavChipView": .control,
        "EncoreConsumerMobile_BaseKit.ChipView": .control,
        "NavigationUI_TabBarImpl.TabBarItemElementView": .tabIcon,
        "CreateMenu_TabBarItemImpl.CreateMenuTabBarItemView": .tabIcon,
        "Home_EvoECMKit.CardArtworkView": .artwork,
        "Home_EvoECMKit.OverlayedTitleCardView": .card,
        "Martini_ElementImpl.TrackRowView": .row, "Queue_ScrollCardImpl.QueueUpNextTrackRowView": .row,
        "ListUXPlatformConsumers_DefaultItemListRowPluginImpl.TrackRowElementUI": .row,
        "Prerelease_PrereleaseImpl.AlbumTrackCell": .row
    ]
    private static let hosts = NSHashTable<UIView>.weakObjects()
    private static let pendingCells = NSHashTable<UICollectionViewCell>.weakObjects()
    private static var key: UInt8 = 0

    @MainActor private final class Decoration {
        let surface: Surface
        let plate: UIVisualEffectView
        var maskSize: CGSize = .zero
        var maskRadius: CGFloat = -1
        init(_ surface: Surface) {
            self.surface = surface
            plate = GlassCapsule.makeGlassView(wantsInteractive: false, cornerRadius: surface.radius).view
            plate.accessibilityIdentifier = "shrubify.native.content.material"
            plate.isUserInteractionEnabled = false
            plate.accessibilityElementsHidden = true
        }
    }

    private static func surface(for view: UIView) -> Surface? {
        if let id = view.accessibilityIdentifier {
            if let surface = ids[id] { return surface }
            if id.hasPrefix("TabBar.Item.") { return .tabIcon }
        }
        if let surface = classes[NSStringFromClass(type(of: view))] { return surface }
        // Home shelves use ordinary cells/image holders too. Scope both matches
        // to Spotify's carousel; Encore.ImageView alone also matches tiny icons.
        if view is UICollectionViewCell || view.accessibilityIdentifier == "Encore.ImageView" {
            var parent = view.superview
            for _ in 0..<16 {
                guard let current = parent else { break }
                if let collection = current as? UICollectionView {
                    if NSStringFromClass(type(of: collection)) == "Home_CarouselKit.TouchCancellingCollectionView" {
                        return view is UICollectionViewCell ? .card : .artwork
                    }
                    if view is UICollectionViewCell { break }
                }
                if !(view is UICollectionViewCell),
                   current.accessibilityIdentifier == "SPTNowPlayingView" || NSStringFromClass(type(of: current)).hasPrefix("Home_FunkisPageImpl.") {
                    return .artwork
                }
                parent = current.superview
            }
        }
        return nil
    }

    static func remove(from host: UIView) {
        guard let old = objc_getAssociatedObject(host, &key) as? Decoration else { return }
        old.plate.removeFromSuperview()
        objc_setAssociatedObject(host, &key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        hosts.remove(host)
    }

    static func removeAll() { for host in hosts.allObjects { remove(from: host) } }

    /// Full-window discovery calls this once per node. Reuse and navigation use
    /// bounded local layout passes instead of rescanning the window on scroll.
    @available(iOS 26.0, *)
    static func update(_ host: UIView) {
        guard host.window != nil, !host.isHidden, let surface = surface(for: host),
              surface.accepts(host.bounds.size) else { remove(from: host); return }
        // Album wrappers and nested Encore chips sometimes expose the same
        // surface at two levels. Never stack two plates on the same footprint.
        var ancestor = host.superview
        for _ in 0..<5 {
            guard let parent = ancestor, parent.bounds.size == host.bounds.size else { break }
            if let outer = objc_getAssociatedObject(parent, &key) as? Decoration, outer.surface == surface {
                remove(from: host); return
            }
            ancestor = parent.superview
        }
        let owner = (host as? UICollectionViewCell)?.contentView ?? host
        let old = objc_getAssociatedObject(host, &key) as? Decoration
        let mount = materialMount(in: owner, surface: surface)
        var frame = mount.bounds.insetBy(dx: surface == .row ? 4 : 0, dy: surface == .row ? 2 : 0)
        if surface == .tabIcon {
            guard let well = iconFrame(in: mount) else { remove(from: host); return }
            frame = well
        }
        if mount.subviews.contains(where: { $0 !== old?.plate && ($0 as? UIVisualEffectView)?.effect is UIGlassEffect }) {
            remove(from: host); return
        }
        let decoration: Decoration
        if let old, old.surface == surface { decoration = old }
        else {
            remove(from: host)
            decoration = Decoration(surface)
            objc_setAssociatedObject(host, &key, decoration, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            hosts.add(host)
        }
        let plate = decoration.plate
        let siblings = mount.subviews.filter { $0 !== plate }
        // Sit above flat fill views but below every label, thumbnail and native
        // control. Keeping the actual fill preserves selected/highlight colors.
        let index = surface == .artwork ? siblings.count : siblings.prefix { child in
            type(of: child) == UIView.self && child.subviews.isEmpty && child.frame == mount.bounds
        }.count
        if plate.superview !== mount || mount.subviews.firstIndex(of: plate) != index {
            mount.insertSubview(plate, at: index)
        }
        if plate.frame != frame { plate.frame = frame }
        if surface == .artwork {
            // Artist portraits may be circles; don't draw rectangular corners
            // into the empty space around a native circular crop.
            let nativeRadius = max(host.layer.cornerRadius, host.subviews.compactMap { subview in
                subview is UIImageView && subview.bounds.size == host.bounds.size ? subview.layer.cornerRadius : nil
            }.max() ?? 0)
            let radius = min(max(surface.radius ?? 0, nativeRadius), min(frame.width, frame.height) / 2)
            guard decoration.maskSize != plate.bounds.size || decoration.maskRadius != radius else { return }
            plate.cornerConfiguration = .corners(radius: .fixed(Double(radius)))
            // A glass sleeve at the perimeter, not a blur over the album cover.
            let rim: CGFloat = 3
            let path = UIBezierPath(roundedRect: plate.bounds, cornerRadius: radius)
            path.append(UIBezierPath(roundedRect: plate.bounds.insetBy(dx: rim, dy: rim), cornerRadius: max(0, radius - rim)))
            let mask = CAShapeLayer(); mask.frame = plate.bounds; mask.path = path.cgPath; mask.fillRule = .evenOdd
            plate.layer.mask = mask
            decoration.maskSize = plate.bounds.size
            decoration.maskRadius = radius
        }
    }

    // Center the material behind the *existing glyph*, not behind the whole
    // tab or its label. A different/unmeasured item layout stays untouched.
    private static func iconFrame(in item: UIView) -> CGRect? {
        var nodes = item.subviews; var index = 0
        while index < nodes.count && index < 30 {
            let node = nodes[index]; index += 1
            guard !node.isHidden, !(node is UIVisualEffectView) else { continue }
            if node is UIImageView || node.accessibilityIdentifier == "Encore.IconView" {
                let glyph = node.convert(node.bounds, to: item)
                if (12...42).contains(glyph.width), (12...42).contains(glyph.height) {
                    let well = glyph.insetBy(dx: -6, dy: -3).intersection(item.bounds)
                    if !well.isNull, well.width >= 12, well.height >= 12 { return well }
                }
            }
            nodes.append(contentsOf: node.subviews)
        }
        return nil
    }

    private static func materialMount(in owner: UIView, surface: Surface) -> UIView {
        guard surface != .artwork else { return owner }
        // Some shortcut buttons wrap all foreground content in an opaque, full-
        // size container. Put the plate *inside* it, not invisibly behind it.
        var view = owner
        for _ in 0..<4 {
            guard let backing = view.subviews.first(where: { !($0 is UIVisualEffectView) }),
                  type(of: backing) == UIView.self, !backing.subviews.isEmpty,
                  backing.frame == view.bounds else { break }
            view = backing
        }
        return view
    }

    static func refresh(in root: UIView) {
        guard #available(iOS 26.0, *), root.window != nil, NativeTabletGlass.contentEnabled else { return }
        walk(root) { update($0) }
    }

    // A hook on UICollectionViewCell can run *inside* a Spotify subclass’s
    // super.layoutSubviews(), before the artwork/buttons have their final
    // bounds. Coalesce until the end of the turn, and don't retain the cell.
    static func schedule(_ cell: UICollectionViewCell) {
        guard cell.window != nil, NativeTabletGlass.contentEnabled, !pendingCells.contains(cell) else { return }
        pendingCells.add(cell)
        DispatchQueue.main.async { [weak cell] in
            guard let cell, pendingCells.contains(cell) else { return }
            pendingCells.remove(cell)
            refresh(in: cell)
        }
    }

    static func prepareForReuse(_ cell: UICollectionViewCell) {
        pendingCells.remove(cell)
        guard hosts.count > 0 else { return }
        walk(cell, visit: remove(from:))
    }

    private static func walk(_ root: UIView, visit: (UIView) -> Void) {
        var nodes = [root]; var index = 0
        while index < nodes.count && index < 160 {
            let node = nodes[index]; index += 1
            visit(node)
            // Nested shelf cells receive their own layout/reuse callbacks.
            if node is UICollectionView || node is UIVisualEffectView { continue }
            nodes.append(contentsOf: node.subviews)
        }
    }
}

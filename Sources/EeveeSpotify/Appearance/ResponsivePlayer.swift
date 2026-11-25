import UIKit
import MediaPlayer
import ObjectiveC.runtime
import EeveeSpotifyC

/// One layout and one set of real controls per player page. The native player
/// remains the action provider; no synthetic hit-test mapping or shared page UI.
@MainActor
enum ResponsivePlayer {
    private static var key: UInt8 = 0
    private static let views = NSHashTable<ResponsivePlayerView>.weakObjects()
    fileprivate static let tabletArtwork: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 8
        return cache
    }()
    private static let thumbnailOwners = NSMapTable<UIImage, NSString>.weakToStrongObjects()

    fileprivate static func artworkKey(for track: SafeTrackMetadata) -> NSString? {
        if let album = track.metadata["album_uri"], album.hasPrefix("spotify:album:") { return album as NSString }
        return track.identifier.map { $0 as NSString }
    }

    static func rememberMiniArtwork(in bar: UIView) {
        guard bar.accessibilityIdentifier == "SPTNowPlayingBar", tabletEnabled,
              let track = CurrentSpotifyTrack.snapshot,
              let key = artworkKey(for: track), tabletArtwork.object(forKey: key) == nil,
              let image = ArtworkInspector.miniImage(in: bar, title: track.title) else { return }
        if let previous = thumbnailOwners.object(forKey: image), previous != key { return }
        thumbnailOwners.setObject(key, forKey: image)
        tabletArtwork.setObject(image, forKey: key)
    }

    static func apply(in page: UIView, image: UIImage?, trackID: String) {
        guard NowPlayingIOS27.isEnabled else { removeAll(); return }
        mount(in: page, image: image, trackID: trackID, tablet: false)
    }

    static var tabletEnabled: Bool {
        EvolvedInterfaceAvailability.usesNativeTabletInterface
            && UserDefaults.nowPlayingIOS27
            && !UserDefaults.standard.bool(forKey: "ShrubifyStabilityMode")
    }

    @discardableResult
    static func applyTablet(in page: UIView) -> Bool {
        guard tabletEnabled, page.window != nil, page.bounds.width >= 280, page.bounds.height >= 380 else {
            remove(from: page)
            return false
        }
        let trackID = KaraokeOverlayPresenter.currentTrackId() ?? ""
        if !trackID.isEmpty { NowPlayingIOS27.refreshMetadataArtwork(trackId: trackID) }
        mount(in: page, image: NowPlayingIOS27.metadataArtworkImage,
              trackID: NowPlayingIOS27.metadataArtworkTrackId, tablet: true)
        return ownsVisiblePlayer(page)
    }

    static func remove(from page: UIView) {
        (objc_getAssociatedObject(page, &key) as? ResponsivePlayerView)?.removePlayer()
    }

    private static func mount(in page: UIView, image: UIImage?, trackID: String, tablet: Bool) {
        let view: ResponsivePlayerView
        if let existing = objc_getAssociatedObject(page, &key) as? ResponsivePlayerView {
            view = existing
        } else {
            view = ResponsivePlayerView(page: page, tablet: tablet)
            objc_setAssociatedObject(page, &key, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            views.add(view)
            page.addSubview(view)
        }
        if view.frame != page.bounds { view.frame = page.bounds }
        view.refresh(image: image, trackID: trackID)
        if page.subviews.last !== view { page.bringSubviewToFront(view) }
    }

    static func reconcile() -> Bool {
        guard NowPlayingIOS27.isEnabled else { removeAll(); return false }
        for view in views.allObjects where !view.tablet {
            guard let page = view.page, page.window != nil else { view.removePlayer(); continue }
            view.refresh(image: NowPlayingIOS27.metadataArtworkImage, trackID: NowPlayingIOS27.metadataArtworkTrackId)
            if view.frame != page.bounds { view.frame = page.bounds }
            page.bringSubviewToFront(view)
        }
        return false
    }

    static func removeAll() {
        for view in views.allObjects where !view.tablet { view.removePlayer() }
    }

    static func owns(_ page: UIView) -> Bool {
        (objc_getAssociatedObject(page, &key) as? ResponsivePlayerView)?.superview === page
    }

    static func ownsVisiblePlayer(_ page: UIView) -> Bool {
        guard let view = objc_getAssociatedObject(page, &key) as? ResponsivePlayerView else { return false }
        return view.superview === page && !view.isHidden && view.window != nil
    }

    static func released(_ page: UIView) {
        objc_setAssociatedObject(page, &key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

@MainActor
final class ResponsivePlayerView: UIView {
    weak var page: UIView?
    fileprivate let tablet: Bool
    private let scroll = UIScrollView()
    private let backdrop = UIView()
    private let headerBlend = CAGradientLayer()
    private var sharedHeaderBottom: CGFloat = 0
    private let background = UIImageView()
    private let shade = UIView()
    private let artworkShade = CAGradientLayer()
    let artwork = UIImageView()
    private let artworkButton = UIButton(type: .custom)
    private let inlineLyric = PlayerLyricPreview(frame: .zero)
    private weak var nativeCover: UIView?
    private weak var nativeCoverCell: UIView?
    private weak var canvasCover: UIView?
    private weak var lastNativeImage: UIImage?
    private weak var staleNativeImage: UIImage?
    private var previewLyrics: KaraokeLyricsDto?
    private var previewGeneration: Int?
    private var requestedPreviewTrack: String?
    private var previewOffset = 0
    private var lastPlaybackState: Bool?
    private var lastArtworkRetry: TimeInterval = 0
    private weak var consideredArtwork: UIImage?
    private var nativeArtworkSnapshot: HeaderSnapshot?
    private var usedWideTypography: Bool?
    private var inlineFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
    private let title = UIButton(type: .system)
    private let artist = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let menu = UIButton(type: .system)
    private let progress = UISlider()
    private let elapsed = UILabel()
    private let remaining = UILabel()
    private let volume = MPVolumeView()
    private let volumeTrack = UIImageView(image: UIImage(systemName: "speaker.wave.2"))
    private let controls = UIStackView()
    private let footer = UIStackView()
    private var footerGlass: UIVisualEffectView?
    private let lyrics = UIView()
    private let notice = UILabel()
    private let credit = UILabel()
    private let lyricsButton = UIButton(type: .system)
    private var actions: [String: UIButton] = [:]
    private let native = NSMapTable<NSString, UIView>.strongToWeakObjects()
    private final class AccessibilitySnapshot {
        weak var view: UIView?
        let wasHidden: Bool
        init(_ view: UIView) {
            self.view = view
            wasHidden = view.accessibilityElementsHidden
        }
    }
    private var savedAccessibility: [AccessibilitySnapshot] = []
    private final class HeaderSnapshot {
        weak var view: UIView?
        let alpha: CGFloat
        init(_ view: UIView) { self.view = view; alpha = view.alpha }
    }
    private var headerSnapshots: [HeaderSnapshot] = []
    @MainActor private final class HeaderLayerSnapshot {
        weak var view: UIView?
        let original: CGFloat
        let raised: CGFloat

        init(_ view: UIView, above player: UIView) {
            self.view = view
            original = view.layer.zPosition
            raised = max(original, player.layer.zPosition + 1)
            view.layer.zPosition = raised
        }

        func restore() {
            if let view, view.layer.zPosition == raised { view.layer.zPosition = original }
        }
    }
    private var nativeHeaderLayers: [HeaderLayerSnapshot] = []
    private var headerHeight: CGFloat { TabletPlayerLayout.headerHeight(safeTop: safeAreaInsets.top) }
    private var lastDiscovery: TimeInterval = 0
    private var lastTabletRefresh: TimeInterval = 0
    private var showingLyrics = false
    private var seekingTrackID: String?
    private var displayLink: CADisplayLink?
    private var hostStorage: AnyObject?
    @available(iOS 26.0, *)
    private var lyricsHost: NowPlayingLyricsHost? {
        get { hostStorage as? NowPlayingLyricsHost }
        set { hostStorage = newValue }
    }
    private(set) var trackID = ""
    private var lastVersion = -1
    private var lastRomanization = -1
    private var observers: [NSObjectProtocol] = []

    init(page: UIView, tablet: Bool = false) {
        self.page = page
        self.tablet = tablet
        super.init(frame: page.bounds)
        accessibilityIdentifier = "shrubify-responsive-player"
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        isOpaque = false
        backdrop.backgroundColor = .black
        backdrop.isUserInteractionEnabled = false
        background.contentMode = .scaleAspectFill
        background.alpha = 0.7
        background.isUserInteractionEnabled = false
        background.clipsToBounds = true
        shade.backgroundColor = tablet ? .clear : UIColor.black.withAlphaComponent(0.5)
        shade.isUserInteractionEnabled = false
        if tablet {
            artworkShade.colors = [UIColor.black.withAlphaComponent(0.04).cgColor,
                                   UIColor.black.withAlphaComponent(0.28).cgColor,
                                   UIColor.black.withAlphaComponent(0.80).cgColor]
            artworkShade.locations = [0, 0.46, 1]
            shade.layer.addSublayer(artworkShade)
            // Fallback for Spotify versions that put part of the header in
            // the same branch as their body instead of a separate view.
            headerBlend.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor]
            backdrop.layer.mask = headerBlend
            isHidden = true
        }
        backdrop.addSubview(background)
        backdrop.addSubview(shade)
        addSubview(backdrop)
        addSubview(scroll)
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.addSubview(artwork)
        artwork.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        artwork.contentMode = .scaleAspectFit
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 14
        artwork.accessibilityLabel = "Album artwork"
        artwork.isAccessibilityElement = !tablet
        if tablet {
            artworkButton.accessibilityLabel = "View album artwork"
            artworkButton.addAction(UIAction { [weak self] _ in self?.openArtwork() }, for: .touchUpInside)
            artworkButton.accessibilityIdentifier = "shrubify.player.artwork"
            scroll.addSubview(artworkButton)
            inlineLyric.addAction(UIAction { [weak self] _ in self?.toggleLyrics() }, for: .touchUpInside)
            scroll.addSubview(inlineLyric)
            observers.append(NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged,
                object: nil, queue: .main) { [weak self] _ in
                    onMainThreadSync { self?.refreshPreview() }
            })
        }
        configure(close, symbol: "chevron.down", label: "Close player") { [weak self] in self?.performNative("now-playing-minimize-button") }
        configure(menu, symbol: "ellipsis", label: "More options") { [weak self] in self?.performNative("Context menu") }
        if !tablet { scroll.addSubview(close); scroll.addSubview(menu) }
        title.setTitleColor(.white, for: .normal)
        if tablet { title.setTitleColor(.white, for: .disabled) }
        artist.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
        title.contentHorizontalAlignment = .leading
        artist.contentHorizontalAlignment = .leading
        updateMetadataFonts()
        title.titleLabel?.adjustsFontForContentSizeCategory = !tablet
        artist.titleLabel?.adjustsFontForContentSizeCategory = !tablet
        title.titleLabel?.lineBreakMode = .byTruncatingTail
        artist.titleLabel?.lineBreakMode = .byTruncatingTail
        title.addAction(UIAction { [weak self] _ in self?.openMetadata("album_uri") }, for: .touchUpInside)
        artist.addAction(UIAction { [weak self] _ in self?.openMetadata("artist_uri") }, for: .touchUpInside)
        scroll.addSubview(title); scroll.addSubview(artist)
        progress.minimumValue = 0; progress.maximumValue = 1
        progress.minimumTrackTintColor = .white
        progress.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.24)
        progress.accessibilityLabel = "Playback position"
        if tablet {
            progress.setMinimumTrackImage(Self.volumeLine(color: UIColor.white.withAlphaComponent(0.96)), for: .normal)
            progress.setMaximumTrackImage(Self.volumeLine(color: UIColor.white.withAlphaComponent(0.28)), for: .normal)
            progress.setThumbImage(Self.sliderThumb(diameter: 10, color: .white), for: .normal)
            progress.setThumbImage(Self.sliderThumb(diameter: 14, color: .white), for: .highlighted)
        }
        progress.addAction(UIAction { [weak self] _ in self?.seekingTrackID = self?.trackID }, for: .touchDown)
        progress.addAction(UIAction { [weak self] _ in
            guard self?.seekingTrackID != nil else { return }
            self?.seek()
        }, for: [.touchUpInside, .touchUpOutside])
        progress.addAction(UIAction { [weak self] _ in
            self?.seekingTrackID = nil
            self?.updatePlayback(KaraokePlaybackTracker.shared.snapshot())
        }, for: .touchCancel)
        progress.addAction(UIAction { [weak self] _ in
            guard let self, !self.progress.isTracking, self.seekingTrackID == nil else { return }
            self.seek()
        }, for: .valueChanged)
        scroll.addSubview(progress)
        for label in [elapsed, remaining] {
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            scroll.addSubview(label)
        }
        remaining.textAlignment = .right
        controls.axis = .horizontal; controls.distribution = .fillEqually; controls.alignment = .center
        for (id, symbol, label) in [
            ("Components.UI.ShuffleButton", "shuffle", "Shuffle"),
            ("SPTNowPlayingPreviousTrackButton", tablet ? "backward.end.fill" : "backward.fill", "Previous track"),
            ("SPTNowPlayingPlayButton", "play.fill", "Play"),
            ("SPTNowPlayingNextTrackButton", tablet ? "forward.end.fill" : "forward.fill", "Next track"),
            ("Nowplaying-RepeatButton", "repeat", "Repeat")
        ] {
            let button = UIButton(type: .system)
            configure(button, symbol: symbol, label: label) { [weak self] in self?.performNative(id) }
            actions[id] = button; controls.addArrangedSubview(button)
        }
        scroll.addSubview(controls)
        volume.showsRouteButton = false
        volume.accessibilityLabel = "Volume"
        if tablet {
            let level = UIColor.white.withAlphaComponent(0.57)
            volume.setMinimumVolumeSliderImage(Self.volumeLine(color: level), for: .normal)
            volume.setMaximumVolumeSliderImage(Self.volumeLine(color: UIColor.white.withAlphaComponent(0.16)), for: .normal)
            volume.setVolumeThumbImage(Self.sliderThumb(diameter: 8, color: level), for: .normal)
            volumeTrack.tintColor = level
            volumeTrack.contentMode = .center
            volumeTrack.accessibilityElementsHidden = true
            scroll.addSubview(volumeTrack)
        }
        scroll.addSubview(volume)
        footer.axis = .horizontal; footer.distribution = .fillEqually; footer.alignment = .center
        configure(lyricsButton, symbol: "quote.bubble", label: "Lyrics") { [weak self] in self?.toggleLyrics() }
        footer.addArrangedSubview(lyricsButton)
        for (id, symbol, label) in [
            ("shrubify-connect", "airplay.audio", "Audio output"),
            ("QueueButtonNowPlaying", "list.bullet", "Queue"),
            ("shrubify-save", "plus.circle", "Save track"),
            ("ShareButtonNowPlayingView", "square.and.arrow.up", "Share")
        ] {
            if !tablet && id == "ShareButtonNowPlayingView" { continue }
            let button = UIButton(type: .system)
            configure(button, symbol: symbol, label: label) { [weak self] in self?.performNative(id) }
            actions[id] = button; footer.addArrangedSubview(button)
        }
        if tablet, #available(iOS 26.0, *) {
            let glass = ShrubifyLiquidGlass.makePlate()
            glass.accessibilityIdentifier = "shrubify.player.shortcuts"
            scroll.addSubview(glass)
            footerGlass = glass
        }
        scroll.addSubview(footer)
        lyrics.isHidden = true
        scroll.addSubview(lyrics)
        notice.textColor = .white; notice.numberOfLines = 0; notice.textAlignment = .center
        notice.font = UIFont.preferredFont(forTextStyle: .body)
        notice.adjustsFontForContentSizeCategory = true
        lyrics.addSubview(notice)
        credit.textColor = UIColor.white.withAlphaComponent(0.7)
        credit.font = UIFont.preferredFont(forTextStyle: .caption1)
        credit.adjustsFontForContentSizeCategory = true
        scroll.addSubview(credit)
        for notification in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification,
                             UIAccessibility.reduceTransparencyStatusDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
                onMainThreadSync { self?.updateClock(); self?.setNeedsLayout() }
            })
        }
        // Hide native accessibility descendants only for this page. Native views
        // are left at their actual positions and never receive remapped touches.
        for child in page.subviews where !tablet {
            savedAccessibility.append(AccessibilitySnapshot(child))
            child.accessibilityElementsHidden = true
        }
    }

    required init?(coder: NSCoder) { return nil }

    private func configure(_ button: UIButton, symbol: String, label: String, action: @escaping () -> Void) {
        // Playback glyphs are content, not permanent floating glass controls.
        button.tintColor = .white
        let size: CGFloat = tablet ? 19 : 23
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .medium)), for: .normal)
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        let minimumWidth = button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        // A hidden optional action gets zero width from its horizontal stack.
        // The visible layout still reserves 44 points for every action.
        minimumWidth.priority = .defaultHigh
        minimumWidth.isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    func refresh(image: UIImage?, trackID: String) {
        guard let page else { return }
        let info = CurrentSpotifyTrack.snapshot
        let currentID = info?.identifier ?? (tablet && !self.trackID.isEmpty ? self.trackID : trackID)
        let artworkKey = tablet ? info.flatMap { ResponsivePlayer.artworkKey(for: $0) } : nil
        if self.trackID != currentID {
            self.trackID = currentID
            artwork.image = nil; background.image = nil
            staleNativeImage = lastNativeImage
            lastVersion = -1
            lastDiscovery = 0
            lastArtworkRetry = 0
            consideredArtwork = nil
            artworkButton.isEnabled = false
            previewLyrics = nil
            requestedPreviewTrack = nil
            if tablet {
                clearInlineLyric()
                refreshPreview()
            }
        }
        // An image is only accepted for the metadata request's exact track.
        if trackID == currentID, let image, consideredArtwork !== image {
            consideredArtwork = image
            let existingWidth = artwork.image.map { $0.size.width * $0.scale } ?? 0
            if !tablet || (ArtworkInspector.usableImage(image) && image.size.width * image.scale >= existingWidth) {
                artwork.image = image
                background.image = NowPlayingIOS27.backdrop(from: image)
                if tablet { artworkButton.isEnabled = true }
            }
        }
        discoverNative(in: page)
        if let artworkKey, let cached = ResponsivePlayer.tabletArtwork.object(forKey: artworkKey) {
            upgradeTabletArtwork(cached)
        }
        if tablet, let nativeImage = [nativeCover, nativeCoverCell, canvasCover].lazy
            .compactMap({ $0.flatMap { ArtworkInspector.nativeImage(in: $0) } }).first {
            lastNativeImage = nativeImage
            if info?.identifier == currentID, nativeImage !== staleNativeImage {
                upgradeTabletArtwork(nativeImage)
            }
        }
        if tablet, artwork.image == nil, let info, info.identifier == currentID,
           let playerInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           playerInfo[MPMediaItemPropertyTitle] as? String == info.title,
           playerInfo[MPMediaItemPropertyArtist] as? String == info.artist,
           let cover = playerInfo[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork,
           let displayImage = cover.image(at: CGSize(width: 1024, height: 1024)),
           ArtworkInspector.usableFallback(displayImage) {
            upgradeTabletArtwork(displayImage)
        }
        if let artworkKey, let cover = artwork.image,
           ResponsivePlayer.tabletArtwork.object(forKey: artworkKey) !== cover {
            ResponsivePlayer.tabletArtwork.setObject(cover, forKey: artworkKey)
        }
        if let info {
            title.setTitle(info.title, for: .normal)
            artist.setTitle(info.artist, for: .normal)
            title.accessibilityLabel = info.title
            artist.accessibilityLabel = "Artist: " + info.artist
            title.isEnabled = info.metadata["album_uri"] != nil && SpotifyURIOpener.isReady
            title.accessibilityHint = title.isEnabled ? "Open album" : nil
            artist.isEnabled = info.metadata["artist_uri"] != nil && SpotifyURIOpener.isReady
        }
        let required = ["SPTNowPlayingPlayButton", "SPTNowPlayingPreviousTrackButton", "SPTNowPlayingNextTrackButton"]
            + (tablet ? [] : ["now-playing-minimize-button"])
        let controlsReady = info != nil && required.allSatisfy {
            activeNative($0).flatMap { NowPlayingIOS27.nearestControl($0) } != nil
        }
        // Changes to Spotify's view tree can briefly detach the transport
        // controls. Keep the installed player covering the native body.
        let ready = controlsReady || (tablet && !isHidden)
        if !tablet, isHidden == ready { isHidden = !ready; setNeedsLayout() }
        for snapshot in headerSnapshots { snapshot.view?.alpha = ready ? 0 : snapshot.alpha }
        for snapshot in savedAccessibility { snapshot.view?.accessibilityElementsHidden = ready || snapshot.wasHidden }
        guard ready else {
            restoreNativeArtwork()
            if tablet { NativeTabletCanvasReadability.restoreVideo(in: page) }
            if !tablet { displayLink?.isPaused = true }
            return
        }
        displayLink?.isPaused = false
        if tablet {
            artworkButton.isEnabled = artwork.image != nil
            hideDuplicateArtwork()
            if backdrop.layer.mask != nil { NativeTabletCanvasReadability.suppressVideo(in: page) }
            else { NativeTabletCanvasReadability.restoreVideo(in: page) }
            if isHidden {
                setNeedsLayout()
                layoutIfNeeded()
                isHidden = false
            }
        }
        refreshPlayback()
        for (id, button) in actions {
            let source = activeNative(id)
            if tablet, button.isHidden != (source == nil) {
                button.isHidden = source == nil
                setNeedsLayout()
            }
            button.isEnabled = source.map { (NowPlayingIOS27.nearestControl($0)?.isEnabled ?? true) && $0.isUserInteractionEnabled } ?? false
            button.alpha = button.isEnabled ? 1 : 0.35
            if id != "SPTNowPlayingPlayButton", let label = source?.accessibilityLabel, !label.isEmpty {
                button.accessibilityLabel = label
            }
            button.isSelected = (source as? UIControl)?.isSelected == true || source?.accessibilityTraits.contains(.selected) == true
            button.accessibilityValue = source?.accessibilityValue ?? (button.isSelected ? "On" : nil)
            if tablet {
                let toggles = id == "Components.UI.ShuffleButton" || id == "Nowplaying-RepeatButton"
                button.tintColor = toggles && !button.isSelected ? UIColor.white.withAlphaComponent(0.55) : .white
            } else {
                button.tintColor = button.isSelected ? .systemGreen : .white
            }
        }
        close.isEnabled = native.object(forKey: "now-playing-minimize-button") != nil
        let disabled = NgzhwmSettingsViewModel.isLyricsFeatureDisabled
        if tablet {
            lyricsButton.isEnabled = !disabled && (KaraokeOverlayPresenter.canOpenForCurrentTrack()
                || NowPlayingIOS27.lyricsEntryTarget(in: page) != nil)
        } else if #available(iOS 26.0, *), UserDefaults.shouldReplaceLyrics {
            lyricsButton.isEnabled = !disabled
        } else { lyricsButton.isEnabled = !disabled && NowPlayingIOS27.lyricsEntryTarget(in: page) != nil }
        if disabled || !UserDefaults.shouldReplaceLyrics {
            showingLyrics = false
            lyrics.isHidden = true
            if #available(iOS 26.0, *) { lyricsHost?.detach() }
        }
        menu.isHidden = native.object(forKey: "Context menu") == nil
        updateLyrics()
        if !tablet { setNeedsLayout() }
    }

    private func upgradeTabletArtwork(_ candidate: UIImage) {
        let existing = artwork.image.map { $0.size.width * $0.scale } ?? 0
        guard candidate.size.width * candidate.scale > existing else { return }
        artwork.image = candidate
        background.image = NowPlayingIOS27.backdrop(from: candidate)
    }

    private func refreshPlayback() {
        KaraokeSeek.player = statefulPlayer as AnyObject?
        let state = KaraokeSeek.refresh()
        if !tablet { updatePlayback(state) }
    }

    private func updatePlayback(_ state: KaraokePlaybackSnapshot) {
        guard !tablet || state.trackID == nil || state.trackID == trackID else { return }
        let position = state.positionMs
        let duration = state.durationMs
        if !progress.isTracking, seekingTrackID == nil {
            progress.value = duration > 0 ? Float(position) / Float(duration) : 0
        }
        progress.isEnabled = duration > 0
        let shownPosition = progress.isTracking && duration > 0 ? Int(progress.value * Float(duration)) : position
        let elapsedText = duration > 0 ? Self.time(shownPosition) : "–:–"
        let remainingText = duration > 0 ? "−" + Self.time(max(0, duration - shownPosition)) : "–:–"
        if elapsed.text != elapsedText { elapsed.text = elapsedText }
        if remaining.text != remainingText { remaining.text = remainingText }
        if let play = actions["SPTNowPlayingPlayButton"], lastPlaybackState != state.isPlaying {
            lastPlaybackState = state.isPlaying
            play.setImage(UIImage(systemName: state.isPlaying ? "pause.fill" : "play.fill",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: tablet ? 30 : 34, weight: .semibold)), for: .normal)
            play.accessibilityLabel = state.isPlaying ? "Pause" : "Play"
        }
        if tablet { updateInlineLyric(at: state.hasPosition ? shownPosition : nil) }
    }

    private func refreshPreview() {
        let store = KaraokeLyricsStore.shared
        let generation = store.resetGeneration
        if previewGeneration != generation {
            previewGeneration = generation
            previewLyrics = nil
            requestedPreviewTrack = nil
            clearInlineLyric()
        }
        if let cached = store.lyrics(forTrackId: trackID) { previewLyrics = cached }
        previewOffset = UserDefaults.karaokeOptions.timingOffsetMs
    }

    private func clearInlineLyric() {
        inlineLyric.display(nil, timed: false, animated: false)
    }

    private func updateInlineLyric(at position: Int?) {
        let enabled = !NgzhwmSettingsViewModel.isLyricsFeatureDisabled && UserDefaults.shouldReplaceLyrics
        // A transiently missing playback sample during a pane transition
        // cannot blank an already-rendered line for this track.
        if enabled && position == nil { return }
        let time = position.map { ShrubifyBetaSupport.lyricPosition(playbackMs: $0, delayMs: previewOffset) }
        let index = time.flatMap { previewLyrics?.previewLineIndex(at: $0) }
        let line = enabled ? index.flatMap { previewLyrics?.lines[$0] } : nil
        let text = line?.plainText
        let highlight = time.flatMap { line?.highlight(at: $0) }
        let opacity = time.flatMap { highlight?.opacity(at: $0) } ?? 0
        inlineLyric.display(text, timed: line?.hasWordTiming == true, word: highlight?.range,
                            opacity: CGFloat(opacity), animated: !progress.isTracking && seekingTrackID == nil)
    }

    private func activeNative(_ id: String) -> UIView? {
        guard let source = native.object(forKey: id as NSString) else { return nil }
        guard tablet else { return source }
        guard let page, source.window === page.window, source.isDescendant(of: page), onPlayerPage(source, page: page) else { return nil }
        return source
    }

    private func onPlayerPage(_ source: UIView, page: UIView, includeSuppressedArtwork: Bool = false) -> Bool {
        var node: UIView? = source
        while let view = node, view !== page {
            guard !view.isHidden,
                  view.alpha > 0.01 || (includeSuppressedArtwork && view === nativeArtworkSnapshot?.view)
            else { return false }
            node = view.superview
        }
        return source.convert(source.bounds, to: page).intersects(page.bounds)
    }

    private func discoverNative(in page: UIView) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDiscovery > 1 else { return }
        lastDiscovery = now
        native.removeAllObjects()
        let previousCover = nativeCover
        if tablet { nativeCover = nil; nativeCoverCell = nil; canvasCover = nil }
        savedAccessibility.removeAll { $0.view == nil }
        var queue = [page]; var index = 0
        var standaloneHeaders: [UIView] = []
        var sharedHeaderBottom: CGFloat = 0
        let ids = Set(actions.keys).union(["now-playing-minimize-button", "Context menu", "SPTNowPlayingSliderV2"])
        while index < queue.count, index < 3000 {
            let view = queue[index]; index += 1
            if view === self { continue }
            queue.append(contentsOf: view.subviews)
            let rect = view.convert(view.bounds, to: page)
            // Spotify intentionally hides this cover while Canvas plays. Its
            // current bitmap can still back the player in the narrow pane.
            if tablet, canvasCover == nil, rect.intersects(page.bounds), ArtworkInspector.isCanvasCover(view) {
                canvasCover = view
            }
            guard !view.isHidden, rect.intersects(page.bounds),
                  !tablet || onPlayerPage(view, page: page, includeSuppressedArtwork: true) else { continue }
            if tablet, nativeCover == nil, ArtworkInspector.isNativeCover(view) {
                nativeCover = view
            }
            if tablet, nativeCoverCell == nil, ArtworkInspector.isNativeCoverCell(view) {
                nativeCoverCell = view
            }
            if tablet, view !== page, rect.minY >= page.bounds.minY + headerHeight,
               !savedAccessibility.contains(where: { snapshot in
                   guard let saved = snapshot.view else { return false }
                   return view === saved || view.isDescendant(of: saved)
               }) {
                savedAccessibility.append(AccessibilitySnapshot(view))
            }
            if let id = view.accessibilityIdentifier, ids.contains(id),
               native.object(forKey: id as NSString) == nil || native.object(forKey: id as NSString)?.window == nil {
                native.setObject(view, forKey: id as NSString)
            }
            let name = NSStringFromClass(type(of: view))
            let id = view.accessibilityIdentifier
            if tablet, view !== page, rect.midY < headerHeight + 8,
               (name.hasSuffix("NowPlayingScrollHeader") || id == NowPlayingIOS27.contextMenuIdentifier
                || id == NowPlayingLyricsPlate.minimizeButtonIdentifier || id == NowPlayingIOS27.navTitleIdentifier) {
                var branch = view
                while let parent = branch.superview, parent !== page { branch = parent }
                let frame = branch.convert(branch.bounds, to: page)
                if frame.minY >= -12, frame.maxY <= headerHeight + 18 {
                    if !standaloneHeaders.contains(where: { $0 === branch }) { standaloneHeaders.append(branch) }
                } else { sharedHeaderBottom = max(sharedHeaderBottom, min(rect.maxY, headerHeight)) }
            }
            if (id == "Components.ConnectButtonOutputSwitcher" || name.contains("ConnectButton")),
               native.object(forKey: "shrubify-connect") == nil {
                native.setObject(view, forKey: "shrubify-connect")
            }
            if (id == "Components.UI.AddToButton" || name.contains("AddToButton")),
               native.object(forKey: "shrubify-save") == nil {
                native.setObject(view, forKey: "shrubify-save")
            }
            if tablet, native.object(forKey: "QueueButtonNowPlaying") == nil,
               let control = view as? UIControl,
               name.contains("QueueButton") || control.accessibilityLabel?.caseInsensitiveCompare("Queue") == .orderedSame {
                native.setObject(control, forKey: "QueueButtonNowPlaying")
            }
        }
        if tablet {
            updateTabletHeader(standaloneHeaders, sharedBottom: sharedHeaderBottom)
            if previousCover !== nativeCover { setNeedsLayout() }
        }
        if !tablet { discoverHeader(in: page) }
        for child in page.subviews where child !== self && !tablet {
            if !savedAccessibility.contains(where: { $0.view === child }) {
                savedAccessibility.append(AccessibilitySnapshot(child))
            }
            child.accessibilityElementsHidden = true
        }
    }

    private func updateTabletHeader(_ branches: [UIView], sharedBottom: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        nativeHeaderLayers.removeAll { snapshot in
            guard branches.contains(where: { $0 === snapshot.view }) else { snapshot.restore(); return true }
            return false
        }
        for view in branches {
            if !nativeHeaderLayers.contains(where: { $0.view === view }) {
                nativeHeaderLayers.append(HeaderLayerSnapshot(view, above: self))
            }
        }
        if sharedHeaderBottom != sharedBottom { sharedHeaderBottom = sharedBottom; setNeedsLayout() }
        let mask = sharedBottom > 0 ? headerBlend : nil
        if backdrop.layer.mask !== mask { backdrop.layer.mask = mask; setNeedsLayout() }
    }

    // iPad can host the native header as a sibling of the scroll controller.
    // Hide only its recognized buttons, preserving their actions and restoration.
    private func discoverHeader(in page: UIView) {
        var root = page
        for _ in 0..<3 {
            guard let parent = root.superview, !(parent is UIWindow),
                  parent.bounds.width <= page.bounds.width + 4 else { break }
            root = parent
        }
        let pageRect = page.convert(page.bounds, to: root)
        let band = CGRect(x: pageRect.minX, y: max(0, pageRect.minY - 64),
                          width: pageRect.width, height: page.safeAreaInsets.top + 128)
        var queue = [root]; var index = 0
        while index < queue.count, index < 1000 {
            let view = queue[index]; index += 1
            if view === self { continue }
            let rect = view.convert(view.bounds, to: root)
            guard rect.intersects(band) else { continue }
            queue.append(contentsOf: view.subviews)
            guard let id = view.accessibilityIdentifier,
                  ["Context menu", "now-playing-minimize-button"].contains(id),
                  let control = NowPlayingIOS27.nearestControl(view) else { continue }
            let controlRect = control.convert(control.bounds, to: root)
            guard controlRect.width <= 96, controlRect.height <= 96,
                  controlRect.width >= 16, controlRect.height >= 16 else { continue }
            if native.object(forKey: id as NSString) == nil { native.setObject(view, forKey: id as NSString) }
            if !headerSnapshots.contains(where: { $0.view === control }) {
                headerSnapshots.append(HeaderSnapshot(control))
            }
        }
    }

    private func performNative(_ id: String) {
        guard let source = activeNative(id), source.window === window else {
            lastDiscovery = 0
            return
        }
        if tablet && id == "shrubify-connect" {
            NowPlayingIOS27.activateConnect(source)
            return
        }
        if let control = NowPlayingIOS27.nearestControl(source), control.isEnabled {
            control.sendActions(for: .touchDown)
            let activation: UIControl.Event = tablet && control.allControlEvents.contains(.primaryActionTriggered)
                ? .primaryActionTriggered : .touchUpInside
            control.sendActions(for: activation)
        } else { _ = source.accessibilityActivate() }
    }

    private func openMetadata(_ key: String) {
        guard let info = CurrentSpotifyTrack.snapshot,
              let value = info.metadata[key], let url = URL(string: value) else { return }
        _ = SpotifyURIOpener.open(url.absoluteString)
    }

    private func seek() {
        defer { seekingTrackID = nil }
        guard (seekingTrackID ?? trackID) == NowPlayingLyricsPlate.currentTrackId() else { return }
        let state = KaraokeSeek.refresh()
        guard state.durationMs > 0 else { return }
        let milliseconds = Int(Float(state.durationMs) * progress.value)
        if tablet, KaraokeSeek.seek(milliseconds: milliseconds, trackID: trackID) { return }
        if let slider = activeNative("SPTNowPlayingSliderV2") as? UISlider {
            slider.value = slider.minimumValue + progress.value * (slider.maximumValue - slider.minimumValue)
            slider.sendActions(for: .valueChanged)
            slider.sendActions(for: .touchUpInside)
            KaraokePlaybackTracker.shared.didSeek(milliseconds: milliseconds)
        } else if !tablet { _ = KaraokeSeek.seek(milliseconds: milliseconds, trackID: trackID) }
    }

    private func toggleLyrics() {
        if tablet, KaraokeOverlayPresenter.canOpenForCurrentTrack() {
            KaraokeOverlayPresenter.present()
        } else if !tablet, #available(iOS 26.0, *), UserDefaults.shouldReplaceLyrics {
            showingLyrics.toggle()
            lyricsButton.accessibilityValue = showingLyrics ? "Shown" : "Hidden"
            lyrics.isHidden = !showingLyrics
            updateLyrics(); updateClock(); setNeedsLayout()
            UIAccessibility.post(notification: .layoutChanged, argument: showingLyrics ? notice : lyricsButton)
        } else {
            // Keep the native full lyrics presentation on older supported OSes.
            guard let page, let target = NowPlayingIOS27.lyricsEntryTarget(in: page) else { return }
            if let action = NowPlayingIOS27.tapAction(for: target, label: "lyrics") { action() }
        }
    }

    private func updateLyrics() {
        guard showingLyrics else { return }
        let timed = NowPlayingLyricsPlate.currentLines() ?? []
        let untimed = NowPlayingLyricsPlate.currentUntimedLines()
        let lines = timed.isEmpty ? NowPlayingLyricsPlate.staticLines(from: untimed ?? []) : timed
        notice.text = NowPlayingLyricsPlate.noticeText() ?? (lines.isEmpty ? "lyrics_unavailable".localized : nil)
        notice.isHidden = !lines.isEmpty
        credit.text = currentLyricsProvider
        if #available(iOS 26.0, *), !lines.isEmpty {
            let host = lyricsHost ?? NowPlayingLyricsHost()
            lyricsHost = host
            let revision = currentLyricsVersion
            let romanization = NowPlayingLyricsHost.romanizationFingerprint()
            if lastVersion != revision || lastRomanization != romanization || !host.isAttached {
                host.detach()
                host.mount(in: lyrics, lines: lines, version: revision, trackId: trackID,
                           isStatic: timed.isEmpty, onSeek: { seconds in seekToTappedLyricLine(seconds) })
                lastVersion = revision; lastRomanization = romanization
            }
        } else if #available(iOS 26.0, *) { lyricsHost?.detach() }
    }

    private func updateClock() {
        displayLink?.invalidate(); displayLink = nil
        guard tablet || (showingLyrics && !isHidden), window != nil,
              UIApplication.shared.applicationState == .active else { return }
        let link = CADisplayLink(target: self, selector: #selector(tickLyrics))
        link.preferredFramesPerSecond = UIAccessibility.isReduceMotionEnabled ? 15 : 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tickLyrics() {
        if tablet {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastTabletRefresh >= 0.25, let page {
                lastTabletRefresh = now
                guard ResponsivePlayer.tabletEnabled else { removePlayer(); return }
                let current = KaraokeOverlayPresenter.currentTrackId() ?? trackID
                if !current.isEmpty,
                   current != trackID || (NowPlayingIOS27.metadataArtworkImage == nil && now - lastArtworkRetry > 1) {
                    lastArtworkRetry = now
                    NowPlayingIOS27.refreshMetadataArtwork(trackId: current)
                }
                let candidate = NowPlayingIOS27.metadataArtworkImage
                if (!current.isEmpty && current != trackID) || isHidden || artwork.image == nil
                    || (candidate != nil && consideredArtwork !== candidate)
                    || now - lastDiscovery > 1 {
                    refresh(image: candidate, trackID: NowPlayingIOS27.metadataArtworkTrackId)
                } else {
                    refreshPlayback()
                }
                if !isHidden, !trackID.isEmpty, requestedPreviewTrack != trackID, previewLyrics == nil,
                   KaraokeOverlayPresenter.canOpenForCurrentTrack(), !NgzhwmSettingsViewModel.isLyricsFeatureDisabled {
                    requestedPreviewTrack = trackID
                    prefetchLyricsIfNeeded(trackId: trackID)
                }
                if superview === page, page.subviews.last !== self, !isHidden { page.bringSubviewToFront(self) }
            }
            if !isHidden { updatePlayback(KaraokePlaybackTracker.shared.snapshot()) }
            return
        }
        if #available(iOS 26.0, *) {
            lyricsHost?.tick(seconds: WordByWordPositionResolver.shared.currentPositionSeconds())
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if tablet, window == nil, let page {
            restoreNativeArtwork()
            NativeTabletCanvasReadability.restoreVideo(in: page)
            nativeHeaderLayers.forEach { $0.restore() }
            nativeHeaderLayers.removeAll()
            lastDiscovery = 0
            isHidden = true
        }
        updateClock()
    }

    private func updateMetadataFonts() {
        if tablet {
            let wide = bounds.width >= 760
            usedWideTypography = wide
            title.titleLabel?.font = UIFontMetrics(forTextStyle: .title1)
                .scaledFont(for: .systemFont(ofSize: wide ? 35 : 28, weight: .bold), compatibleWith: traitCollection)
            artist.titleLabel?.font = UIFontMetrics(forTextStyle: .body)
                .scaledFont(for: .systemFont(ofSize: wide ? 19 : 16, weight: .medium), compatibleWith: traitCollection)
            inlineFont = UIFontMetrics(forTextStyle: .headline)
                .scaledFont(for: .systemFont(ofSize: wide ? 23 : 19, weight: .semibold), compatibleWith: traitCollection)
            inlineLyric.lyricFont = inlineFont
        } else {
            title.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title2)
            artist.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        }
    }

    private static func sliderThumb(diameter: CGFloat, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        }
    }

    private static func volumeLine(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 9, height: 3)).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 9, height: 3), cornerRadius: 1.5).fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if tablet && point.y < headerHeight { return nil }
        return super.hitTest(point, with: event)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateMetadataFonts()
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backdrop.frame = bounds
        background.frame = backdrop.bounds
        shade.frame = backdrop.bounds
        background.isHidden = UIAccessibility.isReduceTransparencyEnabled
        if tablet {
            layoutTablet()
            return
        }
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let layout = PlayerLayout(size: bounds.size, top: safeAreaInsets.top, bottom: safeAreaInsets.bottom,
                                  largeText: large)
        scroll.frame = bounds
        scroll.contentSize = CGSize(width: bounds.width, height: layout.contentHeight)
        close.frame = CGRect(x: layout.header.minX, y: layout.header.minY, width: 48, height: 48)
        menu.frame = CGRect(x: layout.header.maxX - 48, y: layout.header.minY, width: 48, height: 48)
        artwork.frame = layout.artwork
        let panel = layout.content
        // Lyrics replace artwork on narrow screens and occupy the upper right
        // column on wide screens. Controls keep their own reserved region.
        let extra = layout.wide ? max(0, panel.height - (large ? 360 : 300)) : 0
        let textY = panel.minY + extra
        let titleHeight = max(44, (title.titleLabel?.font.lineHeight ?? 32) + 12)
        title.frame = CGRect(x: panel.minX, y: textY, width: panel.width, height: titleHeight)
        artist.frame = CGRect(x: panel.minX, y: title.frame.maxY, width: panel.width, height: max(44, (artist.titleLabel?.font.lineHeight ?? 24) + 12))
        progress.frame = CGRect(x: panel.minX, y: artist.frame.maxY + 4, width: panel.width, height: 44)
        elapsed.frame = CGRect(x: panel.minX, y: progress.frame.maxY - 6, width: panel.width / 2, height: 20)
        remaining.frame = CGRect(x: panel.midX, y: elapsed.frame.minY, width: panel.width / 2, height: 20)
        controls.frame = CGRect(x: panel.minX, y: elapsed.frame.maxY + 8, width: panel.width, height: 52)
        volume.frame = CGRect(x: panel.minX, y: controls.frame.maxY + 16, width: panel.width, height: 44)
        let footerY = max(layout.footer.minY, volume.frame.maxY + 8)
        footer.frame = CGRect(x: panel.minX, y: footerY, width: panel.width, height: 48)
        scroll.contentSize.height = max(layout.contentHeight, footer.frame.maxY + safeAreaInsets.bottom + 8)
        if showingLyrics {
            if layout.wide {
                lyrics.frame = CGRect(x: panel.minX, y: panel.minY, width: panel.width, height: max(120, extra - 24))
                // On short wide containers, place lyrics in the artwork column.
                if extra < 150 { lyrics.frame = artwork.frame; artwork.isHidden = true }
                else { artwork.isHidden = false }
            } else { lyrics.frame = artwork.frame; artwork.isHidden = true }
        } else {
            artwork.isHidden = false
            if #available(iOS 26.0, *) { lyricsHost?.detach() }
            credit.text = nil
        }
        notice.frame = lyrics.bounds.insetBy(dx: 16, dy: 16)
        credit.frame = CGRect(x: panel.minX, y: footer.frame.maxY + 4, width: panel.width, height: 20)
        if showingLyrics { scroll.contentSize.height = max(scroll.contentSize.height, credit.frame.maxY + safeAreaInsets.bottom + 8) }
    }

    private func layoutTablet() {
        let top = min(headerHeight, bounds.height)
        if usedWideTypography != (bounds.width >= 760) { updateMetadataFonts() }
        scroll.frame = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)
        let layout = TabletPlayerLayout(size: scroll.bounds.size, bottom: safeAreaInsets.bottom,
                                        titleHeight: max(40, (title.titleLabel?.font.lineHeight ?? 32) + 3),
                                        artistHeight: max(28, (artist.titleLabel?.font.lineHeight ?? 22) + 4),
                                        lyricHeight: max(44, inlineFont.lineHeight * 2 + 4))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkShade.frame = shade.bounds
        headerBlend.frame = backdrop.bounds
        headerBlend.locations = TabletPlayerLayout.headerFade(end: min(top, sharedHeaderBottom), height: bounds.height).map {
            NSNumber(value: Double($0))
        }
        CATransaction.commit()

        artwork.frame = layout.artwork
        artworkButton.frame = layout.artwork
        artworkButton.isEnabled = artwork.image != nil
        inlineLyric.frame = layout.lyric
        artwork.isHidden = showingLyrics
        artworkButton.isHidden = showingLyrics
        lyrics.frame = layout.artwork
        notice.frame = lyrics.bounds.insetBy(dx: 16, dy: 16)
        title.frame = layout.title
        artist.frame = layout.artist
        progress.frame = layout.progress
        elapsed.frame = CGRect(x: layout.clock.minX, y: layout.clock.minY, width: layout.clock.width / 2, height: layout.clock.height)
        remaining.frame = elapsed.frame.offsetBy(dx: elapsed.frame.width, dy: 0)
        controls.frame = layout.transport
        volumeTrack.frame = CGRect(x: layout.volume.minX, y: layout.volume.minY - 5, width: 26, height: layout.volume.height)
        volume.frame = layout.volume.inset(by: UIEdgeInsets(top: 0, left: 34, bottom: 0, right: 0))
        footer.frame = layout.footer
        footerGlass?.frame = layout.footer
        credit.frame = CGRect(x: layout.footer.minX, y: layout.footer.maxY + 4, width: layout.footer.width, height: 20)
        let heightWithCredit = showingLyrics ? credit.frame.maxY + safeAreaInsets.bottom + 8 : 0
        scroll.contentSize = CGSize(width: scroll.bounds.width, height: max(layout.contentHeight, heightWithCredit))
    }

    private func openArtwork() {
        guard let image = artwork.image else { return }
        restoreNativeArtwork()
        if let nativeCover, let page, onPlayerPage(nativeCover, page: page),
           ArtworkInspector.openNative(from: nativeCover) { return }
        if #available(iOS 15.0, *) { ArtworkInspector.present(image, from: self) }
    }

    private func hideDuplicateArtwork() {
        let child = nativeCover.flatMap { NowPlayingLyricsPlate.sameSizeChild(of: $0) } ?? nativeCoverCell ?? canvasCover
        guard let child, child.bounds.width > 0, child.bounds.height > 0 else { restoreNativeArtwork(); return }
        if nativeArtworkSnapshot?.view !== child {
            restoreNativeArtwork()
            nativeArtworkSnapshot = HeaderSnapshot(child)
        }
        if child.alpha > 0 { child.alpha = 0 }
    }

    private func restoreNativeArtwork() {
        if let snapshot = nativeArtworkSnapshot, let view = snapshot.view, view.alpha == 0 {
            view.alpha = snapshot.alpha
        }
        nativeArtworkSnapshot = nil
    }

    func removePlayer() {
        displayLink?.invalidate(); displayLink = nil
        restoreNativeArtwork()
        if #available(iOS 26.0, *) { lyricsHost?.detach(); lyricsHost = nil }
        for snapshot in savedAccessibility { snapshot.view?.accessibilityElementsHidden = snapshot.wasHidden }
        savedAccessibility.removeAll()
        for snapshot in headerSnapshots { snapshot.view?.alpha = snapshot.alpha }
        headerSnapshots.removeAll()
        for snapshot in nativeHeaderLayers { snapshot.restore() }
        nativeHeaderLayers.removeAll()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        removeFromSuperview()
        if let page {
            if tablet { NativeTabletCanvasReadability.restoreVideo(in: page) }
            ResponsivePlayer.released(page)
        }
    }

    private static func time(_ ms: Int) -> String {
        let seconds = max(0, ms / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

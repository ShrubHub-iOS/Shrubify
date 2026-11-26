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
    private static let mountingPages = NSHashTable<UIView>.weakObjects()
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
        guard tabletEnabled else {
            remove(from: page)
            return false
        }
        guard page.window != nil, page.bounds.width > 1, page.bounds.height > 1 else { return ownsVisiblePlayer(page) }
        guard !mountingPages.contains(page) else { return ownsVisiblePlayer(page) }
        mountingPages.add(page)
        defer { mountingPages.remove(page) }
        let trackID = KaraokeOverlayPresenter.currentTrackId() ?? ""
        if !trackID.isEmpty { NowPlayingIOS27.refreshMetadataArtwork(trackId: trackID) }
        mount(in: page, image: NowPlayingIOS27.metadataArtworkImage,
              trackID: NowPlayingIOS27.metadataArtworkTrackId, tablet: true)
        return ownsVisiblePlayer(page)
    }

    static func remove(from page: UIView) {
        (objc_getAssociatedObject(page, &key) as? ResponsivePlayerView)?.removePlayer()
    }

    static func pageDidDisappear(_ page: UIView) {
        if page.window == nil, !(player(in: page)?.isFullscreen ?? false) { remove(from: page) }
    }

    private static func player(in page: UIView) -> ResponsivePlayerView? {
        objc_getAssociatedObject(page, &key) as? ResponsivePlayerView
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
        if !view.isFullscreen, view.frame != page.bounds { view.frame = page.bounds }
        view.refresh(image: image, trackID: trackID)
        if tablet { view.keepAboveNativeBody(in: page) }
        else if page.subviews.last !== view { page.bringSubviewToFront(view) }
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
        return (view.superview === page || view.isFullscreen) && !view.isHidden && view.window != nil
    }

    static func released(_ page: UIView) {
        objc_setAssociatedObject(page, &key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

@MainActor
final class ResponsivePlayerView: UIView, UIScrollViewDelegate {
    weak var page: UIView?
    fileprivate let tablet: Bool
    private let scroll = UIScrollView()
    private let backdrop = UIView()
    private let background = UIImageView()
    private let shade = UIView()
    private let artworkShade = CAGradientLayer()
    let artwork = UIImageView()
    private let artworkButton = UIButton(type: .custom)
    private let inlineLyric = PlayerLyricPreview(frame: .zero)
    private weak var nativeCover: UIView?
    private var previewLyrics: KaraokeLyricsDto?
    private var previewGeneration: Int?
    private var requestedPreviewTrack: String?
    private var previewOffset = 0
    private var lastPlaybackState: Bool?
    private var lastArtworkRetry: TimeInterval = 0
    private weak var consideredArtwork: UIImage?
    private var usedWideTypography: Bool?
    private var inlineFont = UIFont.systemFont(ofSize: 19, weight: .semibold)
    private let title = UIButton(type: .system)
    private let artist = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let menu = UIButton(type: .system)
    private let pane = UIButton(type: .system)
    private weak var fullscreen: PlayerFullscreenPresentation?
    fileprivate var isFullscreen: Bool { fullscreen != nil }
    private let headerTitle = UILabel()
    private var headerGlass: UIVisualEffectView?
    private let trackDetails = PlayerTrackDetailsView(frame: .zero)
    private weak var nativeList: UIScrollView?
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
        isOpaque = tablet
        if tablet { clipsToBounds = true }
        backdrop.backgroundColor = .black
        backdrop.isUserInteractionEnabled = false
        background.contentMode = .scaleAspectFill
        background.alpha = 0.7
        background.isUserInteractionEnabled = false
        background.clipsToBounds = true
        shade.backgroundColor = tablet ? .clear : UIColor.black.withAlphaComponent(0.5)
        shade.isUserInteractionEnabled = false
        if tablet {
            background.alpha = 1
            artworkShade.colors = [UIColor.black.withAlphaComponent(0.21).cgColor,
                                   UIColor.black.withAlphaComponent(0.32).cgColor,
                                   UIColor.black.withAlphaComponent(0.68).cgColor]
            artworkShade.locations = [0, 0.46, 1]
            shade.layer.addSublayer(artworkShade)
            scroll.delegate = self
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
        configure(close, symbol: "chevron.down", label: "Close player") { [weak self] in
            guard let self else { return }
            if tablet { leaveTabletPlayer() } else { performNative("now-playing-minimize-button") }
        }
        configure(menu, symbol: "ellipsis", label: "More options") { [weak self] in
            guard let self else { return }
            performNative("Context menu")
        }
        if tablet {
            close.accessibilityIdentifier = "shrubify.player.close"
            close.accessibilityLabel = "Minimize player"
            configure(pane, symbol: "arrow.up.left.and.arrow.down.right", label: "Enter fullscreen") { [weak self] in
                self?.toggleFullscreen()
            }
            pane.accessibilityIdentifier = "shrubify.player.fullscreen"
            let glass = ShrubifyLiquidGlass.makePlate(prefersReadableGlass: true)
            addSubview(glass)
            headerGlass = glass
            for view in [close, pane, headerTitle, menu] { addSubview(view) }
            headerTitle.textColor = .white
            headerTitle.textAlignment = .center
            headerTitle.lineBreakMode = .byTruncatingTail
            headerTitle.isAccessibilityElement = true
            headerTitle.accessibilityTraits = .header
            trackDetails.openArtist = { [weak self] in self?.openArtist() }
            trackDetails.onContentChange = { [weak self] in self?.setNeedsLayout() }
            scroll.addSubview(trackDetails)
        } else { scroll.addSubview(close); scroll.addSubview(menu) }
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
        artist.addAction(UIAction { [weak self] _ in self?.openArtist() }, for: .touchUpInside)
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
        if self.trackID != currentID {
            self.trackID = currentID
            artwork.image = nil; background.image = nil
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
                if tablet { upgradeTabletArtwork(image) }
                else {
                    artwork.image = image
                    background.image = NowPlayingIOS27.backdrop(from: image)
                }
            }
        }
        discoverNative(in: page)
        if let info {
            if tablet {
                headerTitle.text = info.metadata["album_title"]
                    ?? (native.object(forKey: NowPlayingIOS27.navTitleIdentifier as NSString) as? UILabel)?.text
                    ?? info.title
                trackDetails.setTrack(id: currentID, title: info.title, artist: info.artist,
                                      album: info.metadata["album_title"], isrc: info.metadata["isrc"] ?? info.metadata["ISRC"],
                                      artistURI: info.metadata["artist_uri"])
            }
            title.setTitle(info.title, for: .normal)
            artist.setTitle(info.artist, for: .normal)
            title.accessibilityLabel = info.title
            artist.accessibilityLabel = "Artist: " + info.artist
            title.isEnabled = info.metadata["album_uri"] != nil && SpotifyURIOpener.isReady
            title.accessibilityHint = title.isEnabled ? "Open album" : nil
            artist.isEnabled = PlayerArtistPhoto.artistID(from: info.metadata["artist_uri"]) != nil
        }
        let required = ["SPTNowPlayingPlayButton", "SPTNowPlayingPreviousTrackButton", "SPTNowPlayingNextTrackButton"]
            + (tablet ? [] : ["now-playing-minimize-button"])
        let controlsReady = info != nil && required.allSatisfy {
            activeNative($0).flatMap { NowPlayingIOS27.nearestControl($0) } != nil
        }
        // Changes to Spotify's view tree can briefly detach the transport
        // controls. Keep the installed player covering the native body.
        let ready = tablet || controlsReady
        if !tablet, isHidden == ready { isHidden = !ready; setNeedsLayout() }
        for snapshot in headerSnapshots { snapshot.view?.alpha = ready ? 0 : snapshot.alpha }
        for snapshot in savedAccessibility { snapshot.view?.accessibilityElementsHidden = ready || snapshot.wasHidden }
        guard ready else {
            if !tablet { displayLink?.isPaused = true }
            return
        }
        displayLink?.isPaused = false
        if tablet {
            artworkButton.isEnabled = artwork.image != nil
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
        close.isEnabled = tablet || native.object(forKey: "now-playing-minimize-button") != nil
        if tablet { updateTabletMenu() }
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
        menu.isHidden = !tablet && native.object(forKey: "Context menu") == nil
        updateLyrics()
        if !tablet { setNeedsLayout() }
    }

    private func upgradeTabletArtwork(_ candidate: UIImage) {
        let existing = artwork.image.map { $0.size.width * $0.scale } ?? 0
        guard candidate.size.width * candidate.scale > existing else { return }
        let requestedTrack = trackID
        artwork.image = candidate
        LyricsBackdropImageCache.shared.blurArtwork(candidate) { [weak self] blurred in
            guard let self, artwork.image === candidate, trackID == requestedTrack else { return }
            background.image = blurred
        }
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
        if id == NowPlayingIOS27.contextMenuIdentifier
            || id == NowPlayingLyricsPlate.minimizeButtonIdentifier {
            return source.window === window && !source.isHidden && source.alpha > 0.01 ? source : nil
        }
        guard let page, source.window === page.window, source.isDescendant(of: page), onPlayerPage(source, page: page) else { return nil }
        return source
    }

    private func onPlayerPage(_ source: UIView, page: UIView) -> Bool {
        var node: UIView? = source
        while let view = node, view !== page {
            guard !view.isHidden, view.alpha > 0.01 else { return false }
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
        if tablet { nativeCover = nil }
        savedAccessibility.removeAll { $0.view == nil }
        var queue = [page]; var index = 0
        let ids = Set(actions.keys).union(["now-playing-minimize-button", "Context menu", "SPTNowPlayingSliderV2",
                                          NowPlayingIOS27.navTitleIdentifier])
        while index < queue.count, index < 3000 {
            let view = queue[index]; index += 1
            if view === self { continue }
            queue.append(contentsOf: view.subviews)
            let rect = view.convert(view.bounds, to: page)
            guard !view.isHidden, rect.intersects(page.bounds),
                  !tablet || onPlayerPage(view, page: page) else { continue }
            if tablet, nativeCover == nil, ArtworkInspector.isNativeCover(view) {
                nativeCover = view
            }
            if tablet, NSStringFromClass(type(of: view)).hasSuffix("CreatorBiographyCardLayout"),
               let artist = CurrentSpotifyTrack.snapshot?.artist, !artist.isEmpty {
                let lead = LyricsMatch.leadArtist(artist.components(separatedBy: ", ").first ?? artist)
                _ = EntityPageHeaderManager.tabletBiography(from: view, expectedArtist: lead)
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
            nativeList = NowPlayingOneScreen.findList(in: page)
            if previousCover !== nativeCover { setNeedsLayout() }
        }
        discoverHeader(in: page)
        for child in page.subviews where child !== self && !tablet {
            if !savedAccessibility.contains(where: { $0.view === child }) {
                savedAccessibility.append(AccessibilitySnapshot(child))
            }
            child.accessibilityElementsHidden = true
        }
    }

    // iPad can host the native header as a sibling of the scroll controller.
    // Find those actions without moving or hiding the system views.
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
            let identifier = view.accessibilityIdentifier
            if tablet, identifier == NowPlayingIOS27.navTitleIdentifier, view is UILabel {
                native.setObject(view, forKey: NowPlayingIOS27.navTitleIdentifier as NSString)
            }
            guard let id = identifier, ["Context menu", "now-playing-minimize-button"].contains(id),
                  (!tablet || (!view.isHidden && view.alpha > 0.01 && view.window === page.window)),
                  let control = NowPlayingIOS27.nearestControl(view) else { continue }
            let controlRect = control.convert(control.bounds, to: root)
            guard controlRect.width <= 96, controlRect.height <= 96,
                  controlRect.width >= 16, controlRect.height >= 16 else { continue }
            if native.object(forKey: id as NSString) == nil { native.setObject(view, forKey: id as NSString) }
            if !tablet, !headerSnapshots.contains(where: { $0.view === control }) {
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
        _ = activate(source)
    }

    private func activate(_ source: UIView) -> Bool {
        if let control = NowPlayingIOS27.nearestControl(source), control.isEnabled {
            control.sendActions(for: .touchDown)
            let activation: UIControl.Event = tablet && control.allControlEvents.contains(.primaryActionTriggered)
                ? .primaryActionTriggered : .touchUpInside
            control.sendActions(for: activation)
            return true
        }
        return source.accessibilityActivate()
    }

    private func leaveTabletPlayer() {
        if let fullscreen {
            fullscreen.exit { [weak self] in self?.minimizeTabletPlayer() }
        } else {
            minimizeTabletPlayer()
        }
    }

    private func minimizeTabletPlayer() {
        guard let page, page.window != nil else { return }
        lastDiscovery = 0
        discoverNative(in: page)
        if let source = activeNative(NowPlayingLyricsPlate.minimizeButtonIdentifier), activate(source) { return }
        var modal = WindowHelper.shared.viewController(for: page)
        while let current = modal, current.presentingViewController == nil { modal = current.parent }
        if let modal {
            let name = NSStringFromClass(type(of: modal))
            if name.contains("NowPlaying") || name.contains("NPV") { modal.dismiss(animated: true) }
        }
    }

    private func toggleFullscreen() {
        if let fullscreen { fullscreen.exit(); return }
        guard let page, let window, superview === page,
              let presenter = WindowHelper.shared.viewController(for: page),
              presenter.viewIfLoaded?.window === window, presenter.presentedViewController == nil,
              !presenter.isBeingDismissed, !presenter.isBeingPresented else { return }
        let presentation = PlayerFullscreenPresentation(player: self, origin: page) { [weak self] in
            self?.fullscreen = nil
            self?.updateFullscreenButton()
        }
        fullscreen = presentation
        updateFullscreenButton()
        presenter.present(presentation, animated: true)
    }

    private func updateFullscreenButton() {
        let symbol = isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        pane.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)),
                      for: .normal)
        pane.accessibilityLabel = isFullscreen ? "Exit fullscreen" : "Enter fullscreen"
    }

    private func updateTabletMenu() {
        let nativeMenu = activeNative(NowPlayingIOS27.contextMenuIdentifier)
            .flatMap { NowPlayingIOS27.nearestControl($0) as? UIButton }?.menu
        if menu.menu !== nativeMenu { menu.menu = nativeMenu }
        menu.showsMenuAsPrimaryAction = nativeMenu != nil
        menu.isEnabled = nativeMenu != nil || activeNative(NowPlayingIOS27.contextMenuIdentifier) != nil
    }

    override func accessibilityPerformEscape() -> Bool {
        guard tablet else { return super.accessibilityPerformEscape() }
        leaveTabletPlayer()
        return true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tablet, scrollView === scroll, scrollView.contentOffset.y > 1,
           scrollView.bounds.maxY + 76 >= trackDetails.frame.minY {
            trackDetails.loadIfNeeded()
        }
    }

    fileprivate func keepAboveNativeBody(in page: UIView) {
        guard !isFullscreen, var branch = (nativeList as UIView?) ?? activeNative("SPTNowPlayingPlayButton") else { return }
        while let parent = branch.superview, parent !== page { branch = parent }
        guard branch !== self, branch.superview === page,
              let bodyIndex = page.subviews.firstIndex(of: branch),
              let playerIndex = page.subviews.firstIndex(of: self), playerIndex < bodyIndex else { return }
        page.insertSubview(self, aboveSubview: branch)
    }

    private func openMetadata(_ key: String) {
        guard let info = CurrentSpotifyTrack.snapshot,
              let value = info.metadata[key], let url = URL(string: value) else { return }
        _ = SpotifyURIOpener.open(url.absoluteString)
    }

    private func openArtist() {
        guard let id = PlayerArtistPhoto.artistID(from: CurrentSpotifyTrack.snapshot?.metadata["artist_uri"]) else { return }
        let scene = window?.windowScene
        let navigate: () -> Void = {
            PlayerArtistNavigation.open(id: id, in: scene) {
                SpotifyURIOpener.open($0, allowSystemFallback: false)
            }
        }
        if let fullscreen { fullscreen.exit(completion: navigate) }
        else { navigate() }
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
                if !isHidden { keepAboveNativeBody(in: page) }
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
        if tablet, window == nil {
            lastDiscovery = 0
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
            headerTitle.font = UIFontMetrics(forTextStyle: .headline)
                .scaledFont(for: .systemFont(ofSize: wide ? 19 : 16, weight: .semibold), compatibleWith: traitCollection)
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
        let hit = super.hitTest(point, with: event)
        return tablet && hit === self ? nil : hit
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
        CATransaction.commit()

        close.frame = TabletPlayerLayout.closeFrame(safeTop: safeAreaInsets.top)
        let headerY = close.frame.minY
        pane.frame = CGRect(x: close.frame.maxX + 2, y: headerY, width: 48, height: 48)
        headerGlass?.frame = close.frame.union(pane.frame).insetBy(dx: -2, dy: 2)
        menu.frame = CGRect(x: bounds.width - 60, y: headerY, width: 48, height: 48)
        headerTitle.frame = CGRect(x: 112, y: headerY, width: max(0, bounds.width - 224), height: 48)

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
        let bottom = max(layout.contentHeight, heightWithCredit)
        let detailsWidth = max(0, min(720, scroll.bounds.width - 44))
        trackDetails.frame = CGRect(x: (scroll.bounds.width - detailsWidth) / 2, y: bottom + 18,
                                    width: detailsWidth, height: trackDetails.preferredHeight(for: detailsWidth))
        scroll.contentSize = CGSize(width: scroll.bounds.width, height: trackDetails.frame.maxY + safeAreaInsets.bottom + 16)
        scrollViewDidScroll(scroll)
    }

    private func openArtwork() {
        guard let image = artwork.image else { return }
        if let page {
            lastDiscovery = 0
            discoverNative(in: page)
            if let nativeCover, nativeCover.window === window, ArtworkInspector.nativeImage(in: nativeCover) === image,
               ArtworkInspector.openNative(from: nativeCover) { return }
        }
        if #available(iOS 15.0, *) { ArtworkInspector.present(image, from: self) }
    }

    func removePlayer() {
        fullscreen?.exit(returningPlayer: false)
        displayLink?.invalidate(); displayLink = nil
        if #available(iOS 26.0, *) { lyricsHost?.detach(); lyricsHost = nil }
        for snapshot in savedAccessibility { snapshot.view?.accessibilityElementsHidden = snapshot.wasHidden }
        savedAccessibility.removeAll()
        for snapshot in headerSnapshots { snapshot.view?.alpha = snapshot.alpha }
        headerSnapshots.removeAll()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        removeFromSuperview()
        if let page {
            ResponsivePlayer.released(page)
        }
    }

    private static func time(_ ms: Int) -> String {
        let seconds = max(0, ms / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

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

    static func apply(in page: UIView, image: UIImage?, trackID: String) {
        guard NowPlayingIOS27.isEnabled else { removeAll(); return }
        let view: ResponsivePlayerView
        if let existing = objc_getAssociatedObject(page, &key) as? ResponsivePlayerView {
            view = existing
        } else {
            view = ResponsivePlayerView(page: page)
            objc_setAssociatedObject(page, &key, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            views.add(view)
            page.addSubview(view)
        }
        if view.frame != page.bounds { view.frame = page.bounds }
        view.refresh(image: image, trackID: trackID)
        page.bringSubviewToFront(view)
    }

    static func reconcile() -> Bool {
        guard NowPlayingIOS27.isEnabled else { removeAll(); return false }
        for view in views.allObjects {
            guard let page = view.page, page.window != nil else { view.removePlayer(); continue }
            view.refresh(image: NowPlayingIOS27.metadataArtworkImage, trackID: NowPlayingIOS27.metadataArtworkTrackId)
            if view.frame != page.bounds { view.frame = page.bounds }
            page.bringSubviewToFront(view)
        }
        return false
    }

    static func removeAll() {
        for view in views.allObjects { view.removePlayer() }
    }

    static func owns(_ page: UIView) -> Bool {
        (objc_getAssociatedObject(page, &key) as? ResponsivePlayerView)?.superview === page
    }

    static func released(_ page: UIView) {
        objc_setAssociatedObject(page, &key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

@MainActor
final class ResponsivePlayerView: UIView {
    weak var page: UIView?
    private let scroll = UIScrollView()
    private let background = UIImageView()
    private let shade = UIView()
    let artwork = UIImageView()
    private let title = UIButton(type: .system)
    private let artist = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let menu = UIButton(type: .system)
    private let progress = UISlider()
    private let elapsed = UILabel()
    private let remaining = UILabel()
    private let volume = MPVolumeView()
    private let controls = UIStackView()
    private let footer = UIStackView()
    private let lyrics = UIView()
    private let notice = UILabel()
    private let credit = UILabel()
    private let lyricsButton = UIButton(type: .system)
    private var actions: [String: UIButton] = [:]
    private let native = NSMapTable<NSString, UIView>.strongToWeakObjects()
    private var savedAccessibility: [(UIView, Bool)] = []
    private final class HeaderSnapshot {
        weak var view: UIView?
        let alpha: CGFloat
        init(_ view: UIView) { self.view = view; alpha = view.alpha }
    }
    private var headerSnapshots: [HeaderSnapshot] = []
    private var lastDiscovery: TimeInterval = 0
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

    init(page: UIView) {
        self.page = page
        super.init(frame: page.bounds)
        accessibilityIdentifier = "shrubify-responsive-player"
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .black
        background.contentMode = .scaleAspectFill
        background.alpha = 0.7
        background.isUserInteractionEnabled = false
        background.clipsToBounds = true
        shade.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        shade.isUserInteractionEnabled = false
        addSubview(background); addSubview(shade); addSubview(scroll)
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.addSubview(artwork)
        artwork.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        artwork.contentMode = .scaleAspectFit
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 14
        artwork.accessibilityLabel = "Album artwork"
        artwork.isAccessibilityElement = true
        configure(close, symbol: "chevron.down", label: "Close player") { [weak self] in self?.performNative("now-playing-minimize-button") }
        configure(menu, symbol: "ellipsis", label: "More options") { [weak self] in self?.performNative("Context menu") }
        scroll.addSubview(close); scroll.addSubview(menu)
        title.setTitleColor(.white, for: .normal)
        artist.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
        title.contentHorizontalAlignment = .leading
        artist.contentHorizontalAlignment = .leading
        title.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title2)
        artist.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        title.titleLabel?.adjustsFontForContentSizeCategory = true
        artist.titleLabel?.adjustsFontForContentSizeCategory = true
        title.titleLabel?.lineBreakMode = .byTruncatingTail
        artist.titleLabel?.lineBreakMode = .byTruncatingTail
        title.addAction(UIAction { [weak self] _ in self?.openMetadata("album_uri") }, for: .touchUpInside)
        artist.addAction(UIAction { [weak self] _ in self?.openMetadata("artist_uri") }, for: .touchUpInside)
        scroll.addSubview(title); scroll.addSubview(artist)
        progress.minimumValue = 0; progress.maximumValue = 1
        progress.accessibilityLabel = "Playback position"
        progress.addAction(UIAction { [weak self] _ in self?.seekingTrackID = self?.trackID }, for: .touchDown)
        progress.addAction(UIAction { [weak self] _ in self?.seek() }, for: [.touchUpInside, .touchUpOutside])
        progress.addAction(UIAction { [weak self] _ in
            guard let self, !self.progress.isTracking else { return }
            self.seek()
        }, for: .valueChanged)
        scroll.addSubview(progress)
        for label in [elapsed, remaining] {
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            scroll.addSubview(label)
        }
        remaining.textAlignment = .right
        controls.axis = .horizontal; controls.distribution = .equalSpacing; controls.alignment = .center
        for (id, symbol, label) in [
            ("Components.UI.ShuffleButton", "shuffle", "Shuffle"),
            ("SPTNowPlayingPreviousTrackButton", "backward.end.fill", "Previous track"),
            ("SPTNowPlayingPlayButton", "play.fill", "Play"),
            ("SPTNowPlayingNextTrackButton", "forward.end.fill", "Next track"),
            ("Nowplaying-RepeatButton", "repeat", "Repeat")
        ] {
            let button = UIButton(type: .system)
            configure(button, symbol: symbol, label: label) { [weak self] in self?.performNative(id) }
            actions[id] = button; controls.addArrangedSubview(button)
        }
        scroll.addSubview(controls)
        volume.showsRouteButton = false
        volume.accessibilityLabel = "Volume"
        scroll.addSubview(volume)
        footer.axis = .horizontal; footer.distribution = .equalSpacing; footer.alignment = .center
        configure(lyricsButton, symbol: "quote.bubble", label: "Lyrics") { [weak self] in self?.toggleLyrics() }
        footer.addArrangedSubview(lyricsButton)
        for (id, symbol, label) in [
            ("shrubify-connect", "airplay.audio", "Audio output"),
            ("QueueButtonNowPlaying", "list.bullet", "Queue"),
            ("shrubify-save", "plus.circle", "Save track")
        ] {
            let button = UIButton(type: .system)
            configure(button, symbol: symbol, label: label) { [weak self] in self?.performNative(id) }
            actions[id] = button; footer.addArrangedSubview(button)
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
        for child in page.subviews {
            savedAccessibility.append((child, child.accessibilityElementsHidden))
            child.accessibilityElementsHidden = true
        }
    }

    required init?(coder: NSCoder) { return nil }

    private func configure(_ button: UIButton, symbol: String, label: String, action: @escaping () -> Void) {
        button.tintColor = .white
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .medium)), for: .normal)
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    func refresh(image: UIImage?, trackID: String) {
        guard let page else { return }
        let currentID = NowPlayingLyricsPlate.currentTrackId() ?? trackID
        if self.trackID != currentID {
            self.trackID = currentID
            artwork.image = nil; background.image = nil
            lastVersion = -1
        }
        // An image is only accepted for the metadata request's exact track.
        if trackID == currentID, let image, artwork.image !== image {
            artwork.image = image
            background.image = NowPlayingIOS27.backdrop(from: image)
        }
        let info = SafeTrackMetadata(track: statefulPlayer?.currentTrack() as AnyObject?)
        if let info {
            title.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title2)
            artist.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            title.setTitle(info.title, for: .normal)
            artist.setTitle(info.artist, for: .normal)
            title.accessibilityLabel = "Album for " + info.title
            artist.accessibilityLabel = "Artist: " + info.artist
            title.isEnabled = info.metadata["album_uri"] != nil && SpotifyURIOpener.isReady
            artist.isEnabled = info.metadata["artist_uri"] != nil && SpotifyURIOpener.isReady
        }
        discoverNative(in: page)
        let ready = info != nil && ["SPTNowPlayingPlayButton", "SPTNowPlayingPreviousTrackButton", "SPTNowPlayingNextTrackButton", "now-playing-minimize-button"].allSatisfy {
            native.object(forKey: $0 as NSString).flatMap { NowPlayingIOS27.nearestControl($0) } != nil
        }
        isHidden = !ready
        for snapshot in headerSnapshots { snapshot.view?.alpha = ready ? 0 : snapshot.alpha }
        for (child, original) in savedAccessibility { child.accessibilityElementsHidden = ready ? true : original }
        guard ready else { displayLink?.isPaused = true; return }
        displayLink?.isPaused = false
        KaraokeSeek.player = statefulPlayer as AnyObject?
        let state = KaraokeSeek.refresh()
        if !progress.isTracking {
            progress.value = state.durationMs > 0 ? Float(state.positionMs) / Float(state.durationMs) : 0
        }
        progress.isEnabled = state.durationMs > 0
        elapsed.text = Self.time(state.positionMs)
        remaining.text = "−" + Self.time(max(0, state.durationMs - state.positionMs))
        if let play = actions["SPTNowPlayingPlayButton"] {
            play.setImage(UIImage(systemName: state.isPlaying ? "pause.fill" : "play.fill",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)), for: .normal)
            play.accessibilityLabel = state.isPlaying ? "Pause" : "Play"
        }
        for (id, button) in actions {
            let source = native.object(forKey: id as NSString)
            button.isEnabled = source.map { (NowPlayingIOS27.nearestControl($0)?.isEnabled ?? true) && $0.isUserInteractionEnabled } ?? false
            button.alpha = button.isEnabled ? 1 : 0.35
            if let label = source?.accessibilityLabel, !label.isEmpty { button.accessibilityLabel = label }
            button.isSelected = (source as? UIControl)?.isSelected ?? false
            button.accessibilityValue = source?.accessibilityValue ?? (button.isSelected ? "On" : nil)
            button.tintColor = button.isSelected ? .systemGreen : .white
        }
        close.isEnabled = native.object(forKey: "now-playing-minimize-button") != nil
        let disabled = NgzhwmSettingsViewModel.isLyricsFeatureDisabled
        if #available(iOS 26.0, *), UserDefaults.shouldReplaceLyrics {
            lyricsButton.isEnabled = !disabled
        } else { lyricsButton.isEnabled = !disabled && NowPlayingIOS27.lyricsEntryTarget(in: page) != nil }
        if disabled || !UserDefaults.shouldReplaceLyrics {
            showingLyrics = false
            lyrics.isHidden = true
            if #available(iOS 26.0, *) { lyricsHost?.detach() }
        }
        menu.isHidden = native.object(forKey: "Context menu") == nil
        updateLyrics()
        setNeedsLayout()
    }

    private func discoverNative(in page: UIView) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDiscovery > 1 else { return }
        lastDiscovery = now
        native.removeAllObjects()
        var queue = [page]; var index = 0
        let ids = Set(actions.keys).union(["now-playing-minimize-button", "Context menu", "SPTNowPlayingSliderV2"])
        while index < queue.count, index < 3000 {
            let view = queue[index]; index += 1
            if view === self { continue }
            queue.append(contentsOf: view.subviews)
            let rect = view.convert(view.bounds, to: page)
            guard !view.isHidden, rect.intersects(page.bounds) else { continue }
            if let id = view.accessibilityIdentifier, ids.contains(id),
               native.object(forKey: id as NSString) == nil || native.object(forKey: id as NSString)?.window == nil {
                native.setObject(view, forKey: id as NSString)
            }
            let name = NSStringFromClass(type(of: view))
            if name.contains("ConnectButton"), native.object(forKey: "shrubify-connect") == nil {
                native.setObject(view, forKey: "shrubify-connect")
            }
            if name.contains("AddToButton"), native.object(forKey: "shrubify-save") == nil {
                native.setObject(view, forKey: "shrubify-save")
            }
        }
        discoverHeader(in: page)
        for child in page.subviews where child !== self {
            if !savedAccessibility.contains(where: { $0.0 === child }) {
                savedAccessibility.append((child, child.accessibilityElementsHidden))
            }
            child.accessibilityElementsHidden = true
        }
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
        guard let source = native.object(forKey: id as NSString), source.window === window else { return }
        if let control = NowPlayingIOS27.nearestControl(source), control.isEnabled {
            control.sendActions(for: .touchDown)
            control.sendActions(for: .touchUpInside)
        } else { _ = source.accessibilityActivate() }
    }

    private func openMetadata(_ key: String) {
        guard let info = SafeTrackMetadata(track: statefulPlayer?.currentTrack() as AnyObject?),
              let value = info.metadata[key], let url = URL(string: value) else { return }
        _ = SpotifyURIOpener.open(url.absoluteString)
    }

    private func seek() {
        defer { seekingTrackID = nil }
        guard (seekingTrackID ?? trackID) == NowPlayingLyricsPlate.currentTrackId() else { return }
        let state = KaraokeSeek.refresh()
        guard state.durationMs > 0 else { return }
        if let slider = native.object(forKey: "SPTNowPlayingSliderV2") as? UISlider {
            slider.value = slider.minimumValue + progress.value * (slider.maximumValue - slider.minimumValue)
            slider.sendActions(for: .valueChanged)
            slider.sendActions(for: .touchUpInside)
        } else { _ = KaraokeSeek.seek(milliseconds: Int(Float(state.durationMs) * progress.value), trackID: trackID) }
    }

    private func toggleLyrics() {
        if #available(iOS 26.0, *), UserDefaults.shouldReplaceLyrics {
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
        guard showingLyrics, !isHidden, window != nil, UIApplication.shared.applicationState == .active else { return }
        let link = CADisplayLink(target: self, selector: #selector(tickLyrics))
        link.preferredFramesPerSecond = UIAccessibility.isReduceMotionEnabled ? 15 : 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tickLyrics() {
        if #available(iOS 26.0, *) {
            lyricsHost?.tick(seconds: WordByWordPositionResolver.shared.currentPositionSeconds())
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateClock()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let layout = PlayerLayout(size: bounds.size, top: safeAreaInsets.top, bottom: safeAreaInsets.bottom, largeText: large)
        background.frame = bounds; shade.frame = bounds; scroll.frame = bounds
        background.isHidden = UIAccessibility.isReduceTransparencyEnabled
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

    func removePlayer() {
        displayLink?.invalidate(); displayLink = nil
        if #available(iOS 26.0, *) { lyricsHost?.detach(); lyricsHost = nil }
        for (view, hidden) in savedAccessibility { view.accessibilityElementsHidden = hidden }
        savedAccessibility.removeAll()
        for snapshot in headerSnapshots { snapshot.view?.alpha = snapshot.alpha }
        headerSnapshots.removeAll()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        removeFromSuperview()
        if let page { ResponsivePlayer.released(page) }
    }

    private static func time(_ ms: Int) -> String {
        let seconds = max(0, ms / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

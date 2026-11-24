import UIKit
import SwiftUI

// Fixture-only playback inputs. Controls, material, timing and dismissal are
// compiled directly from production sources, and receive real XCUITest taps.
struct KaraokePlaybackSnapshot {
    var durationMs = 180_000
    var positionMs = 60_000
    var hasPosition = true
    var isPlaying = false
    var isPlaybackStateKnown = true
    var trackID: String? = "fixture"
}

@main
final class InteractionApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UserDefaults.standard.set(true, forKey: "ShrubifyCustomLyricsGlass")
        if ProcessInfo.processInfo.arguments.contains("saved-glass-on") {
            UserDefaults.standard.set(true, forKey: NativeTabletGlass.preferenceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: NativeTabletGlass.preferenceKey)
        }
        NativeTabletGlass.start()
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Interactions", sessionRole: session.role)
        configuration.delegateClass = InteractionScene.self
        return configuration
    }
}
final class InteractionScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = RootController()
        window.makeKeyAndVisible(); self.window = window
    }
}

final class TabBarGradientView: UIView {}
final class TabBarItemElementView: UIButton {}
final class FixtureTabBarView: UIVisualEffectView {}
final class FixtureBackdropView: UIView {}

final class RootController: UIViewController {
    private var closes = 0
    private let closeCount = UILabel()
    private let materialState = UILabel()
    private let tabCount = UILabel()
    private let selectionStatus = UILabel()
    private let opticalSelection = UILabel()
    private var selections = 0
    private let barSurface = FixtureTabBarView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let dockWrapper = UIView()
    private let dockBacking = UIView()
    private let dockBackdrop = FixtureBackdropView()
    private var blueBackdrop = false
    private var barHost: UIView { barSurface.contentView }
    private let content = ContentFixture(frame: .zero)
    private let miniHost = UIView()
    private let mini = UIView()
    private let miniPlay = UIButton(type: .system)
    private let row = UIStackView()
    private let legacy = TabBarGradientView()
    private var didCaptureNativeLayout = false
    private var nativeFrames: [CGRect] = []
    private var nativeMargins: NSDirectionalEdgeInsets = .zero
    private var nativeMarginsRelative = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.1, green: 0.25, blue: 0.4, alpha: 1)
        let open = UIButton(type: .system)
        open.setTitle("Open lyrics", for: .normal); open.accessibilityIdentifier = "open-lyrics"
        open.addAction(UIAction { [weak self] _ in self?.openLyrics() }, for: .touchUpInside)
        open.frame = CGRect(x: 32, y: 60, width: 180, height: 60); view.addSubview(open)
        closeCount.frame = CGRect(x: 240, y: 60, width: 160, height: 60)
        closeCount.accessibilityIdentifier = "close-count"; closeCount.text = "0"; view.addSubview(closeCount)
        materialState.frame = CGRect(x: 32, y: 140, width: 900, height: 40)
        materialState.accessibilityIdentifier = "material-state"; view.addSubview(materialState)
        tabCount.frame = CGRect(x: 32, y: 190, width: 240, height: 40)
        tabCount.accessibilityIdentifier = "tab-count"; tabCount.text = "0"; view.addSubview(tabCount)
        selectionStatus.frame = CGRect(x: 550, y: 190, width: 250, height: 40)
        selectionStatus.accessibilityIdentifier = "selection-state"; view.addSubview(selectionStatus)
        opticalSelection.frame = CGRect(x: 32, y: 222, width: 245, height: 40)
        opticalSelection.accessibilityIdentifier = "optical-selection"; view.addSubview(opticalSelection)
        let backdropButton = UIButton(type: .system)
        backdropButton.setTitle("Swap dock backdrop", for: .normal)
        backdropButton.accessibilityIdentifier = "swap-dock-backdrop"
        backdropButton.frame = CGRect(x: 290, y: 230, width: 245, height: 34)
        backdropButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            blueBackdrop.toggle()
            dockBackdrop.backgroundColor = blueBackdrop ? .systemBlue : .systemRed
        }, for: .touchUpInside)
        view.addSubview(backdropButton)
        let toggle = UIButton(type: .system); toggle.setTitle("Toggle native glass", for: .normal)
        toggle.frame = CGRect(x: 300, y: 190, width: 240, height: 48); toggle.accessibilityIdentifier = "toggle-glass"
        toggle.addAction(UIAction { [weak self] _ in
            // Flip the effective choice: with no stored value the bars are
            // already glassed, so reading the raw key would leave them on.
            let key = NativeTabletGlass.preferenceKey
            UserDefaults.standard.set(!NativeTabletGlass.isOnForCurrentDevice, forKey: key)
            NativeTabletGlass.reapply()
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
            self?.reportMaterial()
        }, for: .touchUpInside); view.addSubview(toggle)
        view.addSubview(content)
        dockBackdrop.backgroundColor = .systemRed
        dockBackdrop.isUserInteractionEnabled = false
        view.addSubview(dockBackdrop)
        dockBacking.backgroundColor = .darkGray
        dockBacking.isUserInteractionEnabled = false
        view.addSubview(dockBacking)
        view.addSubview(dockWrapper)
        dockWrapper.addSubview(barSurface)
        miniHost.frame = CGRect(x: 568, y: 64, width: 240, height: 56); view.addSubview(miniHost)
        mini.frame = miniHost.bounds; mini.accessibilityIdentifier = "SPTNowPlayingBar"
        mini.backgroundColor = .darkGray; miniHost.addSubview(mini)
        miniPlay.frame = CGRect(x: 64, y: 0, width: 112, height: 56)
        miniPlay.accessibilityIdentifier = "mini-play"; miniPlay.setTitle("Play", for: .normal)
        miniPlay.addAction(UIAction { [weak self] _ in self?.miniPlay.setTitle("Pause", for: .normal) }, for: .touchUpInside)
        mini.addSubview(miniPlay)
        barHost.backgroundColor = .darkGray
        legacy.frame = CGRect(x: 0, y: -112, width: 825, height: 195); legacy.backgroundColor = .black
        legacy.accessibilityIdentifier = "fixture-legacy"
        barHost.addSubview(legacy)
        row.axis = .horizontal; row.distribution = .fillEqually
        row.accessibilityIdentifier = "tabs-container-view-identifier"
        barHost.addSubview(row)
        for index in 0..<5 {
            let button = TabBarItemElementView(frame: .zero); button.setTitle("Tab \(index)", for: .normal)
            button.setImage(UIImage(systemName: "square.grid.2x2.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24)), for: .normal)
            button.accessibilityIdentifier = "TabBar.Item.fixture-\(index)"
            button.isSelected = index == 0
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }; selections += 1; tabCount.text = "\(selections)"
                for (i, item) in row.arrangedSubviews.enumerated() { (item as? UIControl)?.isSelected = i == index }
                layoutBars()
                reportMaterial()
            }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        content.frame = CGRect(x: 24, y: 264, width: min(660, view.bounds.width - 48), height: 200)
        dockWrapper.frame = CGRect(x: 32, y: view.bounds.height - 104, width: min(825, view.bounds.width - 64), height: 84)
        dockBacking.frame = dockWrapper.frame
        dockBackdrop.frame = dockWrapper.frame.insetBy(dx: -8, dy: -12)
        barSurface.frame = dockWrapper.bounds
        barSurface.layoutIfNeeded()
        row.frame = barHost.bounds
        legacy.frame = CGRect(x: 0, y: -112, width: barHost.bounds.width, height: 195)
        row.layoutIfNeeded()
        // Mirror the navigation controller's nested footer and sibling backing.
        if didCaptureNativeLayout { layoutBars() }
    }
    private func layoutBars() {
        NativeTabletGlass.layout(.tabs, in: barSurface, navigationRoot: view)
        NativeTabletGlass.layout(.miniPlayer, in: miniHost)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.layoutIfNeeded()
        if !didCaptureNativeLayout {
            // Wait for the visual-effect host to finish its first layout
            // before taking the unmodified tab frame baseline.
            row.setNeedsLayout()
            row.layoutIfNeeded()
            nativeFrames = controlFrames
            nativeMargins = row.directionalLayoutMargins
            nativeMarginsRelative = row.isLayoutMarginsRelativeArrangement
            didCaptureNativeLayout = true
            layoutBars()
        }
        reportMaterial()
    }
    private var controlFrames: [CGRect] { row.arrangedSubviews.map(\.frame) + [miniPlay.frame] }
    private func reportMaterial() {
        content.report()
        let extra = row.subviews.filter { $0.accessibilityIdentifier == "shrubify.native.selection" }
        if let selected = row.arrangedSubviews.firstIndex(where: { ($0 as? UIControl)?.isSelected == true }) {
            selectionStatus.text = "Tab \(selected) native-selected · \(extra.count) overlays"
        } else { selectionStatus.text = "No selected tab · \(extra.count) overlays" }
        let glasses = view.subviews.compactMap { $0 as? UIVisualEffectView }
            .filter { $0.accessibilityIdentifier == "shrubify.native.glass.material" && $0.effect is UIGlassEffect }
        let tabs = glasses.filter { abs($0.frame.midY - dockWrapper.frame.midY) < 30 }
        let minis = glasses.filter { abs($0.frame.midY - miniHost.frame.midY) < 30 }
        if let plate = tabs.first, let marker = plate.contentView.subviews.first(where: {
            $0.accessibilityIdentifier == "shrubify.native.selection" && !$0.isHidden
        }), plate.contentView.bounds.contains(marker.frame),
           let index = row.arrangedSubviews.firstIndex(where: { item in
               item.bounds.contains(marker.convert(CGPoint(x: marker.bounds.midX, y: marker.bounds.midY), to: item))
           }) {
            opticalSelection.text = "Lens under tab \(index)"
        } else {
            opticalSelection.text = "No selection lens"
        }
        let safe = (tabs + minis).allSatisfy { plate in
            guard let parent = plate.superview, let plateIndex = parent.subviews.firstIndex(of: plate) else { return false }
            let host: UIView = tabs.contains(where: { $0 === plate }) ? dockWrapper : miniHost
            guard let hostIndex = parent.subviews.firstIndex(of: host) else { return false }
            return !plate.isUserInteractionEnabled && plate.accessibilityElementsHidden && plateIndex < hostIndex
        }
        let wells = (row.arrangedSubviews + [miniPlay]).reduce(0) { $0 + $1.fixtureGlassCount }
        let cleared = legacy.alpha == 0 && dockBacking.alpha == 0 && barSurface.effect == nil
            && (barHost.layer.backgroundColor?.alpha ?? 0) == 0
            && (mini.layer.backgroundColor?.alpha ?? 0) == 0
        let restored = legacy.alpha == 1 && dockBacking.alpha == 1 && barSurface.effect is UIBlurEffect
            && barHost.backgroundColor == .darkGray && mini.backgroundColor == .darkGray
        let backing = cleared ? "cleared" : (restored ? "native" : "partial")
        let frames = controlFrames
        let controlsIntact = cleared
            ? frames.last == nativeFrames.last && row.arrangedSubviews.allSatisfy {
                $0.frame.width >= 44 && $0.frame.height >= 44 && row.bounds.contains($0.frame)
            }
            : frames.count == nativeFrames.count
                && zip(frames, nativeFrames).allSatisfy { pair in
                    let (actual, original) = pair
                    return abs(actual.minX - original.minX) < 0.5 && abs(actual.maxX - original.maxX) < 0.5
                        && abs(actual.minY - original.minY) < 0.5 && abs(actual.maxY - original.maxY) < 0.5
                }
                // The safe area can change the effective vertical margins
                // after presentation. Compaction owns only horizontal margins.
                && row.directionalLayoutMargins.leading == nativeMargins.leading
                && row.directionalLayoutMargins.trailing == nativeMargins.trailing
                && row.isLayoutMarginsRelativeArrangement == nativeMarginsRelative
        materialState.text = "\(tabs.count)/\(minis.count) bars · \(wells) wells · \(controlsIntact && safe ? "intact" : "changed") · \(backing)"
        materialState.accessibilityValue = controlsIntact ? nil
            : "Frames \(frames) vs \(nativeFrames), margins \(row.directionalLayoutMargins) vs \(nativeMargins), relative \(row.isLayoutMarginsRelativeArrangement) vs \(nativeMarginsRelative)"
    }
    private func openLyrics() {
        let modal = KaraokeModal.make(onDismiss: { [weak self] in
            guard let self else { return }; closes += 1; closeCount.text = "\(closes)"
        }) { close in LyricsControlsFixture(close: close) }
        present(modal, animated: true)
    }
}

struct LyricsControlsFixture: View {
    let close: () -> Void
    @State private var offset = 0
    @State private var playback = KaraokePlaybackSnapshot()
    @State private var redraw = 0
    @State private var seekTarget = 0
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue, .orange], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 24) {
                HStack { Text("Production lyrics controls"); Spacer(); KaraokeCloseButton(action: close) }
                KaraokeReadingPane(offset: $offset, activeLine: 20) { _ in
                    LazyVStack {
                        ForEach(0..<50) { line in Text("Lyric line \(line)").frame(height: 48).id(line) }
                    }
                }
                Text("\(offset)").accessibilityIdentifier("offset-value")
                Text("\(seekTarget)").accessibilityIdentifier("seek-value")
                // Continuous redraw reproduces the live renderer's 30 Hz updates.
                Text("Frame \(redraw)").accessibilityIdentifier("redraw-count")
                Spacer()
                KaraokePlaybackControls(playback: playback, seek: { target in
                    seekTarget = target; playback.positionMs = target; return true
                }, toggle: { playback.isPlaying.toggle(); return true })
            }.padding(32)
        }.preferredColorScheme(.dark)
            .onReceive(clock) { _ in redraw += 1 }
    }
}

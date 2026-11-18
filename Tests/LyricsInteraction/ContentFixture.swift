import UIKit

/// Native controls with the same identities as the supported Spotify surfaces.
/// The test does not inject into Spotify, relay a tap, or draw a fake material.
final class ContentFixture: UIScrollView {
    private let tile = UIButton(type: .system)
    private let cover = UIImageView(image: UIImage(systemName: "opticaldisc.fill"))
    private let play = UIButton(type: .system)
    private let reusable = UICollectionViewCell()
    private let track = UIButton(type: .system)
    private let result = UILabel()
    private let action = UILabel()
    private let ids = ["Shortcut.Card.Home", "Components.Header.UI.ArtworkImage", "SPTNowPlayingPlayButton", "Album.Row.Library"]
    private var nativeFrames: [CGRect] = []
    private var surfaces: [UIView] { [tile, cover, play, track] }

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "native-content-scroll"
        alwaysBounceHorizontal = true
        contentSize = CGSize(width: 1160, height: 180)
        tile.frame = CGRect(x: 4, y: 6, width: 184, height: 52)
        tile.setTitle("Home shortcut", for: .normal)
        tile.backgroundColor = .darkGray
        cover.frame = CGRect(x: 202, y: 6, width: 90, height: 90)
        cover.backgroundColor = .systemIndigo
        play.frame = CGRect(x: 304, y: 6, width: 54, height: 54)
        play.setImage(UIImage(systemName: "play.fill"), for: .normal)
        reusable.frame = CGRect(x: 374, y: 6, width: 216, height: 54)
        track.frame = reusable.bounds; track.setTitle("Native track", for: .normal)
        reusable.contentView.addSubview(track)
        for view in [tile, cover, play, reusable] { addSubview(view) }
        for (view, id) in zip(surfaces, ids) { view.accessibilityIdentifier = id }
        nativeFrames = surfaces.map(\.frame)
        for (button, title) in [(tile, "shortcut"), (play, "play"), (track, "track")] {
            button.addAction(UIAction { [weak self] _ in self?.action.text = title }, for: .touchUpInside)
        }
        action.frame = CGRect(x: 300, y: 114, width: 120, height: 44)
        action.accessibilityIdentifier = "content-action"; action.text = "none"; addSubview(action)
        result.frame = CGRect(x: 4, y: 64, width: 180, height: 40)
        result.accessibilityIdentifier = "content-material-count"; addSubview(result)
        let reuse = UIButton(type: .system); reuse.setTitle("Repurpose row", for: .normal)
        reuse.frame = CGRect(x: 4, y: 114, width: 180, height: 44); reuse.accessibilityIdentifier = "reuse-row"
        reuse.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            NativeContentGlass.prepareForReuse(reusable)
            track.accessibilityIdentifier = "unknown-row"
            NativeContentGlass.refresh(in: reusable)
            report()
        }, for: .touchUpInside); addSubview(reuse)
        let far = UIButton(type: .system); far.setTitle("Shelf end", for: .normal)
        far.frame = CGRect(x: 1000, y: 10, width: 140, height: 52); far.accessibilityIdentifier = "shelf-end"
        far.addAction(UIAction { [weak self] _ in self?.action.text = "shelf end" }, for: .touchUpInside); addSubview(far)
    }
    required init?(coder: NSCoder) { return nil }

    func report() {
        // Repeated local layout passes must be idempotent. Count actual effects,
        // not flags, and verify they cannot intercept the intended native touch.
        for view in surfaces { NativeContentGlass.refresh(in: view); NativeContentGlass.refresh(in: view) }
        let plates = surfaces.flatMap { $0.subviews.compactMap { $0 as? UIVisualEffectView } }
        let count = plates.filter { $0.effect is UIGlassEffect && !$0.isUserInteractionEnabled && $0.accessibilityElementsHidden }.count
        let unchanged = nativeFrames == surfaces.map(\.frame) && tile.backgroundColor == .darkGray
        result.text = "\(count) · \(unchanged ? "intact" : "changed")"
    }
}

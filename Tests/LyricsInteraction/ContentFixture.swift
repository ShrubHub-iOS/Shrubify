import UIKit

// Test-side inspection only. Production glass must never visit these surfaces.
extension UIView {
    var fixtureGlassCount: Int {
        if (self as? UIVisualEffectView)?.effect is UIGlassEffect { return 1 }
        return subviews.reduce(0) { $0 + $1.fixtureGlassCount }
    }
}

/// Known Home/player identities, plus a real scrolling and recycling shelf.
/// A high-contrast image makes a frosted cover detectable in an actual screenshot.
final class ContentFixture: UIView, UICollectionViewDataSource {
    private let tile = UIButton(type: .system)
    private let cover = UIImageView()
    private let player = UIView()
    private let playerCover = UIImageView()
    private let play = UIButton(type: .system)
    private let action = UILabel()
    private let result = UILabel()
    private let shelf: UICollectionView
    private var sawReuse = false
    private var nativeFrames: [CGRect] = []
    private var surfaces: [UIView] { [tile, cover, player, playerCover, play] }

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal; layout.itemSize = CGSize(width: 150, height: 52)
        shelf = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        let artwork = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            for y in 0..<16 { for x in 0..<16 {
                context.cgContext.setFillColor(((x + y).isMultiple(of: 2) ? UIColor.white : .black).cgColor)
                context.cgContext.fill(CGRect(x: CGFloat(x * 5), y: CGFloat(y * 5), width: 5, height: 5))
            } }
        }
        tile.frame = CGRect(x: 4, y: 4, width: 150, height: 52)
        tile.setTitle("Home shortcut", for: .normal); tile.backgroundColor = .darkGray
        tile.accessibilityIdentifier = "Shortcut.Card.Home"
        play.frame = CGRect(x: 166, y: 4, width: 54, height: 54)
        play.setImage(UIImage(systemName: "play.fill"), for: .normal)
        play.accessibilityIdentifier = "SPTNowPlayingPlayButton"
        for (button, name) in [(tile, "shortcut"), (play, "play")] {
            button.addAction(UIAction { [weak self] _ in self?.action.text = name }, for: .touchUpInside)
        }
        cover.frame = CGRect(x: 240, y: 4, width: 80, height: 80)
        cover.accessibilityIdentifier = "Components.UI.CardLibrary.Artwork"
        player.frame = CGRect(x: 350, y: 4, width: 120, height: 120)
        player.accessibilityIdentifier = "SPTNowPlayingView"
        playerCover.frame = player.bounds; playerCover.accessibilityIdentifier = "Encore.ImageView"
        player.addSubview(playerCover)
        for image in [cover, playerCover] {
            image.image = artwork; image.isAccessibilityElement = true; image.accessibilityTraits = .image
        }
        action.frame = CGRect(x: 4, y: 60, width: 180, height: 32)
        action.accessibilityIdentifier = "content-action"; action.text = "none"
        result.frame = CGRect(x: 4, y: 92, width: 300, height: 32)
        result.accessibilityIdentifier = "content-state"
        shelf.backgroundColor = .clear; shelf.dataSource = self; shelf.isPrefetchingEnabled = false
        shelf.register(TrackCell.self, forCellWithReuseIdentifier: "track")
        shelf.accessibilityIdentifier = "native-shelf"
        for view in [tile, cover, player, play, action, result, shelf] { addSubview(view) }
        nativeFrames = surfaces.map(\.frame)
    }
    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        shelf.frame = CGRect(x: 4, y: 136, width: min(520, max(0, bounds.width - 8)), height: 60)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 16 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "track", for: indexPath) as! TrackCell
        let item = indexPath.item
        if cell.wasReused { sawReuse = true }
        cell.contentView.accessibilityIdentifier = item.isMultiple(of: 2) ? "Album.Row.Library" : "unknown-row"
        cell.button.setTitle("Track \(item)", for: .normal)
        cell.button.accessibilityIdentifier = "track-\(item)"
        cell.tap = { [weak self] in
            self?.action.text = "track \(item)"; self?.report()
        }
        return cell
    }

    func report() {
        let intact = nativeFrames == surfaces.map(\.frame) && tile.backgroundColor == .darkGray
        result.text = "\(fixtureGlassCount) effects · \(intact ? "intact" : "changed") · \(sawReuse ? "reused" : "initial")"
    }
}

private final class TrackCell: UICollectionViewCell {
    let button = UIButton(type: .system)
    var tap: (() -> Void)?
    var wasReused = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        button.frame = contentView.bounds; button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.addAction(UIAction { [weak self] _ in self?.tap?() }, for: .touchUpInside)
        contentView.addSubview(button)
    }
    required init?(coder: NSCoder) { return nil }
    override func prepareForReuse() { super.prepareForReuse(); wasReused = true; tap = nil }
}

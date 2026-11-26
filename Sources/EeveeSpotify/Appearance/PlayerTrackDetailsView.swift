import UIKit

@MainActor
final class PlayerTrackDetailsView: UIView {
    private let stack = UIStackView()
    private let artistCard = UIStackView()
    private let creditsCard = UIStackView()
    private let photoRow = UIView()
    private let photo = UIImageView()
    private let artistHeading = UILabel()
    private let artistName = UILabel()
    private let biography = UILabel()
    private let biographySource = UIButton(type: .system)
    private let artistLink = UIButton(type: .system)
    private let credits = UIStackView()
    private var id = ""
    private var info: (title: String, artist: String, album: String?, isrc: String?)?
    private var biographyURL: URL?
    private var photoID: String?
    private var requestedPhotoID: String?
    private var reservesPhoto = false
    private var started = false
    var onContentChange: (() -> Void)?
    var openArtist: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.spacing = 16
        for card in [artistCard, creditsCard] {
            card.axis = .vertical
            card.spacing = 12
            card.isLayoutMarginsRelativeArrangement = true
            card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            card.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            card.layer.cornerRadius = 24
            card.layer.cornerCurve = .continuous
            stack.addArrangedSubview(card)
        }
        photo.contentMode = .scaleAspectFit
        photo.clipsToBounds = true
        photo.layer.cornerCurve = .continuous
        photo.layer.cornerRadius = 22
        photo.accessibilityElementsHidden = true
        configure(artistHeading, style: .subheadline, weight: .semibold)
        artistHeading.text = "About the artist"
        artistHeading.accessibilityTraits.insert(.header)
        configure(artistName, style: .title1, weight: .bold)
        artistCard.addArrangedSubview(artistHeading)
        artistCard.addArrangedSubview(artistName)
        artistCard.setCustomSpacing(4, after: artistHeading)
        photoRow.addSubview(photo)
        artistCard.addArrangedSubview(photoRow)
        photoRow.isHidden = true
        artistCard.addArrangedSubview(biography)
        configure(biography, style: .body)
        biographySource.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        biographySource.tintColor = UIColor.white.withAlphaComponent(0.82)
        biographySource.contentHorizontalAlignment = .leading
        biographySource.addAction(UIAction { [weak self] _ in
            if let url = self?.biographyURL { UIApplication.shared.open(url) }
        }, for: .touchUpInside)
        artistCard.addArrangedSubview(biographySource)
        var link = UIButton.Configuration.tinted()
        link.title = "Open artist page"
        link.image = UIImage(systemName: "chevron.right")
        link.imagePlacement = .trailing
        link.imagePadding = 7
        link.baseForegroundColor = .white
        link.baseBackgroundColor = UIColor.white.withAlphaComponent(0.45)
        link.cornerStyle = .capsule
        artistLink.configuration = link
        artistLink.contentHorizontalAlignment = .leading
        artistLink.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        artistLink.addAction(UIAction { [weak self] _ in self?.openArtist?() }, for: .touchUpInside)
        artistCard.addArrangedSubview(artistLink)
        creditsCard.addArrangedSubview(heading("Song credits"))
        credits.axis = .vertical
        credits.spacing = 12
        creditsCard.addArrangedSubview(credits)
        addSubview(stack)
        accessibilityIdentifier = "shrubify.player.details"
        isHidden = true
    }

    required init?(coder: NSCoder) { return nil }

    private func heading(_ text: String) -> UILabel {
        let label = UILabel()
        configure(label, style: .title2, weight: .bold)
        label.text = text
        label.accessibilityTraits.insert(.header)
        return label
    }

    private func configure(_ label: UILabel, style: UIFont.TextStyle, weight: UIFont.Weight = .regular) {
        let preferred = UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        label.font = UIFontMetrics(forTextStyle: style)
            .scaledFont(for: .systemFont(ofSize: preferred.pointSize, weight: weight))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.numberOfLines = 0
    }

    func setTrack(id: String, title: String, artist: String, album: String?, isrc: String?, artistURI: String?) {
        guard !id.isEmpty, !artist.isEmpty else { return }
        let nextPhotoID = PlayerArtistPhoto.artistID(from: artistURI)
        artistLink.isHidden = nextPhotoID == nil
        if photoID != nextPhotoID {
            photo.layer.removeAllAnimations()
            photo.image = nil
            photoID = nextPhotoID
            requestedPhotoID = nil
            reservesPhoto = photoID != nil
            photoRow.isHidden = !reservesPhoto
            onContentChange?()
        }
        guard id != self.id else {
            if let name = info?.artist, let native = EntityPageHeaderManager.cachedBioText(for: name), native != biography.text {
                biography.text = native
                biography.isHidden = false
                biographySource.isHidden = true
                biographyURL = nil
                onContentChange?()
            }
            return
        }
        self.id = id
        let primary = LyricsMatch.leadArtist(artist.components(separatedBy: ", ").first ?? artist)
        info = (title, primary, album, isrc)
        started = false
        isHidden = false
        artistName.text = primary
        setCredits(rows: [("Performed by", artist)])
        biography.text = EntityPageHeaderManager.cachedBioText(for: primary)
        biography.isHidden = biography.text == nil
        biographyURL = nil
        biographySource.isHidden = true
        onContentChange?()
    }

    func loadIfNeeded() {
        if let photoID, requestedPhotoID != photoID {
            requestedPhotoID = photoID
            PlayerArtistPhoto.load(id: photoID) { [weak self] image in
                guard let self, self.photoID == photoID else { return }
                reservesPhoto = image != nil
                photoRow.isHidden = !reservesPhoto
                photo.image = image
                if image != nil, !UIAccessibility.isReduceMotionEnabled {
                    photo.alpha = 0
                    UIView.animate(withDuration: 0.22) { self.photo.alpha = 1 }
                } else { photo.alpha = 1 }
                onContentChange?()
            }
        }
        guard !started, let info else { return }
        started = true
        let requestedTrack = id
        if biography.text == nil {
            biography.text = "Loading artist information…"
            biography.isHidden = false
            ArtistBioSource.exactWikipediaBio(for: info.artist) { [weak self] text, url in
                guard let self, id == requestedTrack else { return }
                let cached = EntityPageHeaderManager.cachedBioText(for: info.artist)
                biography.text = cached ?? text ?? "No biography available."
                biographyURL = cached == nil ? url : nil
                biographySource.setTitle("Wikipedia · CC BY-SA", for: .normal)
                biographySource.isHidden = biographyURL == nil
                onContentChange?()
            }
        }
        addCreditNote("Loading additional credits…")
        ArtistBioSource.musicBrainzCredits(isrc: info.isrc, title: info.title, artist: info.artist) { [weak self] result in
            guard let self, id == requestedTrack else { return }
            if let result { showCredits(result, source: "MusicBrainz"); return }
            ArtistBioSource.geniusCredits(title: info.title, artist: info.artist, album: info.album) { [weak self] alternative in
                guard let self, id == requestedTrack else { return }
                showCredits(alternative, source: "Genius")
            }
        }
        onContentChange?()
    }

    private func showCredits(_ result: ArtistBioSource.SongCredits?, source: String) {
        if let loading = credits.arrangedSubviews.last as? UILabel { loading.removeFromSuperview() }
        guard let result else {
            addCreditNote("Additional credits unavailable.")
            onContentChange?()
            return
        }
        if !result.writers.isEmpty { addCredit(role: "Written by", names: result.writers.joined(separator: ", ")) }
        if !result.producers.isEmpty { addCredit(role: "Produced by", names: result.producers.joined(separator: ", ")) }
        if !result.featured.isEmpty { addCredit(role: "Featuring", names: result.featured.joined(separator: ", ")) }
        addCreditNote("Additional credits from \(source)")
        onContentChange?()
    }

    private func setCredits(rows: [(String, String)]) {
        credits.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (role, names) in rows { addCredit(role: role, names: names) }
    }

    private func addCredit(role: String, names: String) {
        let roleLabel = UILabel()
        configure(roleLabel, style: .footnote, weight: .semibold)
        roleLabel.textColor = UIColor.white.withAlphaComponent(0.74)
        roleLabel.text = role
        let people = UILabel()
        configure(people, style: .body, weight: .medium)
        people.text = names
        let row = UIStackView(arrangedSubviews: [roleLabel, people])
        row.axis = .vertical
        row.spacing = 3
        credits.addArrangedSubview(row)
    }

    private func addCreditNote(_ text: String) {
        let label = UILabel()
        configure(label, style: .caption1)
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.text = text
        credits.addArrangedSubview(label)
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        guard !isHidden, width > 44 else { return 0 }
        let contentWidth = max(1, width - 32)
        artistName.preferredMaxLayoutWidth = contentWidth
        biography.preferredMaxLayoutWidth = contentWidth
        let imageSize = photo.image?.size ?? CGSize(width: 1, height: 1)
        let maximumHeight = min(216, contentWidth * 0.62)
        photoHeight.constant = reservesPhoto ? min(maximumHeight, contentWidth * imageSize.height / max(1, imageSize.width)) : 0
        return ceil(stack.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                                  withHorizontalFittingPriority: .required,
                                                  verticalFittingPriority: .fittingSizeLevel).height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.frame = bounds
        stack.layoutIfNeeded()
        guard let image = photo.image, image.size.height > 0 else { return }
        let width = min(photoRow.bounds.width, photoRow.bounds.height * image.size.width / image.size.height)
        photo.frame = CGRect(x: (photoRow.bounds.width - width) / 2, y: 0, width: width, height: photoRow.bounds.height)
    }

    private lazy var photoHeight: NSLayoutConstraint = {
        let constraint = photoRow.heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        return constraint
    }()
}

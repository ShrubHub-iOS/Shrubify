import UIKit

@MainActor
final class PlayerTrackDetailsView: UIView {
    private let stack = UIStackView()
    private let artistName = UILabel()
    private let biography = UILabel()
    private let biographySource = UIButton(type: .system)
    private let artistLink = UIButton(type: .system)
    private let performer = UILabel()
    private let credits = UILabel()
    private var id = ""
    private var info: (title: String, artist: String, album: String?, isrc: String?)?
    private var biographyURL: URL?
    private var started = false
    var onContentChange: (() -> Void)?
    var openArtist: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.spacing = 10
        stack.addArrangedSubview(heading("About the artist"))
        for label in [artistName, biography] { stack.addArrangedSubview(label) }
        configure(artistName, style: .title3)
        configure(biography, style: .body)
        biographySource.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        biographySource.tintColor = UIColor.white.withAlphaComponent(0.82)
        biographySource.contentHorizontalAlignment = .leading
        biographySource.addAction(UIAction { [weak self] _ in
            if let url = self?.biographyURL { UIApplication.shared.open(url) }
        }, for: .touchUpInside)
        stack.addArrangedSubview(biographySource)
        artistLink.setTitle("Open artist page", for: .normal)
        artistLink.tintColor = .white
        artistLink.contentHorizontalAlignment = .leading
        artistLink.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        artistLink.addAction(UIAction { [weak self] _ in self?.openArtist?() }, for: .touchUpInside)
        stack.addArrangedSubview(artistLink)
        let creditHeading = heading("Song credits")
        stack.addArrangedSubview(creditHeading)
        stack.setCustomSpacing(20, after: artistLink)
        for label in [performer, credits] {
            configure(label, style: .body)
            stack.addArrangedSubview(label)
        }
        addSubview(stack)
        backgroundColor = UIColor.black.withAlphaComponent(0.28)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        accessibilityIdentifier = "shrubify.player.details"
        isHidden = true
    }

    required init?(coder: NSCoder) { return nil }

    private func heading(_ text: String) -> UILabel {
        let label = UILabel()
        configure(label, style: .headline)
        label.text = text
        label.accessibilityTraits.insert(.header)
        return label
    }

    private func configure(_ label: UILabel, style: UIFont.TextStyle) {
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.numberOfLines = 0
    }

    func setTrack(id: String, title: String, artist: String, album: String?, isrc: String?, canOpenArtist: Bool) {
        guard !id.isEmpty, !artist.isEmpty else { return }
        artistLink.isHidden = !canOpenArtist
        guard id != self.id else { return }
        self.id = id
        let primary = LyricsMatch.leadArtist(artist.components(separatedBy: ", ").first ?? artist)
        info = (title, primary, album, isrc)
        started = false
        isHidden = false
        artistName.text = primary
        performer.text = "Performed by\n\(artist)"
        biography.text = EntityPageHeaderManager.cachedBioText(for: primary)
        biography.isHidden = biography.text == nil
        biographyURL = nil
        biographySource.isHidden = true
        credits.text = nil
        credits.isHidden = true
        onContentChange?()
    }

    func loadIfNeeded() {
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
        credits.isHidden = false
        credits.text = "Loading additional credits…"
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
        guard let result else {
            credits.text = "Additional credits unavailable."
            onContentChange?()
            return
        }
        var sections: [String] = []
        if !result.writers.isEmpty { sections.append("Written by\n" + result.writers.joined(separator: ", ")) }
        if !result.producers.isEmpty { sections.append("Produced by\n" + result.producers.joined(separator: ", ")) }
        if !result.featured.isEmpty { sections.append("Featuring\n" + result.featured.joined(separator: ", ")) }
        sections.append("Additional credits from \(source)")
        credits.text = sections.joined(separator: "\n\n")
        onContentChange?()
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        guard !isHidden, width > 44 else { return 0 }
        return ceil(stack.systemLayoutSizeFitting(CGSize(width: width - 36, height: 0),
                                                  withHorizontalFittingPriority: .required,
                                                  verticalFittingPriority: .fittingSizeLevel).height) + 36
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.frame = bounds.insetBy(dx: 18, dy: 18)
    }
}

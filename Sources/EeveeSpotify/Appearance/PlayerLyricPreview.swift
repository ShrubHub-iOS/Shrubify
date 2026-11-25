import UIKit

/// A fixed-height button for the live lyric. The line dissolves as a unit;
/// the changing emphasis is drawn independently without relaying out text.
@MainActor
final class PlayerLyricPreview: UIButton {
    private let content = UIView()
    private let line = UILabel()
    private let emphasis = UILabel()
    private var lyric: String?
    private var word: Range<String.Index>?
    private var timed = false
    var lyricFont = UIFont.systemFont(ofSize: 19, weight: .semibold) {
        didSet { renderLine(); renderEmphasis() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        content.isUserInteractionEnabled = false
        content.accessibilityElementsHidden = true
        addSubview(content)
        for label in [line, emphasis] {
            label.numberOfLines = 2
            label.lineBreakMode = .byTruncatingTail
            label.textAlignment = .natural
            content.addSubview(label)
        }
        emphasis.alpha = 0
        accessibilityHint = "Open full lyrics"
        accessibilityIdentifier = "shrubify.player.current-lyric"
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
        line.frame = content.bounds
        emphasis.frame = content.bounds
    }

    func display(_ text: String?, timed: Bool, word: Range<String.Index>? = nil,
                 opacity: CGFloat = 0, animated: Bool = true) {
        let canAnimate = animated && window != nil && !UIAccessibility.isReduceMotionEnabled
        let changedLine = text != lyric
        let changedWord = changedLine || self.word != word
        let changedTiming = self.timed != timed
        lyric = text
        self.timed = timed
        self.word = word
        if changedLine {
            accessibilityLabel = text
            isAccessibilityElement = text != nil
            isUserInteractionEnabled = text != nil
            if canAnimate {
                UIView.transition(with: line, duration: 0.22,
                                  options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction]) {
                    self.renderLine()
                }
            } else {
                line.layer.removeAllAnimations()
                renderLine()
            }
        } else if changedTiming { renderLine() }
        if changedWord { renderEmphasis() }
        let alpha = word == nil ? 0 : (UIAccessibility.isReduceMotionEnabled ? 1 : opacity)
        if emphasis.alpha != alpha { emphasis.alpha = alpha }
    }

    private func renderLine() {
        line.attributedText = lyric.map { NSAttributedString(string: $0, attributes: [
            .font: lyricFont, .foregroundColor: UIColor.white.withAlphaComponent(timed ? 0.76 : 0.94)
        ]) }
    }

    private func renderEmphasis() {
        guard let lyric, let word else { emphasis.attributedText = nil; return }
        let value = NSMutableAttributedString(string: lyric, attributes: [.font: lyricFont, .foregroundColor: UIColor.clear])
        value.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(word, in: lyric))
        emphasis.attributedText = value
    }
}

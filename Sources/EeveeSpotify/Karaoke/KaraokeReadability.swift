import Foundation

/// Artwork remains visible outside the reading panel. The second scrim is
/// confined to text, retaining AA contrast even with a completely white cover.
enum KaraokeReadability {
    static let backgroundDimOpacity = 0.52
    static let readingPanelOpacity = 0.68
    static let unsungTextOpacity = 0.90
}

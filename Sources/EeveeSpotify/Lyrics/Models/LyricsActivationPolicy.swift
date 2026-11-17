import Foundation

/// Lyrics transport must also run for real Premium users who disable account
/// patching, and for the explicit Apple Music experiment over Spotify lyrics.
enum LyricsActivationPolicy {
    static func shouldReplaceLyrics(replacementSelected: Bool, officialExperiment: Bool, disabled: Bool) -> Bool {
        !disabled && (replacementSelected || officialExperiment)
    }
}

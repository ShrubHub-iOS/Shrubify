import Foundation

/// Lyrics transport must also run for real Premium users who disable account
/// patching, and for the explicit Apple Music experiment over Spotify lyrics.
enum LyricsActivationPolicy {
    static func shouldCapturePlayer(replacingLyrics: Bool, stabilityMode: Bool) -> Bool {
        replacingLyrics || !stabilityMode
    }

    static func shouldHandleLyricsTraffic(replacementSelected: Bool, officialExperiment: Bool, disabled: Bool) -> Bool {
        disabled || shouldReplaceLyrics(replacementSelected: replacementSelected,
            officialExperiment: officialExperiment, disabled: disabled)
    }

    static func shouldReplaceLyrics(replacementSelected: Bool, officialExperiment: Bool, disabled: Bool) -> Bool {
        !disabled && (replacementSelected || officialExperiment)
    }
}

import Foundation

extension UserDefaults {
    static var shouldHandleLyricsTraffic: Bool {
        LyricsActivationPolicy.shouldHandleLyricsTraffic(
            replacementSelected: lyricsSource.isReplacingLyrics,
            officialExperiment: experimentsOptions.appleMusicOfficialTtml,
            disabled: NgzhwmSettingsViewModel.isLyricsFeatureDisabled)
    }

    static var shouldReplaceLyrics: Bool {
        LyricsActivationPolicy.shouldReplaceLyrics(
            replacementSelected: lyricsSource.isReplacingLyrics,
            officialExperiment: experimentsOptions.appleMusicOfficialTtml,
            disabled: NgzhwmSettingsViewModel.isLyricsFeatureDisabled)
    }
}

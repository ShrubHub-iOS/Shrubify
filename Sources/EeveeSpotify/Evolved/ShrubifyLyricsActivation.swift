import Foundation

extension UserDefaults {
    static var shouldReplaceLyrics: Bool {
        LyricsActivationPolicy.shouldReplaceLyrics(
            replacementSelected: lyricsSource.isReplacingLyrics,
            officialExperiment: experimentsOptions.appleMusicOfficialTtml,
            disabled: NgzhwmSettingsViewModel.isLyricsFeatureDisabled)
    }
}

import Foundation

extension UserDefaults {
    static var container: UserDefaults = .standard

    private static let musixmatchTokenKey = "musixmatchToken"
    private static let darkPopUpsKey = "darkPopUps"
    private static let debugLoggingEnabledKey = "debugLoggingEnabled"
    private static let patchTypeKey = "patchType"
    private static let trueShuffleEnabledKey = "trueShuffleEnabled"
    private static let overwriteConfigurationKey = "overwriteConfiguration"
    private static let lyricsColorsKey = "lyricsColors"
    private static let lyricsOptionsKey = "lyricsOptions"
    private static let hasShownCommonIssuesTipKey = "hasShownCommonIssuesTip"
    private static let hasPatchedBootstrapKey = "eeveeHasPatchedBootstrap"
    private static let cachedCustomizeDataKey = "eeveeCachedCustomizeData"
    private static let iconNamePrettifyKey = "iconNamePrettify"
    private static let cleanShareLinksKey = "cleanShareLinks"

    static var musixmatchToken: String {
        get {
            container.string(forKey: musixmatchTokenKey) ?? ""
        }
        set (token) {
            container.set(token, forKey: musixmatchTokenKey)
        }
    }

    static var darkPopUps: Bool {
        get {
            container.object(forKey: darkPopUpsKey) as? Bool ?? true
        }
        set (darkPopUps) {
            container.set(darkPopUps, forKey: darkPopUpsKey)
        }
    }

    static var debugLoggingEnabled: Bool {
        get {
            container.object(forKey: debugLoggingEnabledKey) as? Bool ?? false
        }
        set (debugLoggingEnabled) {
            container.set(debugLoggingEnabled, forKey: debugLoggingEnabledKey)
        }
    }

    static var patchType: EeveePatchType {
        get {
            if let rawValue = container.object(forKey: patchTypeKey) as? Int {
                return EeveePatchType(rawValue: rawValue) ?? .requests
            }

            // If the key is missing (fresh install / "reset data"), default to patching.
            // This avoids users silently falling back to Free tier.
            return .requests
        }
        set (patchType) {
            container.set(patchType.rawValue, forKey: patchTypeKey)
        }
    }

    static var trueShuffleEnabled: Bool {
        get {
            container.object(forKey: trueShuffleEnabledKey) as? Bool ?? false
        }
        set (isEnabled) {
            container.set(isEnabled, forKey: trueShuffleEnabledKey)
        }
    }

    static var overwriteConfiguration: Bool {
        get {
            container.bool(forKey: overwriteConfigurationKey)
        }
        set (overwriteConfiguration) {
            container.set(overwriteConfiguration, forKey: overwriteConfigurationKey)
        }
    }

    static var hasPatchedBootstrap: Bool {
        get { container.bool(forKey: hasPatchedBootstrapKey) }
        set { container.set(newValue, forKey: hasPatchedBootstrapKey) }
    }

    /// Persisted copy of the last patched customize response body. The in-memory
    /// cache in SpotifyResponsePatcher dies with the process, but Spotify
    /// re-fetches customize with ETag revalidation on every warm relaunch and
    /// gets a 304 with no body — without this persisted copy the tweak has
    /// nothing to replay and free-tier/ad flags re-enable mid-session.
    static var cachedCustomizeData: Data? {
        get { container.data(forKey: cachedCustomizeDataKey) }
        set {
            if let newValue {
                container.set(newValue, forKey: cachedCustomizeDataKey)
            } else {
                container.removeObject(forKey: cachedCustomizeDataKey)
            }
        }
    }

    static var hasShownCommonIssuesTip: Bool {
        get {
            container.bool(forKey: hasShownCommonIssuesTipKey)
        }
        set (hasShownCommonIssuesTip) {
            container.set(hasShownCommonIssuesTip, forKey: hasShownCommonIssuesTipKey)
        }
    }

    /// When true, icon names are prettified: underscores/hyphens become spaces,
    /// camelCase boundaries and numbers get spaces, and parentheses get a leading space.
    static var iconNamePrettify: Bool {
        get {
            container.object(forKey: iconNamePrettifyKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: iconNamePrettifyKey)
        }
    }

    /// When true, the `si` tracking parameter is stripped from shared Spotify links.
    static var cleanShareLinks: Bool {
        get {
            container.object(forKey: cleanShareLinksKey) as? Bool ?? false
        }
        set (cleanShareLinks) {
            container.set(cleanShareLinks, forKey: cleanShareLinksKey)
        }
    }

    static var roundedArtwork: Bool {
        get { container.bool(forKey: "eeveeRoundedArtwork") }
        set { container.set(newValue, forKey: "eeveeRoundedArtwork") }
    }
}

// Evolved UI and lyrics preferences (GPL-3.0).
extension UserDefaults {
    private static let lyricsAutoTranslateKey = "lyricsAutoTranslate"
    private static let enableLogRecordingKey = "enableLogRecording"
    private static let redactSharedLogKey = "redactSharedLog"
    private static let blockTelemetryKey = "blockTelemetry"
    private static let telemetryObserveOnlyKey = "telemetryObserveOnly"
    private static let telemetryExtraKeywordsKey = "telemetryExtraKeywords"
    private static let blockRatingPromptsKey = "blockRatingPrompts"
    private static let lockScreenArtworkEnabledKey = "lockScreenAnimatedArtwork"
    private static let lockScreenArtworkCanvasKey = "lockScreenAnimatedArtworkCanvas"
    private static let lockScreenArtworkFillKey = "lockScreenAnimatedArtworkFill"
    private static let lockScreenLyricsKey = "lockScreenLyrics"
    private static let sleepTimerMinutesKey = "sleepTimerMinutes"
    private static let hapticsEnabledKey = "hapticsEnabled"
    private static let hapticsStrengthKey = "hapticsStrength"
    private static let hapticsSurfaceKeywordsKey = "hapticsSurfaceKeywords"
    private static let hapticsLogControlsKey = "hapticsLogControls"
    private static let coverPulseEnabledKey = "coverPulseEnabled"
    private static let musicHapticsEnabledKey = "musicHapticsEnabled"
    private static let musicHapticsStrengthKey = "musicHapticsStrength"
    private static let headGestureControlsEnabledKey = "headGestureControlsEnabled"
    private static let dspEnabledKey = "dspEnabled"
    private static let dspPreampDbKey = "dspPreampDb"
    private static let dspBandGainsDbKey = "dspBandGainsDb"
    private static let dspPresetKey = "dspPreset"
    private static let dumpViewTreeKey = "dumpViewTree"
    private static let detailedLoggingKey = "detailedLogging"
    private static let hideMiniPlayerBarKey = "hideMiniPlayerBar"
    private static let hideSingalongLineKey = "hideSingalongLine"
    private static let hideNowPlayingPillsKey = "hideNowPlayingPills"
    private static let hideHomeHeaderKey = "hideHomeHeader"
    private static let hideConnectButtonKey = "hideConnectButton"
    private static let hideAddToButtonKey = "hideAddToButton"
    private static let blockedArtistsEnabledKey = "blockedArtistsEnabled"
    private static let blockedArtistsKey = "blockedArtists"
    private static let dumpCustomizeBodyKey = "dumpCustomizeBody"
    private static let libraryLargeTitleKey = "libraryLargeTitle"
    private static let homeLargeTitleKey = "homeLargeTitle"
    private static let tabBarSystemGlassKey = "tabBarSystemGlass"
    private static let tabBarHideLabelsKey = "tabBarHideLabels"
    private static let tabBarHideCreateKey = "tabBarHideCreate"
    private static let miniBarGlassKey = "miniBarGlass"
    private static let playlistSingleCoverKey = "playlistSingleCover"
    private static let nowPlayingLayoutKey = "nowPlayingLayout"
    private static let nowPlayingIOS27Key = "nowPlayingIOS27"
    private static let nowPlayingBackdropKey = "nowPlayingBackdrop"
    private static let nowPlayingOneScreenKey = "nowPlayingOneScreen"
    private static let nowPlayingLyricsInPlayerKey = "nowPlayingLyricsInPlayer"
    private static let nowPlayingLyricsExpandedKey = "nowPlayingLyricsExpanded"
    private static let entityPageDissolveKey = "entityPageDissolve"
    private static let entityPageHideChromeKey = "entityPageHideChrome"
    private static let amoledThemeKey = "amoledTheme"
    private static let accentColorRGBKey = "accentColorRGB"
    private static let entityPageAMHeaderKey = "entityPageAMHeader"
    private static let artistHideListenersKey = "artistHideListeners"
    private static let artistHideTabsKey = "artistHideTabs"
    private static let homeTileTintKey = "homeTileTint"
    private static let miniBarRoundArtworkKey = "miniBarRoundArtwork"
    private static let tabBarSystemGlassDefaultMigratedKey = "tabBarSystemGlassDefaultOn"
    private static let cachedCustomizeVersionKey = "eeveeCachedCustomizeVersion"

    static var enableLogRecording: Bool {
        get {
            container.bool(forKey: enableLogRecordingKey)
        }
        set {
            container.set(newValue, forKey: enableLogRecordingKey)
        }
    }
    static var redactSharedLog: Bool {
        get {
            container.object(forKey: redactSharedLogKey) == nil
                ? true
                : container.bool(forKey: redactSharedLogKey)
        }
        set {
            container.set(newValue, forKey: redactSharedLogKey)
        }
    }

    static var telemetryObserveOnly: Bool {
        get {
            container.object(forKey: telemetryObserveOnlyKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: telemetryObserveOnlyKey)
        }
    }
    static var telemetryExtraKeywords: String {
        get {
            container.string(forKey: telemetryExtraKeywordsKey) ?? ""
        }
        set {
            container.set(newValue, forKey: telemetryExtraKeywordsKey)
        }
    }
    static var lockScreenAnimatedArtwork: Bool {
        get {
            container.object(forKey: lockScreenArtworkEnabledKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: lockScreenArtworkEnabledKey)
        }
    }
    static var lockScreenAnimatedArtworkCanvas: Bool {
        get {
            container.object(forKey: lockScreenArtworkCanvasKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: lockScreenArtworkCanvasKey)
        }
    }
    static var lockScreenAnimatedArtworkFill: Bool {
        get {
            container.object(forKey: lockScreenArtworkFillKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: lockScreenArtworkFillKey)
        }
    }
    static var lockScreenLyrics: Bool {
        get {
            container.object(forKey: lockScreenLyricsKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: lockScreenLyricsKey)
        }
    }
    static var sleepTimerMinutes: Int {
        get {
            let stored = container.object(forKey: sleepTimerMinutesKey) as? Int ?? 0
            return stored > 0 ? stored : 30
        }
        set {
            container.set(newValue, forKey: sleepTimerMinutesKey)
        }
    }
    static var hapticsEnabled: Bool {
        get {
            container.object(forKey: hapticsEnabledKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: hapticsEnabledKey)
        }
    }
    static var hapticsStrength: Double {
        get {
            container.object(forKey: hapticsStrengthKey) as? Double ?? 0.6
        }
        set {
            container.set(newValue, forKey: hapticsStrengthKey)
        }
    }
    static var hapticsSurfaceKeywords: String {
        get {
            container.string(forKey: hapticsSurfaceKeywordsKey)
                ?? "player,nowplaying,now_playing,npv,transport,playback,scrubber,miniplayer"
        }
        set {
            container.set(newValue, forKey: hapticsSurfaceKeywordsKey)
        }
    }
    static var hapticsLogControls: Bool {
        get {
            container.object(forKey: hapticsLogControlsKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: hapticsLogControlsKey)
        }
    }
    static var coverPulseEnabled: Bool {
        get {
            container.object(forKey: coverPulseEnabledKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: coverPulseEnabledKey)
        }
    }
    static var musicHapticsEnabled: Bool {
        get {
            container.object(forKey: musicHapticsEnabledKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: musicHapticsEnabledKey)
        }
    }
    static var musicHapticsStrength: Int {
        get {
            let raw = container.object(forKey: musicHapticsStrengthKey) as? Int ?? 2
            return min(max(raw, 1), 3)
        }
        set {
            container.set(min(max(newValue, 1), 3), forKey: musicHapticsStrengthKey)
        }
    }
    static var headGestureControlsEnabled: Bool {
        get {
            container.object(forKey: headGestureControlsEnabledKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: headGestureControlsEnabledKey)
        }
    }
    static var dspEnabled: Bool {
        get {
            container.object(forKey: dspEnabledKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: dspEnabledKey)
        }
    }
    static var dspPreampDb: Double {
        get {
            let raw = container.object(forKey: dspPreampDbKey) as? Double ?? 0
            return min(max(raw, -12), 6)
        }
        set {
            container.set(min(max(newValue, -12), 6), forKey: dspPreampDbKey)
        }
    }
    static var dumpViewTree: Bool {
        get {
            container.object(forKey: dumpViewTreeKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: dumpViewTreeKey)
        }
    }
    static var amoledTheme: Bool {
        get {
            container.object(forKey: amoledThemeKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: amoledThemeKey)
        }
    }
    static var accentColorRGB: Int {
        get {
            container.object(forKey: accentColorRGBKey) as? Int ?? -1
        }
        set {
            if newValue < 0 {
                container.removeObject(forKey: accentColorRGBKey)
            } else {
                container.set(newValue, forKey: accentColorRGBKey)
            }
        }
    }
    static var entityPageAMHeader: Bool {
        get {
            container.object(forKey: entityPageAMHeaderKey) == nil
                ? true
                : container.bool(forKey: entityPageAMHeaderKey)
        }
        set {
            container.set(newValue, forKey: entityPageAMHeaderKey)
        }
    }
    static var artistHideListeners: Bool {
        get {
            container.object(forKey: artistHideListenersKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: artistHideListenersKey)
        }
    }
    static var artistHideTabs: Bool {
        get {
            container.object(forKey: artistHideTabsKey) == nil
                ? true
                : container.bool(forKey: artistHideTabsKey)
        }
        set {
            container.set(newValue, forKey: artistHideTabsKey)
        }
    }
    static var homeTileTint: Bool {
        get {
            container.object(forKey: homeTileTintKey) == nil
                ? true
                : container.bool(forKey: homeTileTintKey)
        }
        set {
            container.set(newValue, forKey: homeTileTintKey)
        }
    }
    static var miniBarRoundArtwork: Bool {
        get {
            container.object(forKey: miniBarRoundArtworkKey) == nil
                ? true
                : container.bool(forKey: miniBarRoundArtworkKey)
        }
        set {
            container.set(newValue, forKey: miniBarRoundArtworkKey)
        }
    }
    static var hideMiniPlayerBar: Bool {
        get {
            container.object(forKey: hideMiniPlayerBarKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: hideMiniPlayerBarKey)
        }
    }
    static var hideSingalongLine: Bool {
        get {
            container.object(forKey: hideSingalongLineKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: hideSingalongLineKey)
        }
    }
    static var hideNowPlayingPills: Bool {
        get {
            container.object(forKey: hideNowPlayingPillsKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: hideNowPlayingPillsKey)
        }
    }
    static var hideHomeHeader: Bool {
        get {
            container.object(forKey: hideHomeHeaderKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: hideHomeHeaderKey)
        }
    }
    static var hideConnectButton: Bool {
        get {
            container.object(forKey: hideConnectButtonKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: hideConnectButtonKey)
        }
    }
    static var hideAddToButton: Bool {
        get {
            container.object(forKey: hideAddToButtonKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: hideAddToButtonKey)
        }
    }
    static var blockedArtistsEnabled: Bool {
        get {
            container.object(forKey: blockedArtistsEnabledKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: blockedArtistsEnabledKey)
        }
    }
    static var blockedArtists: [String] {
        get {
            container.stringArray(forKey: blockedArtistsKey) ?? []
        }
        set {
            container.set(newValue, forKey: blockedArtistsKey)
        }
    }
    static var tabBarSystemGlass: Bool {
        get {
            container.object(forKey: tabBarSystemGlassKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: tabBarSystemGlassKey)
        }
    }
    static func applyTabBarSystemGlassDefaultIfNeeded() {
        guard container.object(forKey: tabBarSystemGlassDefaultMigratedKey) == nil else { return }
        container.set(true, forKey: tabBarSystemGlassDefaultMigratedKey)

        guard container.object(forKey: tabBarSystemGlassKey) as? Bool == false else { return }
        container.set(true, forKey: tabBarSystemGlassKey)
        writeDebugLog(
            "[TabBar] system glass default turned on once (the stored switch said off)"
                + " — from here on the switch in the extras settings decides"
        )
    }
    static var cachedCustomizeVersion: String? {
        get {
            container.string(forKey: cachedCustomizeVersionKey)
        }
        set {
            if let newValue {
                container.set(newValue, forKey: cachedCustomizeVersionKey)
            } else {
                container.removeObject(forKey: cachedCustomizeVersionKey)
            }
        }
    }
    static var tabBarHideLabels: Bool {
        get {
            container.object(forKey: tabBarHideLabelsKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: tabBarHideLabelsKey)
        }
    }
    static var tabBarHideCreate: Bool {
        get {
            container.object(forKey: tabBarHideCreateKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: tabBarHideCreateKey)
        }
    }
    static var miniBarGlass: Bool {
        get {
            container.object(forKey: miniBarGlassKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: miniBarGlassKey)
        }
    }
    static var playlistSingleCover: Bool {
        get {
            container.object(forKey: playlistSingleCoverKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: playlistSingleCoverKey)
        }
    }
    static var lyricsAutoTranslate: Bool {
        get {
            container.object(forKey: lyricsAutoTranslateKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: lyricsAutoTranslateKey)
        }
    }
    static var entityPageDissolve: Bool {
        get {
            container.object(forKey: entityPageDissolveKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: entityPageDissolveKey)
        }
    }
    static var entityPageHideChrome: Bool {
        get {
            container.object(forKey: entityPageHideChromeKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: entityPageHideChromeKey)
        }
    }
    static var nowPlayingLayout: Bool {
        get {
            container.object(forKey: nowPlayingLayoutKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: nowPlayingLayoutKey)
        }
    }
    static var nowPlayingIOS27: Bool {
        get {
            container.object(forKey: nowPlayingIOS27Key) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: nowPlayingIOS27Key)
        }
    }
    static var nowPlayingAnyLayout: Bool { nowPlayingLayout || nowPlayingIOS27 }
    static func normalizeNowPlayingLayoutKeys() -> Int {
        // 「沉浸式」删除后的存量收口：
        // · 选过它的人盘上是 `nowPlayingLayout = true`、`nowPlayingIOS27 = false` ⇒ 补上
        //   `.appleMusic`（他们的意图是"我要改过的听歌页"，不是"我要 Spotify 原样"）；
        // · **任何人**盘上的 `nowPlayingLayout` 都清成 false —— 旧那套「歌词进播放器」
        //   （`NowPlayingLyricsPlate.isEnabled`）读它，留着 true 会和 AM 档同时挂载。
        if nowPlayingLayout {
            nowPlayingLayout = false
            if !nowPlayingIOS27 {
                nowPlayingIOS27 = true
            }
        }

        // 两档布局共用这四颗结构键 ⇒ 归一到「任一布局开着」。
        let enabled = nowPlayingAnyLayout
        let keys = [
            nowPlayingBackdropKey,
            nowPlayingOneScreenKey,
            nowPlayingLyricsInPlayerKey,
            hideSingalongLineKey,
            hideNowPlayingPillsKey,
        ]

        var changed = 0
        for key in keys where (container.object(forKey: key) as? Bool) != enabled {
            container.set(enabled, forKey: key)
            changed += 1
        }

        guard changed > 0 else { return 0 }
        writeDebugLog(
            "[Layout] now-playing layout keys normalised to \(enabled ? "ON" : "OFF")"
                + " (\(changed) of \(keys.count) key(s) disagreed with the master switch)"
        )
        return changed
    }
    static var nowPlayingBackdrop: Bool {
        get {
            container.object(forKey: nowPlayingBackdropKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: nowPlayingBackdropKey)
        }
    }
    static var nowPlayingOneScreen: Bool {
        get {
            container.object(forKey: nowPlayingOneScreenKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: nowPlayingOneScreenKey)
        }
    }
    static var nowPlayingLyricsInPlayer: Bool {
        get {
            container.object(forKey: nowPlayingLyricsInPlayerKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: nowPlayingLyricsInPlayerKey)
        }
    }
    static var nowPlayingLyricsExpanded: Bool {
        get {
            container.object(forKey: nowPlayingLyricsExpandedKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: nowPlayingLyricsExpandedKey)
        }
    }
    static var detailedLogging: Bool {
        get {
            if let stored = container.object(forKey: detailedLoggingKey) as? Bool {
                return stored
            }
            return dumpViewTree || dumpCustomizeBody
        }
        set {
            container.set(newValue, forKey: detailedLoggingKey)
            container.set(newValue, forKey: dumpViewTreeKey)
            container.set(newValue, forKey: dumpCustomizeBodyKey)
        }
    }
    static var libraryLargeTitle: Bool {
        get {
            container.object(forKey: libraryLargeTitleKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: libraryLargeTitleKey)
        }
    }
    static var homeLargeTitle: Bool {
        get {
            container.object(forKey: homeLargeTitleKey) as? Bool ?? true
        }
        set {
            container.set(newValue, forKey: homeLargeTitleKey)
        }
    }
    static var dumpCustomizeBody: Bool {
        get {
            container.object(forKey: dumpCustomizeBodyKey) as? Bool ?? false
        }
        set {
            container.set(newValue, forKey: dumpCustomizeBodyKey)
        }
    }
}

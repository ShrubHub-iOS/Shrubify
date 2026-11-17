import Foundation

/// One-time migration: keep provider raw values, credentials and appearance colors.
/// Deprecated renderer archives remain stored but are never decoded or applied.
enum ShrubifyEvolvedMigration {
    static func apply(to defaults: UserDefaults = UserDefaults.container) {
        guard !defaults.bool(forKey: "ShrubifyEvolvedUI1") else { return }
        if defaults.object(forKey: "accentColorRGB") == nil,
           let accent = defaults.object(forKey: "eeveeAccent") as? Int {
            defaults.set(accent, forKey: "accentColorRGB")
        }
        if defaults.object(forKey: "amoledTheme") == nil {
            defaults.set(defaults.bool(forKey: "eeveeAmoled"), forKey: "amoledTheme")
        }
        // This migration deliberately selects the UI requested for this release.
        defaults.set(true, forKey: "nowPlayingIOS27")
        defaults.set(false, forKey: "nowPlayingLayout")
        defaults.set(true, forKey: "tabBarSystemGlass")
        defaults.set(true, forKey: "miniBarGlass")
        defaults.set(true, forKey: "entityPageAMHeader")
        defaults.set(true, forKey: "entityPageDissolve")
        defaults.set(true, forKey: "homeLargeTitle")
        defaults.set(true, forKey: "libraryLargeTitle")
        defaults.set(true, forKey: "ShrubifyEvolvedUI1")
    }
}


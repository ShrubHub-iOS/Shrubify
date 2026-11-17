// SPDX-License-Identifier: GPL-3.0-only
// UI/lyrics integration of zbzxbg/EeveeSpotifyEvolved revision 92d783486d527c20ccffb759de523d6c7b956547.
import Foundation
import SwiftUI
import UIKit
import Orion

func activateEvolvedInterface() {
    _ = UserDefaults.normalizeNowPlayingLayoutKeys()
    activateNewDesignYield()
    activateTabBarGlass()
    activateLibraryAppearance()
    activateHomeHeaderAppearance()
    activateDeclutterChrome()
    activatePlayerCardsDeclutter()
    activateNowPlayingControls()
    activateCoverFlashGuard()
    activateSpotifyURIOpener()
    activateEntityPageHeader()
    activateArtistBioTranslateGuard()
    activatePlayerMenuOffsetRow()
    activateHomeShortcutTiles()
    activateEntityPageRepaint()
    activateEntityPageStatusBar()
    activatePlaylistSingleCover()
    EntityPageAppearance.start()
}

/// Existing Shrubify pages remain reachable through the Evolved settings surface.
struct LiquidGlassSettingsView: View {
    var body: some View {
        List {
            Section(header: Text("Evolved UI"), footer: Text("Evolved’s player, tab bar, mini-player and page designs replace the previous glass renderer. System glass effects require iOS 26 or later.")) {
                SettingsLink(title: "Player design", icon: "play.rectangle", color: .blue) { NowPlayingSettingsView() }
                SettingsLink(title: "Tabs and mini-player", icon: "rectangle.bottomthird.inset.filled", color: .purple) { TabBarAndMiniBarSettingsView() }
                SettingsLink(title: "Home, library and pages", icon: "square.grid.2x2", color: .orange) { PagesAppearanceSettingsView() }
                SettingsLink(title: "Lyrics appearance", icon: "textformat.size", color: .green) { EeveeLyricsAppearanceSettingsView() }
                SettingsLink(title: "Open-source licenses", icon: "doc.text", color: .gray) { EeveeLicensesSettingsView() }
            }
        }
        .eeveeSettingsStyle()
    }
}

/// One-time migration: keep provider raw values, credentials and appearance colors.
/// Deprecated renderer archives remain stored but are never decoded or applied.
enum ShrubifyEvolvedMigration {
    static func apply() {
        let defaults = UserDefaults.container
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

extension UserDefaults {
    // Compatibility alias used by Shrubify's existing settings shell.
    static var accentRGB: Int {
        get { accentColorRGB }
        set { accentColorRGB = newValue }
    }
}

func spotifyAccessTokenSnapshot() -> String? { spotifyAccessToken }
func eeveeSanitizedNSLog(_ message: String) { NSLog("%@", DebugLogSanitizer.sanitize(message)) }
func writeErrorLog(_ message: String) { writeDebugLog("[ERROR] " + message) }

/// Evolved's player footer opens Shrubify's shared, idempotent sleep timer.
enum SleepTimerPanel {
    static func present() {
        WindowHelper.shared.present(UIHostingController(rootView: NavigationView { ShrubifySleepTimerView() }))
    }
}

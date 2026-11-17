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

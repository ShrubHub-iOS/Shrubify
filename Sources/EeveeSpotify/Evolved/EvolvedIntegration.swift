// SPDX-License-Identifier: GPL-3.0-only
// UI/lyrics integration of zbzxbg/EeveeSpotifyEvolved revision 92d783486d527c20ccffb759de523d6c7b956547.
import Foundation
import SwiftUI
import UIKit
import Orion
import ObjectiveC.runtime

struct PlayerAppearanceGroup: HookGroup {}

/// Preserve Spotify's tablet presentation and real controls during recovery.
enum EvolvedInterfaceAvailability {
    static var usesNativeTabletInterface: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    static var supportsCustomInterface: Bool { !usesNativeTabletInterface }
}

func activateEvolvedInterface() {
    _ = UserDefaults.normalizeNowPlayingLayoutKeys()
    activateSpotifyURIOpener()
    guard EvolvedInterfaceAvailability.supportsCustomInterface else {
        writeDebugLog("[Shrubify] iPad UI recovery: native player, navigation and page layouts; custom interface hooks skipped")
        return
    }
    if let controller = NSClassFromString("NowPlaying_ScrollImpl.NPVScrollViewController"),
       ["viewWillAppear:", "viewDidAppear:", "viewWillDisappear:"].allSatisfy({
           class_getInstanceMethod(controller, NSSelectorFromString($0)) != nil
       }) {
        PlayerAppearanceGroup().activate()
    }
    activateNewDesignYield()
    activateTabBarGlass()
    activateLibraryAppearance()
    activateHomeHeaderAppearance()
    activateDeclutterChrome()
    activatePlayerCardsDeclutter()
    activateNowPlayingControls()
    activateCoverFlashGuard()
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
            Section(header: Text("Evolved UI"), footer: Text("Custom interface effects require compatible Spotify layouts. System glass requires iOS 26 or later.")) {
                if EvolvedInterfaceAvailability.usesNativeTabletInterface {
                    Text("iPad compatibility recovery is active. Spotify handles its player, fullscreen presentation, navigation and page layouts. Expanded lyrics sources remain available.")
                        .font(.footnote)
                } else {
                    SettingsLink(title: "Player design", icon: "play.rectangle", color: .blue) { NowPlayingSettingsView() }
                    SettingsLink(title: "Tabs and mini-player", icon: "rectangle.bottomthird.inset.filled", color: .purple) { TabBarAndMiniBarSettingsView() }
                    SettingsLink(title: "Home, library and pages", icon: "square.grid.2x2", color: .orange) { PagesAppearanceSettingsView() }
                }
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
        weak var presented: UIViewController?
        let view = NavigationView {
            ShrubifySleepTimerView()
                .navigationBarItems(trailing: Button("Done") { presented?.dismiss(animated: true) })
        }.navigationViewStyle(StackNavigationViewStyle())
        let controller = UIHostingController(rootView: view)
        presented = controller
        controller.modalPresentationStyle = .pageSheet
        WindowHelper.shared.present(controller)
    }
}

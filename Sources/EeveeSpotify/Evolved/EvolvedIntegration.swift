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
    activateNativeTabletGlass()
    activateShrubifyGlassChrome()
    activateNativeTabletCanvasReadability()
    guard EvolvedInterfaceAvailability.supportsCustomInterface else {
        // Enable scoped cosmetic Home features, not the recovered controller replacements.
        activateHomeHeaderAppearance()
        activateHomeShortcutTiles()
        writeDebugLog("[Shrubify] iPad: native player and navigation; scoped Home appearance enabled")
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

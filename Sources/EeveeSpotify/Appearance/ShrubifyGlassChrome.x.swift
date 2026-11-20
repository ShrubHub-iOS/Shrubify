import UIKit
import Orion
import ObjectiveC.runtime

struct ShrubifyGlassChromeGroup: HookGroup {}

/// One hook on a class that always exists: the bars are discovered from the
/// window instead of from a Spotify class name that may be renamed, so this is
/// the only place bottom-bar glass can stop working by accident.
class ShrubifyGlassWindowHook: ClassHook<UIView> {
    typealias Group = ShrubifyGlassChromeGroup
    static let targetName = "UIWindow"

    func layoutSubviews() {
        orig.layoutSubviews()
        let window = target
        onMainThreadSync { ShrubifyGlassChrome.pass(in: window) }
    }
}

/// Separate group: the player row hook is probed before activation so a renamed
/// class only costs the accelerator, never the rest of the chrome.
struct ShrubifyGlassPlayerGroup: HookGroup {}

/// The player's own transport row. On iPad the custom-interface hooks are
/// skipped entirely, so this is the only place that can hand the chrome pass a
/// real player view instead of making it find one in the window.
class ShrubifyGlassPlayerHook: ClassHook<UIView> {
    typealias Group = ShrubifyGlassPlayerGroup
    static let targetName = "_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit"

    func layoutSubviews() {
        orig.layoutSubviews()
        let unit = target
        onMainThreadSync { ShrubifyGlassChrome.playerLayout(in: unit) }
    }
}

func activateShrubifyGlassChrome() {
    guard EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { ShrubifyGlassChrome.start() }
    ShrubifyGlassChromeGroup().activate()
    if NSClassFromString(ShrubifyGlassPlayerHook.targetName) != nil {
        ShrubifyGlassPlayerGroup().activate()
        writeDebugLog(
            "[GlassChrome] player row hook on \(ShrubifyGlassPlayerHook.targetName)"
                + " — glass behind the player card and every key"
        )
    } else {
        writeDebugLog(
            "[GlassChrome] \(ShrubifyGlassPlayerHook.targetName) missing"
                + " — the player is found by the window scan only"
        )
    }
}

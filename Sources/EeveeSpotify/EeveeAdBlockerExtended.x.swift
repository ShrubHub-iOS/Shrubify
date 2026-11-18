// TESTING: extended ad blocker for Swift Service-based ad surfaces
// (Evo home brand-ads, NPV under-player ad, in-stream audio, native ads).
// Hooks SPTService -load on each ad service and skips orig so the service
// stays inert. Per-surface bool flips below if one needs disabling.

import Orion
import Foundation
import UIKit
import ObjectiveC.runtime

// Every service has its own group. Spotify rolls these modules out
// independently, so one missing/renamed class must not disable the rest of the
// blocker on sideloaded/rootless builds either.
struct AdsServiceImplGroup: HookGroup {}
struct InStreamAdsServiceGroup: HookGroup {}
struct EmbeddedNPVServiceGroup: HookGroup {}
struct LeavebehindAdsBaseServiceGroup: HookGroup {}
struct LeavebehindAdsBaseInternalServiceGroup: HookGroup {}
struct SponsoredContextServiceGroup: HookGroup {}
struct SponsoredContextNPBAttachmentServiceGroup: HookGroup {}
struct SponsoredPlaylistHeaderServiceGroup: HookGroup {}
struct SponsoredPlaylistHeaderViewGroup: HookGroup {}
struct NativeAdsLoggerServiceGroup: HookGroup {}
struct EmbeddedAdAdapterViewGroup: HookGroup {}
struct EmbeddedAdProviderGroup: HookGroup {}
struct PlaylistAdControllerV2Group: HookGroup {}
struct PlaylistAdControllerImplGroup: HookGroup {}
struct LeavebehindAdElementProviderGroup: HookGroup {}
struct HtmlAdViewGroup: HookGroup {}
struct DSAAdViewGroup: HookGroup {}
struct ScrollFeedAdServiceGroup: HookGroup {}
struct ScrollFeedAdControllerGroup: HookGroup {}

private let killAdsServiceImpl         = true
private let killInStreamAdsService     = true
private let killEmbeddedNPVService     = true
private let killNativeAdsLoggerService = true
private let logAdBlockerEvents         = true

@inline(__always)
private func adlog(_ what: String) {
    if logAdBlockerEvents {
        writeDebugLog("[AdBlock] suppressed \(what)")
    }
}

// Activation diagnostics also go to the debug file — NSLog alone never
// reached the tester log and hid whether hooks actually attached.
private func ablog(_ message: String) {
    writeDebugLog("[AdBlock] \(message)")
}

// Swift classes register in the ObjC runtime lazily, so NSClassFromString at
// tweak-init time can miss classes that exist (build-3 tester log: every
// scroll-feed service kill skipped as "unavailable" while the ad rendered).
// Brute-force the registered class list as a fallback, cached after the first
// scan so every activation lookup shares one pass.
private var classListByNameCache: [String: AnyClass] = [:]
private var cachedClassCount: Int32 = 0
private let classListCacheLock = NSLock()

func findTweakClass(_ name: String) -> AnyClass? {
    if let cls = NSClassFromString(name) { return cls }
    classListCacheLock.lock()
    defer { classListCacheLock.unlock() }
    // objc_copyClassList returns AutoreleasingUnsafeMutablePointer; subscripting
    // triggers retain/autorelease msgSend which aborts on iOS 26+ (same trap as
    // EeveeProbes). objc_getClassList with a raw buffer sidesteps it.
    let total = objc_getClassList(nil, 0)
    guard total > 0 else { return nil }
    if total == cachedClassCount { return classListByNameCache[name] }
    let buf = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(total))
    defer { buf.deallocate() }
    let n = objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(buf), total)
    for i in 0..<Int(min(n, total)) {
        let raw = UnsafeRawPointer(buf).load(fromByteOffset: i * MemoryLayout<UnsafeRawPointer>.size,
                                              as: UnsafeRawPointer.self)
        let cls = unsafeBitCast(raw, to: AnyClass.self)
        classListByNameCache[String(cString: class_getName(cls))] = cls
    }
    cachedClassCount = total
    return classListByNameCache[name]
}

class AdsServiceImplKill: ClassHook<NSObject> {
    typealias Group = AdsServiceImplGroup
    static let targetName: String = "_TtC19AdsPlatform_AdsImpl14AdsServiceImpl"
    func load() {
        if killAdsServiceImpl { adlog("AdsServiceImpl.load"); return }
        orig.load()
    }
}

class InStreamAdsServiceKill: ClassHook<NSObject> {
    typealias Group = InStreamAdsServiceGroup
    static let targetName: String = "_TtC29AdsNowPlaying_InStreamAdsImpl18InStreamAdsService"
    func load() {
        if killInStreamAdsService { adlog("InStreamAdsService.load"); return }
        orig.load()
    }
}

class EmbeddedNPVServiceImplKill: ClassHook<NSObject> {
    typealias Group = EmbeddedNPVServiceGroup
    static let targetName: String = "_TtC29AdsNowPlaying_EmbeddedNPVImpl22EmbeddedNPVServiceImpl"
    func load() {
        if killEmbeddedNPVService { adlog("EmbeddedNPVServiceImpl.load"); return }
        orig.load()
    }
}

// Spotify 9.1.66+ can render the under-player card through a separate
// "unified leavebehind" pipeline. It does not depend on EmbeddedNPVServiceImpl.
class LeavebehindAdsBaseServiceKill: ClassHook<NSObject> {
    typealias Group = LeavebehindAdsBaseServiceGroup
    static let targetName: String =
        "_TtC36AdsStandalone_LeavebehindAdsBaseImpl25LeavebehindAdsBaseService"

    func load() {
        adlog("LeavebehindAdsBaseService.load")
        return
    }
}

class LeavebehindAdsBaseInternalServiceKill: ClassHook<NSObject> {
    typealias Group = LeavebehindAdsBaseInternalServiceGroup
    static let targetName: String =
        "_TtC36AdsStandalone_LeavebehindAdsBaseImpl33LeavebehindAdsBaseInternalService"

    func load() {
        adlog("LeavebehindAdsBaseInternalService.load")
        return
    }
}

// Native sponsored surfaces are separate from AdsServiceImpl in 9.1.x.
// Blocking their SPTService entry points keeps sponsored headers and the
// Now Playing Bar attachment from being constructed at all.
class SponsoredContextServiceKill: ClassHook<NSObject> {
    typealias Group = SponsoredContextServiceGroup
    static let targetName =
        "_TtC35AdsEmbedded_AdsSponsoredContextImpl30AdsSponsoredContextServiceImpl"

    func load() {
        adlog("AdsSponsoredContextServiceImpl.load")
        return
    }
}

class SponsoredContextNPBAttachmentServiceKill: ClassHook<NSObject> {
    typealias Group = SponsoredContextNPBAttachmentServiceGroup
    static let targetName =
        "_TtC48AdsEmbedded_AdsSponsoredContextNPBAttachmentImpl43AdsSponsoredContextNPBAttachmentServiceImpl"

    func load() {
        adlog("AdsSponsoredContextNPBAttachmentServiceImpl.load")
        return
    }
}

class SponsoredPlaylistHeaderServiceKill: ClassHook<NSObject> {
    typealias Group = SponsoredPlaylistHeaderServiceGroup
    static let targetName =
        "_TtC42AdsEmbedded_AdsSponsoredPlaylistHeaderImpl37AdsSponsoredPlaylistHeaderServiceImpl"

    func load() {
        adlog("AdsSponsoredPlaylistHeaderServiceImpl.load")
        return
    }
}

// Rendering fallback for a sponsored header that was already materialized
// before its service hook became active. Generic Spotify banners stay intact.
class SponsoredPlaylistHeaderViewKill: ClassHook<UIView> {
    typealias Group = SponsoredPlaylistHeaderViewGroup
    static let targetName =
        "_TtC18AdsPlatform_ECMKit37AdsSponsoredPlaylistHeaderCentralView"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        target.isHidden = true
        target.isUserInteractionEnabled = false
        if target.superview != nil {
            adlog("AdsSponsoredPlaylistHeaderCentralView")
            target.removeFromSuperview()
        }
    }
}

class NativeAdsLoggerServiceImplKill: ClassHook<NSObject> {
    typealias Group = NativeAdsLoggerServiceGroup
    static let targetName: String = "_TtC20NativeAds_LoggerImpl26NativeAdsLoggerServiceImpl"
    func load() {
        if killNativeAdsLoggerService { adlog("NativeAdsLoggerServiceImpl.load"); return }
        orig.load()
    }
}

// Now Playing scroll-feed ad card ("Montblanc Legend Elixir · Adverti…" in the
// scrollsita/NPV feed). The feed payload (spotify.scrollsita.v1.EmbeddedAd /
// ImageBrandAd) is rendered by EmbeddedAdAdapterElementUI, and
// EmbeddedCTAElementsServiceImpl provisions the embedded-CTA/ad adapter tree.
// Same hide-on-attach pattern as SponsoredPlaylistHeaderViewKill above.
class EmbeddedAdAdapterElementUIKill: ClassHook<NSObject> {
    typealias Group = EmbeddedAdAdapterViewGroup
    static let targetName =
        "_TtC35AdsEmbedded_EmbeddedCTAElementsImpl26EmbeddedAdAdapterElementUI"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("EmbeddedAdAdapterElementUI (scroll-feed ad card)")
            view.removeFromSuperview()
        }
    }
}

class EmbeddedCTAElementsServiceImplKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdServiceGroup
    static let targetName =
        "_TtC35AdsEmbedded_EmbeddedCTAElementsImpl30EmbeddedCTAElementsServiceImpl"

    func load() {
        adlog("EmbeddedCTAElementsServiceImpl.load")
    }
}

// Second scroll-feed pipeline: EmbeddedAdControllerServiceImpl wires the
// scrollsita EmbeddedAd/ImageBrandAd payloads into renderable ad elements.
// Starving it covers the case where the CTA service path is bypassed.
class EmbeddedAdControllerServiceImplKill: ClassHook<NSObject> {
    typealias Group = ScrollFeedAdControllerGroup
    static let targetName =
        "_TtC36AdsEmbedded_EmbeddedAdControllerImpl31EmbeddedAdControllerServiceImpl"

    func load() {
        adlog("EmbeddedAdControllerServiceImpl.load")
    }
}

// Broader embedded-ad pipeline kills (every name verified in the 9.1.84
// binary). The scroll card rendered despite the EmbeddedAdAdapterElementUI
// view kill, so the pipeline is starved one layer deeper and sibling render
// paths are covered too.
class EmbeddedAdAdapterElementProviderKill: ClassHook<NSObject> {
    typealias Group = EmbeddedAdProviderGroup
    static let targetName =
        "_TtC35AdsEmbedded_EmbeddedCTAElementsImpl32EmbeddedAdAdapterElementProvider"

    func load() {
        adlog("EmbeddedAdAdapterElementProvider.load")
    }
}

// Playlist-feed ad controllers (EmbeddedAd sections injected into playlist
// scroll contexts; sibling pipeline of the NPV scroll feed).
class PlaylistAdControllerV2Kill: ClassHook<NSObject> {
    typealias Group = PlaylistAdControllerV2Group
    static let targetName =
        "_TtC32AdsEmbedded_EmbeddedPlaylistImpl22PlaylistAdControllerV2"

    func load() {
        adlog("PlaylistAdControllerV2.load")
    }
}

class PlaylistAdControllerImplKill: ClassHook<NSObject> {
    typealias Group = PlaylistAdControllerImplGroup
    static let targetName =
        "_TtC32AdsEmbedded_EmbeddedPlaylistImpl24PlaylistAdControllerImpl"

    func load() {
        adlog("PlaylistAdControllerImpl.load")
    }
}

// Leavebehind ad elements under the player (EmbeddedAdPresentationKit).
class LeavebehindAdElementProviderKill: ClassHook<NSObject> {
    typealias Group = LeavebehindAdElementProviderGroup
    static let targetName =
        "_TtC37AdsEmbedded_EmbeddedAdPresentationKit28LeavebehindAdElementProvider"

    func load() {
        adlog("LeavebehindAdElementProvider.load")
    }
}

// HTML-backed brand-ad creative. NSObject-based with an internal cast:
// ElementUI classes have proven non-UIView on some 9.1.x builds.
class HtmlAdElementUIKill: ClassHook<NSObject> {
    typealias Group = HtmlAdViewGroup
    static let targetName =
        "_TtC22AdsPlatform_ElementKit15HtmlAdElementUI"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("HtmlAdElementUI")
            view.removeFromSuperview()
        }
    }
}

// DSA ad-transparency overlay (AdsPlatform_DSAImpl) — ad-only surface.
class DSAMainViewKill: ClassHook<NSObject> {
    typealias Group = DSAAdViewGroup
    static let targetName =
        "_TtC19AdsPlatform_DSAImpl11DSAMainView"

    func didMoveToSuperview() {
        orig.didMoveToSuperview()
        guard let view = target as? UIView else { return }
        view.isHidden = true
        view.isUserInteractionEnabled = false
        if view.superview != nil {
            adlog("DSAMainView")
            view.removeFromSuperview()
        }
    }
}

private var activatedAdTargets = Set<String>()
private var adActivationScheduled = false
private var adForegroundObserver: NSObjectProtocol?

private func activateAvailableAdHooks() {
    let targets: [(String, String, Bool, () -> Void)] = [
        (AdsServiceImplKill.targetName, "load", false, { AdsServiceImplGroup().activate() }),
        (InStreamAdsServiceKill.targetName, "load", false, { InStreamAdsServiceGroup().activate() }),
        (EmbeddedNPVServiceImplKill.targetName, "load", false, { EmbeddedNPVServiceGroup().activate() }),
        (LeavebehindAdsBaseServiceKill.targetName, "load", false, { LeavebehindAdsBaseServiceGroup().activate() }),
        (LeavebehindAdsBaseInternalServiceKill.targetName, "load", false, { LeavebehindAdsBaseInternalServiceGroup().activate() }),
        (SponsoredContextServiceKill.targetName, "load", false, { SponsoredContextServiceGroup().activate() }),
        (SponsoredContextNPBAttachmentServiceKill.targetName, "load", false, { SponsoredContextNPBAttachmentServiceGroup().activate() }),
        (SponsoredPlaylistHeaderServiceKill.targetName, "load", false, { SponsoredPlaylistHeaderServiceGroup().activate() }),
        (SponsoredPlaylistHeaderViewKill.targetName, "didMoveToSuperview", true, { SponsoredPlaylistHeaderViewGroup().activate() }),
        (NativeAdsLoggerServiceImplKill.targetName, "load", false, { NativeAdsLoggerServiceGroup().activate() }),
        (EmbeddedAdAdapterElementUIKill.targetName, "didMoveToSuperview", true, { EmbeddedAdAdapterViewGroup().activate() }),
        (EmbeddedCTAElementsServiceImplKill.targetName, "load", false, { ScrollFeedAdServiceGroup().activate() }),
        (EmbeddedAdControllerServiceImplKill.targetName, "load", false, { ScrollFeedAdControllerGroup().activate() }),
        (EmbeddedAdAdapterElementProviderKill.targetName, "load", false, { EmbeddedAdProviderGroup().activate() }),
        (PlaylistAdControllerV2Kill.targetName, "load", false, { PlaylistAdControllerV2Group().activate() }),
        (PlaylistAdControllerImplKill.targetName, "load", false, { PlaylistAdControllerImplGroup().activate() }),
        (LeavebehindAdElementProviderKill.targetName, "load", false, { LeavebehindAdElementProviderGroup().activate() }),
        (HtmlAdElementUIKill.targetName, "didMoveToSuperview", true, { HtmlAdViewGroup().activate() }),
        (DSAMainViewKill.targetName, "didMoveToSuperview", true, { DSAAdViewGroup().activate() }),
    ]
    for (className, selectorName, requiresView, activate) in targets {
        guard !activatedAdTargets.contains(className),
              let cls = findTweakClass(className), cls is NSObject.Type,
              !requiresView || cls is UIView.Type,
              let method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName)),
              method_getNumberOfArguments(method) == 2 else { continue }
        let returnType = method_copyReturnType(method)
        defer { free(returnType) }
        guard String(cString: returnType) == "v" else { continue }
        activatedAdTargets.insert(className)
        activate()
        ablog("\(className)/\(selectorName) hook activated")
    }
}

func activateEeveeAdBlockerExtended() {
    onMainThreadSync {
        guard !adActivationScheduled else { return }
        adActivationScheduled = true
        activateAvailableAdHooks()
        // Swift ad modules may register after tweak initialization. Retry only
        // at bounded startup intervals and foreground, never hook a class twice.
        for delay in [0.25, 1.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { activateAvailableAdHooks() }
        }
        adForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in activateAvailableAdHooks() }
    }
}

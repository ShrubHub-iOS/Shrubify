import Foundation

// Shared by SPTDataLoaderServiceHook and HttpClientURLSessionHook. Lyrics is
// kept in each caller because its async fetch doesn't fit a sync transform.
enum SpotifyResponsePatcher {

    private static let lock = NSLock()
    private static var customize: Data?
    private static var customizeToken: String?

    // Reuse only within this process and bearer-token context. Old persisted
    // configuration can describe another account, Spotify build or tab registry.
    static var cachedCustomizeData: Data? {
        get {
            let token = spotifyAccessToken
            lock.lock(); defer { lock.unlock() }
            return token != nil && token == customizeToken ? customize : nil
        }
        set {
            let token = spotifyAccessToken
            lock.lock(); defer { lock.unlock() }
            customize = newValue
            customizeToken = token
        }
    }

    static func shouldBlock(_ url: URL) -> Bool {
        let elapsed = Date().timeIntervalSince(tweakInitTime)
        let path = url.path.lowercased()

        if url.isDeleteToken || url.isSessionInvalidation
            || path.contains("session/purge") || path.contains("token/revoke")
            || url.isAdRelated {
            return true
        }
        if path.contains("/dac/view/v1/") { return true }
        // Required signup, access-point lookup and configuration requests must
        // keep working regardless of how long the user has had the app open.
        if elapsed > 30 {
            return url.isOndemandSelector || url.isTrialsFacade || url.isPremiumMarketing
                || url.isPendragonFetchMessageList
        }
        return false
    }

    // Customize policy shared by shouldBlock/shouldModify. We do NOT blanket-block
    // customize: when the cache is cold there is nothing to replay, and serving an
    // empty body re-enables free-tier flags (crash/ad recurrence). Instead we let
    // the request through to a real 200 (patched on arrival), or synthesize a 200
    // from cache for 304s — see the URLSession hooks.
    static func shouldHandleCustomize(_ url: URL) -> Bool {
        url.isCustomize && UserDefaults.patchType.isPatching
    }

    static func shouldModify(_ url: URL) -> Bool {
        let shouldPatchPremium = BasePremiumPatchingGroup.isActive || PremiumBootstrapGroup.isActive
        let shouldReplaceLyrics = BaseLyricsGroup.isActive
        let isDAC = url.path.lowercased().contains("/dac/view/v1/")

        return (shouldReplaceLyrics && UserDefaults.lyricsSource.isReplacingLyrics && url.isLyrics)
            || (shouldPatchPremium && (
                url.isBootstrap || url.isCustomize ||
                url.isPremiumPlanRow || url.isPremiumBadge || url.isPlanOverview ||
                isDAC
            ))
            || BrowsitaSectionStripper.shouldHandle(url)
    }

    static func blockedResponseData(for url: URL) -> Data {
        if url.isAccountValidate {
            return #"{"status":1,"country":"US","is_country_launched":true}"#.data(using: .utf8)!
        }
        if url.isTrialsFacade {
            return #"{"result":"NOT_ELIGIBLE"}"#.data(using: .utf8)!
        }
        if url.isPremiumMarketing {
            return #"{}"#.data(using: .utf8)!
        }
        if url.isSessionInvalidation
            || url.path.contains("session/purge")
            || url.path.contains("token/revoke")
            || url.path.contains("signup/public")
            || url.path.contains("apresolve") {
            // Logout daemons parse the body; synthetic OK keeps them off the
            // actual logout codepath.
            return #"{"status":"OK"}"#.data(using: .utf8)!
        }
        if url.path.contains("pses/screenconfig") {
            return #"{}"#.data(using: .utf8)!
        }
        if shouldHandleCustomize(url), let cached = cachedCustomizeData {
            return cached
        }
        return Data()
    }

    enum PatchTag: String {
        case bootstrap   = "bootstrap"
        case customize   = "customize"
        case planRow     = "PremiumPlanRow"
        case planBadge   = "YourPremiumBadge"
        case planOverview = "PlanOverview"
        case dacEmpty    = "dac"
        case casitaStrip = "casitaStrip"
    }

    struct PatchResult {
        let data: Data
        let tag: PatchTag
    }

    static func patch(url: URL, buffer: Data) throws -> PatchResult? {
        if url.isPremiumPlanRow {
            return PatchResult(
                data: try getPremiumPlanRowData(
                    originalPremiumPlanRow: try PremiumPlanRow(serializedBytes: buffer)
                ),
                tag: .planRow
            )
        }
        if url.isPremiumBadge {
            return PatchResult(data: try getPremiumPlanBadge(), tag: .planBadge)
        }
        if url.isBootstrap {
            var msg = try BootstrapMessage(serializedBytes: buffer)
            UserDefaults.hasPatchedBootstrap = true
            if UserDefaults.patchType == .requests {
                modifyRemoteConfiguration(&msg.ucsResponse)
            }
            return PatchResult(data: try msg.serializedBytes(), tag: .bootstrap)
        }
        if url.isCustomize {
            var msg = try CustomizeMessage(serializedBytes: buffer)
            modifyRemoteConfiguration(&msg.response)
            let data = try msg.serializedData()
            cachedCustomizeData = data
            return PatchResult(data: data, tag: .customize)
        }
        if url.isPlanOverview {
            return PatchResult(data: try getPlanOverviewData(), tag: .planOverview)
        }
        if url.path.lowercased().contains("/dac/view/v1/") {
            // Empty body = "no ad to render" to the DAC consumer.
            return PatchResult(data: Data(), tag: .dacEmpty)
        }
        if BrowsitaSectionStripper.shouldHandle(url) {
            if let stripped = BrowsitaSectionStripper.strip(buffer, url: url) {
                return PatchResult(data: stripped, tag: .casitaStrip)
            }
            // Ad survived in a feed we parse but found no marker in — visible
            // only via this log. Testers hitting ads can now hand us the exact
            // feed + payload size to dig new markers out of.
            writeDebugLog("[STRIP] no-match \(url.path) size=\(buffer.count)")
            return nil
        }
        return nil
    }
}

import Foundation
import ObjectiveC
import EeveeSpotifyC

final class SponsorBlockSkipper {
    static let shared = SponsorBlockSkipper()

    private let queue = DispatchQueue(label: "com.eevee.sponsorblock.skipper")

    init() {
        NotificationCenter.default.addObserver(
            forName: SponsorBlockMySubmissionsStore.changedNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleLocalSubmissionsChanged()
        }
    }

    private func handleLocalSubmissionsChanged() {
        queue.async {
            guard let episodeID = self.currentEpisodeID else { return }
            let serverOnly = self.currentSegments.filter { !SponsorBlockLocalSegment.isLocalUUID($0.uuid) }
            self.currentSegments = self.mergeWithLocal(serverSegs: serverOnly, episodeID: episodeID)
            self.broadcastSegments()
            if self.lastIsPlaying, !self.currentSegments.isEmpty { self.startPolling() }
        }
    }

    private func mergeWithLocal(serverSegs: [SponsorBlockSegment], episodeID: String) -> [SponsorBlockSegment] {
        let local = SponsorBlockMySubmissionsStore.segments(for: episodeID)
        guard !local.isEmpty else { return serverSegs.sorted { $0.start < $1.start } }
        var merged = serverSegs
        for ls in local {
            let dup = serverSegs.contains { seg in
                let overlap = max(0, min(seg.end, ls.end) - max(seg.start, ls.start))
                let union = max(seg.end, ls.end) - min(seg.start, ls.start)
                return union > 0 && overlap / union >= 0.8
            }
            if dup {
                writeDebugLog("[SB] local seg \(ls.start)..\(ls.end) dup with API — using API")
                continue
            }
            merged.append(ls.asSegment)
        }
        return merged.sorted { $0.start < $1.start }
    }
    private var currentEpisodeID: String?
    private var currentSegments: [SponsorBlockSegment] = []
    private var fetchInFlight = false
    private var fetchGeneration = UUID()
    private var playbackGeneration = UUID()
    private var emptyEpisodeIDs: Set<String> = []
    private var lastSeekMonotonicMs: UInt64 = 0
    private var probedURIs: Set<String> = []

    private var lastPosition: Double = 0
    private var lastPositionStamp: TimeInterval = 0
    private var lastPlaybackSpeed: Double = 1.0
    private var lastIsPlaying: Bool = false
    private var lastDuration: Double = 0
    private weak var lastPlayer: AnyObject?

    static let segmentsChangedNotification = Notification.Name("EeveeSponsorBlockSegmentsChanged")

    func snapshot() -> (segments: [SponsorBlockSegment], duration: Double, episodeID: String?) {
        queue.sync { (currentSegments, lastDuration, currentEpisodeID) }
    }

    func currentPlayhead() -> (position: Double, duration: Double, episodeID: String?, isPlaying: Bool) {
        queue.sync {
            let elapsed = (lastPositionStamp == 0) ? 0 : (uptimeSec() - lastPositionStamp)
            let est = lastIsPlaying
                ? lastPosition + elapsed * lastPlaybackSpeed
                : lastPosition
            return (est, lastDuration, currentEpisodeID, lastIsPlaying)
        }
    }

    func segment(withUUID uuid: String) -> SponsorBlockSegment? {
        queue.sync { currentSegments.first { $0.uuid == uuid } }
    }

    @discardableResult
    func seekTo(seconds: Double) -> Bool {
        var ok = false
        queue.sync {
            guard let player = lastPlayer else { return }
            let target = max(0, seconds)
            preSeekPosition = lastPosition
            pendingSeekTarget = target
            pendingSeekDeadline = uptimeSec() + 2.5
            dismissedUUIDs.removeAll()
            playthroughAllowed.removeAll()
            guard seek(player: player, toSeconds: target) else { pendingSeekTarget = nil; preSeekPosition = nil; return }
            lastPosition = target
            lastPositionStamp = uptimeSec()
            writeDebugLog("[SB] user-initiated seek -> \(fmt(target))s")
            ok = true
        }
        return ok
    }

    private var pendingSeekTarget: Double?
    private var pendingSeekDeadline: TimeInterval = 0
    // Pre-seek pos: lets us recognize Spotify's stale callback fired before our seek lands.
    private var preSeekPosition: Double?
    private var dismissedUUIDs: Set<String> = []
    private var promptedUUIDs: Set<String> = []
    // UUIDs that should be allowed to play through unconditionally — populated by Undo.
    // Cleared on (a) natural exit past seg.end, (b) any manualSeek, (c) episode change.
    private var playthroughAllowed: Set<String> = []

    private var pollTimer: DispatchSourceTimer?
    private var seekSelectorCached: Selector?

    func processStateChange(player: AnyObject, state: AnyObject) {
        let options = UserDefaults.sponsorBlockOptions
        guard options.enabled else { optionsChanged(); return }
        guard let facts = ShrubPlaybackFacts(state) as? [String: Any],
              let uriString = facts["uri"] as? String else { return }
        let trackObj: AnyObject? = nil
        let isPodcastFlag = safeBool(trackObj, "isPodcast") ?? false
        let isVideoFlag   = safeBool(trackObj, "isVideo") ?? false

        if options.verboseLogging, !uriString.isEmpty {
            queue.async {
                if self.probedURIs.insert(uriString).inserted {
                    self.dumpTrackProbe(trackObj: trackObj, uri: uriString,
                                         isPodcast: isPodcastFlag, isVideo: isVideoFlag)
                }
            }
        }

        // URI-based detection — `isPodcast` flag flips off for some
        // video podcasts even though they have spotify:episode: URIs.
        let isEpisodeURI = uriString.hasPrefix("spotify:episode:") || uriString.contains("/episode/")
        guard isEpisodeURI, let episodeID = extractEpisodeID(fromURI: uriString) else {
            queue.async {
                // Stop the timer immediately before clearing state, so that
                // any in-flight poll tick sees empty segments and cannot seek a music track.
                self.stopPolling()
                let wasActive = (self.currentEpisodeID != nil) || !self.currentSegments.isEmpty
                if wasActive {
                    writeDebugLog("[SB] track changed away (isPodcastFlag=\(isPodcastFlag ? "Y" : "N") isVideoFlag=\(isVideoFlag ? "Y" : "N") uri=\(uriString.isEmpty ? "<nil>" : uriString)) — clearing")
                    self.currentEpisodeID = nil
                    self.currentSegments = []
                    self.dismissedUUIDs.removeAll()
                    self.promptedUUIDs.removeAll()
                    self.lastDuration = 0
                    self.lastIsPlaying = false
                    self.pendingSeekTarget = nil
                    self.preSeekPosition = nil
                    // Clear cached seek selector so it cannot be reused on a non-episode track.
                    self.seekSelectorCached = nil
                    self.broadcastSegments()
                }
            }
            return
        }
        if !isPodcastFlag && options.verboseLogging {
            writeDebugLog("[SB] note: isPodcast=N but URI is episode — proceeding (uri=\(uriString) isVideo=\(isVideoFlag ? "Y" : "N"))")
        }

        // The validated state bridge exposes seconds. Track length is not a unit.
        guard let positionRaw = (facts["position"] as? NSNumber)?.doubleValue,
              positionRaw.isFinite, positionRaw >= 0 else { return }
        let durationRaw = (facts["duration"] as? NSNumber)?.doubleValue ?? 0
        let playbackSpeed = (facts["speed"] as? NSNumber)?.doubleValue ?? 1
        let isPlaying = !((facts["paused"] as? NSNumber)?.boolValue ?? true)
        let positionSec = positionRaw

        queue.async {
            self.lastPlayer = player
            let now = self.uptimeSec()
            let firstStateForEpisode = (episodeID != self.currentEpisodeID) || (self.lastPositionStamp == 0)
            let expected = self.lastPosition + (now - self.lastPositionStamp) * self.lastPlaybackSpeed
            let delta = positionSec - expected
            let isOwnSeek: Bool = {
                guard let target = self.pendingSeekTarget else { return false }
                if now > self.pendingSeekDeadline { return false }
                return abs(positionSec - target) < 1.5
            }()
            // Stale callback: pos matches where we WERE, not the target. User manualSeek differs from both.
            let isStaleSeekCallback: Bool = {
                guard let pre = self.preSeekPosition,
                      let _ = self.pendingSeekTarget,
                      now <= self.pendingSeekDeadline else { return false }
                return abs(positionSec - pre) < 1.0
            }()

            var classification = "tick"
            if firstStateForEpisode { classification = "first" }
            else if isOwnSeek { classification = "ownSeek"; self.pendingSeekTarget = nil; self.preSeekPosition = nil }
            else if isStaleSeekCallback { classification = "stale" }
            else if abs(delta) > 2.0 { classification = "manualSeek" }

            if classification == "manualSeek" || classification == "first" {
                writeDebugLog("[SB] state ep=\(episodeID) pos=\(fmt(positionSec)) playing=\(isPlaying ? "Y" : "N") delta=\(fmtSigned(delta)) -> \(classification)")
            }

            if classification == "manualSeek" {
                if !self.playthroughAllowed.isEmpty {
                    writeDebugLog("[SB] manual seek — clearing playthroughAllowed (\(self.playthroughAllowed.count))")
                    self.playthroughAllowed.removeAll()
                }
                if self.lastIsPlaying && options.respectManualSeek {
                    for seg in self.currentSegments
                    where positionSec >= seg.start && positionSec < seg.end {
                        if self.dismissedUUIDs.insert(seg.uuid).inserted {
                            writeDebugLog("[SB] manual seek into \(seg.category) \(fmt(seg.start))..\(fmt(seg.end)) at \(fmt(positionSec)) — dismissed")
                        }
                    }
                }
            }

            if classification != "stale" {
                self.lastPosition = positionSec
                self.lastPositionStamp = now
            }
            self.lastPlaybackSpeed = playbackSpeed > 0 ? playbackSpeed : 1.0
            self.lastIsPlaying = isPlaying
            let normalizedDuration = durationRaw.isFinite ? max(0, durationRaw) : 0
            if abs(normalizedDuration - self.lastDuration) > 0.5 {
                self.lastDuration = normalizedDuration
                self.broadcastSegments()
            }

            if episodeID != self.currentEpisodeID {
                SponsorBlockToast.shared.dismissNow()
                self.fetchGeneration = UUID()
                self.playbackGeneration = UUID()
                self.currentEpisodeID = episodeID
                self.currentSegments = self.mergeWithLocal(serverSegs: [], episodeID: episodeID)
                self.dismissedUUIDs.removeAll()
                self.promptedUUIDs.removeAll()
                self.playthroughAllowed.removeAll()
                self.pendingSeekTarget = nil
                self.preSeekPosition = nil
                self.fetchInFlight = false
                self.broadcastSegments()
                writeDebugLog("[SB] new episode \(episodeID) (preloaded \(self.currentSegments.count) local)")
                self.fetchSegments(for: episodeID, options: options)
            } else if self.currentSegments.isEmpty
                      && !self.fetchInFlight
                      && !self.emptyEpisodeIDs.contains(episodeID) {
                self.fetchSegments(for: episodeID, options: options)
            }

            if isPlaying && !self.currentSegments.isEmpty {
                self.startPolling()
            } else {
                self.stopPolling()
            }

            if classification != "stale",
               !(classification == "manualSeek" && options.respectManualSeek) {
                self.checkAndSkip(reportedPosition: positionSec, options: options)
            }
        }
    }

    private func startPolling() {
        if pollTimer != nil { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.lastIsPlaying else { return }
            let elapsed = self.uptimeSec() - self.lastPositionStamp
            let est = self.lastPosition + elapsed * self.lastPlaybackSpeed
            self.checkAndSkip(reportedPosition: est, options: UserDefaults.sponsorBlockOptions)
        }
        t.resume()
        pollTimer = t
        writeDebugLog("[SB] polling started")
    }

    private func stopPolling() {
        if let t = pollTimer {
            t.cancel()
            pollTimer = nil
            writeDebugLog("[SB] polling stopped")
        }
    }

    private func checkAndSkip(reportedPosition pos: Double, options: SponsorBlockOptions) {
        guard options.enabled else { resetState(); return }
        guard lastIsPlaying else { return }
        guard !currentSegments.isEmpty else { return }
        // Safety guard: never seek if we are not on an episode track.
        guard currentEpisodeID != nil else { return }

        if !playthroughAllowed.isEmpty {
            playthroughAllowed = playthroughAllowed.filter { uuid in
                guard let seg = currentSegments.first(where: { $0.uuid == uuid }) else { return false }
                let stillRelevant = pos < seg.end
                if !stillRelevant {
                    writeDebugLog("[SB] playthrough done for \(seg.category) (pos=\(fmt(pos)) past end=\(fmt(seg.end)))")
                }
                return stillRelevant
            }
        }

        for seg in currentSegments {
            guard seg.isSkip else { continue }
            guard seg.duration >= options.minSegmentDuration else { continue }
            let action = options.action(for: seg.category)
            guard action == .autoSkip || action == .manualSkip else { continue }
            guard !options.respectManualSeek || !dismissedUUIDs.contains(seg.uuid) else { continue }
            guard !playthroughAllowed.contains(seg.uuid) else { continue }
            guard !SponsorBlockHiddenStore.contains(seg.uuid) else { continue }
            if SponsorBlockLocalSegment.isLocalUUID(seg.uuid) {
                guard options.autoSkipMySubmissions else { continue }
            }
            guard pos >= seg.start, pos < (seg.end - 0.25) else { continue }

            if action == .manualSkip {
                promptManualSkip(seg: seg, options: options)
                continue
            }

            // 1.2s cooldown: estimated-position polling can fire twice before
            // the real player tick lands, causing a double-seek.
            let nowMs = monotonicMs()
            if nowMs - lastSeekMonotonicMs < 1200 { return }
            lastSeekMonotonicMs = nowMs

            let targetSec = seg.end + 0.05
            writeDebugLog("[SB] skip cat=\(seg.category) pos=\(fmt(pos)) range=\(fmt(seg.start))..\(fmt(seg.end)) -> \(fmt(targetSec))s")
            if options.logOnly {
                writeDebugLog("[SB] logOnly=true — not seeking")
                return
            }
            guard let player = lastPlayer else {
                writeDebugLog("[SB] no player ref")
                return
            }
            preSeekPosition = lastPosition
            pendingSeekTarget = targetSec
            pendingSeekDeadline = uptimeSec() + 2.5
            guard seek(player: player, toSeconds: targetSec) else { pendingSeekTarget = nil; preSeekPosition = nil; return }
            lastPosition = targetSec
            lastPositionStamp = uptimeSec()
            if options.showToast {
                let segCapture = seg
                let episode = currentEpisodeID
                let generation = playbackGeneration
                SponsorBlockReportingUI.presentSkipFeedback(segment: segCapture) { [weak self] in
                    self?.undoSkip(seg: segCapture, episode: episode, generation: generation)
                }
            }
            return
        }
    }

    private func undoSkip(seg: SponsorBlockSegment, episode: String?, generation: UUID) {
        queue.async {
            guard UserDefaults.sponsorBlockOptions.enabled,
                  self.currentEpisodeID == episode, self.playbackGeneration == generation,
                  self.currentSegments.contains(where: { $0.uuid == seg.uuid }),
                  let player = self.lastPlayer else { return }
            let target = max(0, seg.start - 0.25)
            self.preSeekPosition = self.lastPosition
            self.pendingSeekTarget = target
            self.pendingSeekDeadline = self.uptimeSec() + 2.5
            self.playthroughAllowed.insert(seg.uuid)
            guard self.seek(player: player, toSeconds: target) else { self.pendingSeekTarget = nil; self.preSeekPosition = nil; return }
            self.lastPosition = target
            self.lastPositionStamp = self.uptimeSec()
            writeDebugLog("[SB] undo skip cat=\(seg.category) -> \(fmt(target))s, playthrough=\(seg.uuid)")
        }
    }

    private func promptManualSkip(seg: SponsorBlockSegment, options: SponsorBlockOptions) {
        guard !promptedUUIDs.contains(seg.uuid) else { return }
        promptedUUIDs.insert(seg.uuid)
        let title = "\(SponsorBlockFormatters.categoryShortName(seg.category)) (\(Int(seg.duration))s)"
        let episode = currentEpisodeID
        let generation = playbackGeneration
        SponsorBlockToast.shared.showAction(message: title, actionTitle: "Skip") { [weak self] in
            self?.queue.async {
                guard let self else { return }
                guard UserDefaults.sponsorBlockOptions.enabled,
                      self.currentEpisodeID == episode, self.playbackGeneration == generation,
                      self.currentSegments.contains(where: { $0.uuid == seg.uuid }),
                      let player = self.lastPlayer else { return }
                let targetSec = seg.end + 0.05
                self.preSeekPosition = self.lastPosition
                self.pendingSeekTarget = targetSec
                self.pendingSeekDeadline = self.uptimeSec() + 2.5
                guard self.seek(player: player, toSeconds: targetSec) else { self.pendingSeekTarget = nil; self.preSeekPosition = nil; return }
                self.lastPosition = targetSec
                self.lastPositionStamp = self.uptimeSec()
                writeDebugLog("[SB] manual-skip accepted cat=\(seg.category) -> \(fmt(targetSec))s")
            }
        }
    }

    private func fetchSegments(for episodeID: String, options: SponsorBlockOptions) {
        guard !fetchInFlight else { return }
        fetchInFlight = true
        let requestGeneration = UUID()
        fetchGeneration = requestGeneration
        writeDebugLog("[SB] fetching segments for \(episodeID)")
        SponsorBlockAPI.fetchSegments(episodeID: episodeID, options: options) { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard self.fetchGeneration == requestGeneration,
                      episodeID == self.currentEpisodeID,
                      UserDefaults.sponsorBlockOptions.enabled else { return }
                self.fetchInFlight = false
                switch result {
                case .success(let segs):
                    let merged = self.mergeWithLocal(serverSegs: segs, episodeID: episodeID)
                    self.currentSegments = merged
                    self.broadcastSegments()
                    if merged.isEmpty {
                        if segs.isEmpty {
                            if self.emptyEpisodeIDs.count >= 256 { self.emptyEpisodeIDs.removeAll() }
                            self.emptyEpisodeIDs.insert(episodeID)
                            writeDebugLog("[SB] no segments for \(episodeID) (cached empty)")
                        }
                    } else {
                        writeDebugLog("[SB] got \(segs.count) API + \(merged.count - segs.count) local segments for \(episodeID)")
                        for s in merged {
                            let mark = SponsorBlockLocalSegment.isLocalUUID(s.uuid) ? " [local]" : ""
                            writeDebugLog("[SB]   - \(s.category) \(fmt(s.start))..\(fmt(s.end)) (\(fmt(s.duration))s)\(mark)")
                        }
                        if UserDefaults.sponsorBlockOptions.respectManualSeek {
                            let pos = self.lastPosition
                            for seg in merged
                            where pos >= seg.start && pos < seg.end {
                                self.dismissedUUIDs.insert(seg.uuid)
                                writeDebugLog("[SB] already inside \(seg.category) \(fmt(seg.start))..\(fmt(seg.end)) at load — dismissed")
                            }
                        }
                        if self.lastIsPlaying { self.startPolling() }
                    }
                case .failure(let err):
                    writeDebugLog("[SB] fetch failed: \(err); using local only")
                    let merged = self.mergeWithLocal(serverSegs: [], episodeID: episodeID)
                    if !merged.isEmpty {
                        self.currentSegments = merged
                        self.broadcastSegments()
                        if self.lastIsPlaying { self.startPolling() }
                    }
                }
            }
        }
    }

    private func seek(player: AnyObject, toSeconds seconds: Double) -> Bool {
        guard UserDefaults.sponsorBlockOptions.enabled,
              let episode = currentEpisodeID,
              let live = ShrubReadLivePlayback(player),
              let uri = live["uri"] as? String,
              extractEpisodeID(fromURI: uri) == episode else { return false }
        // Known seconds selector and an ABI-checked invocation. Unknown signatures
        // are unsupported instead of receiving guessed units/register arguments.
        return ShrubSeekPlaybackSeconds(player, seconds)
    }

    func optionsChanged() {
        queue.async {
            self.emptyEpisodeIDs.removeAll()
            if !UserDefaults.sponsorBlockOptions.enabled { self.resetState() }
        }
    }

    private func resetState() {
        stopPolling()
        fetchGeneration = UUID()
        playbackGeneration = UUID()
        fetchInFlight = false
        currentEpisodeID = nil
        currentSegments.removeAll()
        dismissedUUIDs.removeAll(); promptedUUIDs.removeAll(); playthroughAllowed.removeAll()
        pendingSeekTarget = nil; preSeekPosition = nil
        lastPlayer = nil; lastIsPlaying = false; lastDuration = 0
        lastPosition = 0; lastPositionStamp = 0
        SponsorBlockToast.shared.dismissNow()
        broadcastSegments()
    }

    private func safeRead(_ obj: AnyObject?, _ key: String) -> Any? {
        guard let obj else { return nil }
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.value(forKey: key)
    }

    private func safeBool(_ obj: AnyObject?, _ key: String) -> Bool? {
        safeRead(obj, key) as? Bool
    }

    private func dumpTrackProbe(trackObj: AnyObject?, uri: String, isPodcast: Bool, isVideo: Bool) {
        writeDebugLog("[SB][probe] === track probe begin ===")
        writeDebugLog("[SB][probe] uri=\(uri) isPodcast=\(isPodcast ? "Y" : "N") isVideo=\(isVideo ? "Y" : "N")")
        guard let trackObj else { writeDebugLog("[SB][probe] track is nil"); return }
        let cls: AnyClass? = object_getClass(trackObj)
        writeDebugLog("[SB][probe] track class=\(cls.map { String(cString: class_getName($0)) } ?? "<nil>")")

        // ObjC property list — authoritative source of safe-to-read keys.
        var allNames: [String] = []
        if let cls {
            var count: UInt32 = 0
            if let props = class_copyPropertyList(cls, &count) {
                for i in 0..<Int(count) {
                    allNames.append(String(cString: property_getName(props[i])))
                }
                free(props)
            }
        }
        writeDebugLog("[SB][probe] @properties (\(allNames.count)): \(allNames.joined(separator: ", "))")

        let interesting = ["URI", "uri", "name", "isPodcast", "isVideo", "isAd", "isExplicit",
                           "isLocal", "isLive", "isPaywalled", "mediaType", "type", "format",
                           "contentType", "showURI", "episodeURI", "duration", "metadata",
                           "contextURI", "previewURI", "shareURL"]
        for k in interesting {
            if let v = safeRead(trackObj, k) {
                let s = String(describing: v)
                let trimmed = s.count > 200 ? String(s.prefix(200)) + "…" : s
                writeDebugLog("[SB][probe]   \(k) = \(trimmed)")
            }
        }
        writeDebugLog("[SB][probe] === track probe end ===")
    }

    private func extractEpisodeID(fromURI uri: String) -> String? {
        if uri.hasPrefix("spotify:episode:") {
            return String(uri.dropFirst("spotify:episode:".count))
        }
        if let r = uri.range(of: "/episode/") {
            return String(uri[r.upperBound...]).split(separator: "?").first.map(String.init)
        }
        return nil
    }

    private func monotonicMs() -> UInt64 {
        UInt64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
    }

    private func uptimeSec() -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }

    private func broadcastSegments() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SponsorBlockSkipper.segmentsChangedNotification, object: nil)
        }
    }
}

private func fmt(_ d: Double) -> String { String(format: "%.2f", d) }
private func fmtSigned(_ d: Double) -> String { String(format: "%+.2f", d) }

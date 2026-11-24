import Foundation

// Provider state still has one writer; obsolete work is cancelled rather than
// allowing a serial backlog to hold the current track hostage.
private let evolvedLyricsWorker = DispatchQueue(label: "com.shrubify.evolved.lyrics")
private final class LyricsFlight {
    let key: String
    let trackID: String
    let token = LyricsCancellationToken()
    var callbacks: [(Data?) -> Void] = []
    var finished = false
    init(key: String, trackID: String) {
        self.key = key
        self.trackID = trackID
    }
    func finish(_ data: Data?) {
        guard !finished else { return }
        finished = true
        let pending = callbacks; callbacks.removeAll()
        for callback in pending { callback(data) }
    }
}
// Main queue owns flights, their callback lists and completion delivery.
private var currentLyricsFlight: LyricsFlight?

func extractTrackId(from path: String) -> String? {
    guard let range = path.range(of: #"/track/([a-zA-Z0-9]+)"#, options: .regularExpression) else { return nil }
    return path[range].split(separator: "/").last.map(String.init)
}

func invalidateLyricsForSourceChange() {
    DispatchQueue.main.async {
        currentLyricsFlight?.token.cancel()
        currentLyricsFlight?.finish(nil)
        currentLyricsFlight = nil
        LyricsResponseCache.shared.noteSettingsChanged()
        KaraokeLyricsStore.shared.clear()
        LyricsURLCachePurge.purgeLastRequest(reason: "Settings changed")
    }
}

func prefetchLyricsIfNeeded(trackId: String) {
    loadLyricsDataAsync("/color-lyrics/v2/track/" + trackId) { _ in }
}

func loadLyricsDataAsync(_ path: String, originalLyrics: Lyrics? = nil, force: Bool = false,
                         completion: @escaping (Data?) -> Void) {
    let arrived = ProcessInfo.processInfo.systemUptime
    DispatchQueue.main.async {
        let deliver: (Data?) -> Void = { data in
            if let data { completion(data); return }
            if let originalLyrics, let id = extractTrackId(from: path),
               CurrentSpotifyTrack.identifier == id,
               KaraokeLyricsStore.shared.lyrics(forTrackId: id) == nil, originalLyrics.data.timeSynchronized,
               !originalLyrics.data.lines.isEmpty {
                let lines = originalLyrics.data.lines.map {
                    LyricsLineDto(content: $0.content, offsetMs: Int($0.offsetMs))
                }
                let provider = originalLyrics.data.providedBy
                if let lyrics = KaraokeLyricsAdapter.convert(
                    lines: lines, timeSynced: true, providerName: provider.isEmpty ? "Spotify" : provider
                ) {
                    KaraokeLyricsStore.shared.set(trackId: id, lyrics: lyrics)
                }
            }
            completion(emptyLyricsData(originalLyrics: originalLyrics))
        }
        if NgzhwmSettingsViewModel.isLyricsFeatureDisabled {
            let blocked = try? Lyrics.with { $0.data = LyricsData() }.serializedData()
            completion(blocked)
            return
        }
        let signature = LyricsResponseCache.currentSignature
        guard let trackID = extractTrackId(from: path) else { deliver(nil); return }
        let key = trackID + "|" + signature
        if let existing = currentLyricsFlight, !existing.finished {
            if existing.key == key {
                existing.callbacks.append(deliver)
                return
            }
            if LyricsResultPolicy.shouldKeepActiveLookup(
                active: existing.trackID, incoming: trackID, playing: CurrentSpotifyTrack.identifier
            ) {
                writeDebugLog("[Lyrics] Deferred another track while looking up the playing track")
                deliver(nil)
                return
            }
        }
        currentLyricsFlight?.token.cancel()
        currentLyricsFlight?.finish(nil)
        let flight = LyricsFlight(key: key, trackID: trackID)
        flight.callbacks = [deliver]
        currentLyricsFlight = flight
        let cache = LyricsResponseCache.shared
        if force { cache.reset() }
        let plan = cache.budgetPlan(forPath: path, signature: signature)
        if case .cached(let data) = plan.plan {
            if let id = extractTrackId(from: path), id == currentLyricsDtoTrackId, let dto = currentLyricsDto {
                publishShrubifyCustomLyrics(dto, trackId: id)
            }
            flight.finish(data)
            return
        }
        evolvedLyricsWorker.async {
            let remaining = max(0, plan.budget - (ProcessInfo.processInfo.systemUptime - arrived))
            var result: Data?
            if remaining > 0, !flight.token.isCancelled {
                do {
                    result = try LyricsRequestBudget.withLimit(seconds: remaining, cancellation: flight.token) {
                        try LyricsRequestBudget.check()
                        return try getLyricsDataForCurrentTrack(path, originalLyrics: originalLyrics)
                    }
                } catch {
                    writeDebugLog("[Lyrics] Lookup ended: \(error)")
                }
            }
            let data = result
            DispatchQueue.main.async {
                guard !flight.finished, !flight.token.isCancelled else { return }
                // Transient failures and stale settings must never become memoized
                // "unavailable" responses after connectivity recovers.
                if let data, signature == LyricsResponseCache.currentSignature,
                   let track = extractTrackId(from: path), currentLyricsDtoTrackId == track,
                   currentLyricsDto?.lines.isEmpty == false {
                    cache.store(data, forPath: path, signature: signature)
                }
                flight.finish(data)
            }
        }
        // An arrival-to-completion deadline also covers queue and DNS delays.
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, plan.budget - (ProcessInfo.processInfo.systemUptime - arrived))) {
            guard !flight.finished else { return }
            writeDebugLog("[Lyrics] Lookup deadline expired")
            flight.token.cancel()
            flight.finish(nil)
        }
    }
}

func emptyLyricsData(originalLyrics: Lyrics? = nil) -> Data? {
    if let originalLyrics, !originalLyrics.data.lines.isEmpty,
       let data = try? originalLyrics.serializedData() {
        return data
    }
    return unavailableLyricsBytes(original: originalLyrics, message: "lyrics_lookup_retry".localized)
}

func publishShrubifyCustomLyrics(_ dto: LyricsDto, trackId: String) {
    guard !trackId.isEmpty else { return }
    if let lyrics = KaraokeLyricsAdapter.convert(lines: dto.lines, timeSynced: dto.timeSynced,
        providerName: dto.providerName, contributors: dto.providerContributors) {
        KaraokeLyricsStore.shared.set(trackId: trackId, lyrics: lyrics)
    } else { KaraokeLyricsStore.shared.remove(trackId: trackId) }
}

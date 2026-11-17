import Foundation

/// Preserve Shrubify's asynchronous response delivery and task-identity buffers.
/// The serial worker keeps Evolved's global provider/rendering state single-writer.
private let evolvedLyricsWorker = DispatchQueue(label: "com.shrubify.evolved.lyrics")

func extractTrackId(from path: String) -> String? {
    guard let range = path.range(of: #"/track/([a-zA-Z0-9]+)"#, options: .regularExpression) else { return nil }
    return path[range].split(separator: "/").last.map(String.init)
}

func invalidateLyricsForSourceChange() {
    LyricsResponseCache.shared.noteSettingsChanged()
    LyricsURLCachePurge.purgeLastRequest(reason: "Settings changed")
}

func prefetchLyricsIfNeeded(trackId: String) {
    loadLyricsDataAsync("/color-lyrics/v2/track/" + trackId) { _ in }
}

func loadLyricsDataAsync(_ path: String, originalLyrics: Lyrics? = nil, force: Bool = false,
                         completion: @escaping (Data?) -> Void) {
    if NgzhwmSettingsViewModel.isLyricsFeatureDisabled {
        let blocked = try? Lyrics.with { lyrics in
            lyrics.data = LyricsData()
        }.serializedData()
        DispatchQueue.main.async { completion(blocked) }
        return
    }
    evolvedLyricsWorker.async {
        let signature = LyricsResponseCache.currentSignature
        let cache = LyricsResponseCache.shared
        if force { cache.reset() }
        let plan = cache.budgetPlan(forPath: path, signature: signature)
        if case .cached(let data) = plan.plan {
            DispatchQueue.main.async { completion(data) }
            return
        }
        let data = (try? LyricsRequestBudget.withLimit(seconds: plan.budget) {
            try getLyricsDataForCurrentTrack(path, originalLyrics: originalLyrics)
        })
            ?? unavailableLyricsBytes(original: originalLyrics)
        if let data { cache.store(data, forPath: path, signature: signature) }
        DispatchQueue.main.async { completion(data) }
    }
}

func emptyLyricsData(originalLyrics: Lyrics? = nil) -> Data? {
    unavailableLyricsBytes(original: originalLyrics)
}

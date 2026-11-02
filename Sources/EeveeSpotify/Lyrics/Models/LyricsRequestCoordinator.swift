import Foundation

private struct LyricsRequestConfiguration: Equatable {
    let primary = UserDefaults.lyricsSource
    let fallbacks = UserDefaults.lyricsFallbackOrder
    let options = UserDefaults.lyricsOptions
    let spicyKey = UserDefaults.effectiveSpicyLyricsApiKey
    let musixmatchToken = UserDefaults.musixmatchToken
}

struct LoadedLyrics {
    let dto: LyricsDto
    let source: LyricsSource
}

/// All request/cache ownership lives on one queue. Repository work runs on a
/// separate bounded serial worker; it never blocks Spotify's delegate or UI.
final class LyricsRequestCoordinator {
    static let shared = LyricsRequestCoordinator()
    private let queue = DispatchQueue(label: "com.shrubify.lyrics.requests")
    private let worker = DispatchQueue(label: "com.shrubify.lyrics.providers", qos: .userInitiated)
    private var configuration: LyricsRequestConfiguration?
    private var jobs: [String: (id: UUID, context: LyricsRequestContext, callbacks: [(LoadedLyrics?) -> Void])] = [:]
    private var cache: [String: LoadedLyrics] = [:]
    private var recency: [String] = []

    func invalidate() { queue.async { self.clear() } }
    private func clear() {
        jobs.values.forEach { $0.context.cancel() }
        let callbacks = jobs.values.flatMap { $0.callbacks }
        jobs.removeAll(); cache.removeAll(); recency.removeAll()
        KaraokeLyricsStore.shared.clear()
        callbacks.forEach { $0(nil) }
    }

    func request(_ query: LyricsSearchQuery, force: Bool, completion: @escaping (LoadedLyrics?) -> Void) {
        let config = LyricsRequestConfiguration()
        queue.async {
            if self.configuration != config { self.clear(); self.configuration = config }
            let track = query.spotifyTrackId
            if force { self.cache[track] = nil; self.recency.removeAll { $0 == track } }
            if let cached = self.cache[track] {
                self.recency.removeAll { $0 == track }; self.recency.append(track)
                completion(cached)
                return
            }
            if self.jobs[track] != nil { self.jobs[track]?.callbacks.append(completion); return }
            let playing = KaraokePlaybackTracker.shared.playerReportedTrackId()
            if track == playing {
                for obsolete in self.jobs.keys.filter({ $0 != track }) {
                    let job = self.jobs.removeValue(forKey: obsolete)
                    job?.context.cancel()
                    job?.callbacks.forEach { $0(nil) }
                }
            }
            while self.jobs.count >= 2, let obsolete = self.jobs.keys.first(where: { $0 != playing && $0 != track }) {
                let obsoleteJob = self.jobs.removeValue(forKey: obsolete)
                obsoleteJob?.context.cancel()
                let callbacks = obsoleteJob?.callbacks ?? []
                callbacks.forEach { $0(nil) }
            }
            let id = UUID()
            let context = LyricsRequestContext()
            self.jobs[track] = (id, context, [completion])
            self.worker.async {
                // Invalidated or superseded queued jobs do no network work.
                guard self.queue.sync(execute: { self.jobs[track]?.id == id }) else { return }
                let result: LoadedLyrics? = context.run {
                var query = query
                if (query.title.isEmpty || query.primaryArtist.isEmpty), let token = spotifyAccessToken,
                   let info = fetchTrackDetails(trackId: track, token: token) {
                    query = LyricsSearchQuery(title: info.title, primaryArtist: info.artist, spotifyTrackId: track)
                    LyricsTrackMetadata.set(trackId: track, title: info.title, artist: info.artist)
                }
                return self.load(query, configuration: config, isCurrent: { !context.isCancelled })
                }
                context.cancel()
                self.queue.async {
                    guard self.jobs[track]?.id == id, self.configuration == config else { return }
                    let callbacks = self.jobs.removeValue(forKey: track)?.callbacks ?? []
                    if let result {
                        self.cache[track] = result
                        self.recency.removeAll { $0 == track }; self.recency.append(track)
                        while self.recency.count > 8 { self.cache[self.recency.removeFirst()] = nil }
                        if let karaoke = result.dto.karaoke ?? KaraokeLyricsDto.lineSynced(from: result.dto, providerName: result.source.description) {
                            KaraokeLyricsStore.shared.set(trackId: track, lyrics: karaoke)
                        } else { KaraokeLyricsStore.shared.remove(trackId: track) }
                        var state = LyricsLoadingState()
                        state.isEmpty = result.dto.lines.isEmpty
                        state.loadedSuccessfully = true
                        state.wasRomanized = result.dto.romanization == .romanized
                            || (result.dto.romanization == .canBeRomanized && config.options.romanization)
                        lyricsState = state
                    } else {
                        var state = LyricsLoadingState()
                        state.fallbackError = .noSuchSong
                        lyricsState = state
                    }
                    callbacks.forEach { $0(result) }
                }
            }
        }
    }

    private func load(_ query: LyricsSearchQuery, configuration: LyricsRequestConfiguration,
                      isCurrent: () -> Bool) -> LoadedLyrics? {
        for source in LyricsFallbacks.chain(primary: configuration.primary, fallbacks: configuration.fallbacks) {
            guard isCurrent() else { return nil }
            if [.genius, .lrclib, .petit].contains(source) && (query.title.isEmpty || query.primaryArtist.isEmpty) { continue }
            let repository: LyricsRepository
            switch source {
            case .spicylyrics: repository = SpicyLyricsRepository.shared
            case .musixmatch: repository = MusixmatchLyricsRepository.shared
            case .lrclib: repository = LrclibLyricsRepository.shared
            case .genius: repository = GeniusLyricsRepository()
            case .petit: repository = PetitLyricsRepository()
            case .notReplaced: continue
            }
            do {
                let dto = try repository.getLyrics(query, options: configuration.options)
                if !dto.lines.isEmpty || dto.instrumental { return LoadedLyrics(dto: dto, source: source) }
            } catch {
                writeDebugLog("[Lyrics] \(source.description) could not load \(query.spotifyTrackId): \(error)")
            }
        }
        return nil
    }
}

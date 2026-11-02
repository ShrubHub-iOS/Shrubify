import Orion
import SwiftUI
import MediaPlayer

struct BaseLyricsGroup: HookGroup { }
struct LegacyLyricsGroup: HookGroup { }
struct ModernLyricsGroup: HookGroup { }
struct V91LyricsGroup: HookGroup { }
struct LyricsErrorHandlingGroup: HookGroup { }

private let lyricsStateLock = NSLock()
private var storedLyricsState = LyricsLoadingState()
var lyricsState: LyricsLoadingState {
    get { lyricsStateLock.lock(); defer { lyricsStateLock.unlock() }; return storedLyricsState }
    set { lyricsStateLock.lock(); storedLyricsState = newValue; lyricsStateLock.unlock() }
}
var hasShownRestrictedPopUp = false
var hasShownUnauthorizedPopUp = false

func invalidateLyricsForSourceChange() { LyricsRequestCoordinator.shared.invalidate() }

func extractTrackId(from path: String) -> String? {
    guard let range = path.range(of: #"/track/([a-zA-Z0-9]+)"#, options: .regularExpression) else { return nil }
    let id = String(path[range].split(separator: "/").last ?? "")
    return id.isEmpty ? nil : id
}

func prefetchLyricsIfNeeded(trackId: String) {
    loadLyricsDataAsync("/color-lyrics/v2/track/" + trackId) { _ in }
}

/// Completion is always asynchronous on main. Metadata is captured before any
/// worker starts, with no main.sync/semaphore cycle and no private UI calls off-main.
func loadLyricsDataAsync(_ path: String, originalLyrics: Lyrics? = nil, force: Bool = false,
                         completion: @escaping (Data?) -> Void) {
    DispatchQueue.main.async {
        guard UserDefaults.lyricsSource.isReplacingLyrics, let trackId = extractTrackId(from: path) else { completion(nil); return }
        if KaraokePlaybackTracker.shared.playerReportedTrackId() == nil { KaraokePlaybackTracker.shared.updateTrackIdFromLyricsFetch(trackId) }
        var metadata = LyricsTrackMetadata.get(trackId: trackId)
        if metadata == nil, KaraokePlaybackTracker.shared.playerReportedTrackId() == trackId,
           let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let title = info[MPMediaItemPropertyTitle] as? String,
           let artist = info[MPMediaItemPropertyArtist] as? String {
            LyricsTrackMetadata.set(trackId: trackId, title: title, artist: artist)
            metadata = (title, artist)
        }
        let query = LyricsSearchQuery(title: metadata?.title ?? "", primaryArtist: metadata?.artist ?? "", spotifyTrackId: trackId)
        LyricsRequestCoordinator.shared.request(query, force: force) { result in
            DispatchQueue.main.async {
                guard let result else { completion(originalLyrics.flatMap { try? $0.serializedData() } ?? emptyLyricsData()); return }
                var lyrics = Lyrics.with { $0.data = result.dto.toSpotifyLyricsData(source: result.source.description) }
                let settings = UserDefaults.lyricsColors
                if settings.displayOriginalColors, let originalLyrics { lyrics.colors = originalLyrics.colors }
                else {
                    let color: Color
                    if settings.useStaticColor { color = Color(hex: settings.staticColor) }
                    else if let uiColor = backgroundViewModel?.color() { color = Color(uiColor).normalized(settings.normalizationFactor) }
                    else { color = .gray }
                    lyrics.colors = LyricsColors.with {
                        $0.backgroundColor = color.uInt32
                        $0.lineColor = Color.black.uInt32
                        $0.activeLineColor = Color.white.uInt32
                    }
                }
                completion(try? lyrics.serializedData())
            }
        }
    }
}

func emptyLyricsData(originalLyrics: Lyrics? = nil) -> Data? {
    let emptyDto = LyricsDto(lines: [], timeSynced: false, romanization: .original, translation: nil)
    var lyrics = Lyrics.with {
        $0.data = emptyDto.toSpotifyLyricsData(source: "")
    }
    if let originalLyrics = originalLyrics {
        lyrics.colors = originalLyrics.colors
    }
    return try? lyrics.serializedData()
}

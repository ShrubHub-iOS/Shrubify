import SwiftUI
import UIKit

/// Keeps the open custom lyrics view in step with the playing track. When a song ends and the
/// next one starts, it swaps in that song's lyrics (fetching them if Spotify hasn't), and gives up
/// — closing the view — only if none turn up.
@available(iOS 15.0, *)
final class KaraokeLyricsViewModel: ObservableObject {
    @Published private(set) var playback = KaraokePlaybackSnapshot()
    @Published private(set) var trackId: String?
    @Published private(set) var lyrics: KaraokeLyricsDto?
    @Published private(set) var layouts: [KaraokeLineLayout] = []

    private let onNoLyrics: () -> Void
    private var observer: NSObjectProtocol?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var playbackTimer: Timer?
    private var visible = false
    private var retryWork: DispatchWorkItem?
    private var attempts = 0

    private let maxAttempts = 4
    private let retryInterval: TimeInterval = 2.0

    init(trackId: String?, lyrics: KaraokeLyricsDto, onNoLyrics: @escaping () -> Void) {
        self.trackId = trackId
        self.onNoLyrics = onNoLyrics
        apply(lyrics)
        observer = NotificationCenter.default.addObserver(
            forName: .eeveeKaraokeLyricsChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.sync() }
        lifecycleObservers = [
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
                DispatchQueue.main.async { self?.pauseUpdates() }
            },
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
                DispatchQueue.main.async { if self?.visible == true { self?.startPlaybackUpdates() } }
            }
        ]
    }

    deinit {
        playbackTimer?.invalidate()
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        retryWork?.cancel()
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func startPlaybackUpdates() {
        visible = true
        guard UIApplication.shared.applicationState == .active else { return }
        refreshPlayback()
        guard playbackTimer == nil else { return }
        let timer = Timer(timeInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.1 : 0.05, repeats: true) { [weak self] _ in self?.refreshPlayback() }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        playbackTimer = timer
    }

    func stopPlaybackUpdates() {
        visible = false
        pauseUpdates()
    }

    private func pauseUpdates() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func refreshPlayback() {
        let next = KaraokeSeek.refresh()
        if next != playback { playback = next }
        if let id = playback.trackID, id != trackId { sync() }
    }

    func seek(to milliseconds: Int) -> Bool {
        let target = playback.durationMs > 0 ? min(playback.durationMs, max(0, milliseconds)) : max(0, milliseconds)
        let result = KaraokeSeek.seek(milliseconds: target, trackID: trackId)
        if result { playback = KaraokePlaybackTracker.shared.snapshot() }
        return result
    }

    func togglePlayback() -> Bool {
        KaraokeSeek.setPaused(playback.isPlaying)
    }

    private func apply(_ candidate: KaraokeLyricsDto?) {
        guard var lyrics = candidate else { self.lyrics = nil; layouts = []; return }
        // The line lookup and layout must use exactly the same sorted sequence.
        lyrics.lines = lyrics.lines.enumerated().sorted {
            $0.element.startMs == $1.element.startMs ? $0.offset < $1.offset : $0.element.startMs < $1.element.startMs
        }.map(\.element)
        self.lyrics = lyrics
        let songIsRTL = lyrics.isRTL
        layouts = lyrics.lines.map { line in
            let direction = line.strongDirection
            return KaraokeLineLayout(words: line.words, isRTL: direction.map { $0 == .rightToLeft } ?? songIsRTL)
        }
    }

    private func sync() {
        // The player's own track, not the one a lyrics request last named: Spotify also loads
        // lyrics for songs that haven't started yet.
        let tracker = KaraokePlaybackTracker.shared
        guard let playing = tracker.playerReportedTrackId() ?? tracker.currentTrackId() else { return }

        let stored = KaraokeLyricsStore.shared.lyrics(forTrackId: playing)
        if playing != trackId {
            retryWork?.cancel()
            retryWork = nil
            attempts = 0
            trackId = playing
            apply(stored)
        } else if lyrics == nil, let stored {
            apply(stored)
        }

        if lyrics == nil {
            fetchMissingLyrics()
        } else {
            retryWork?.cancel()
            retryWork = nil
        }
    }

    private func fetchMissingLyrics() {
        guard retryWork == nil, let trackId else { return }
        guard attempts < maxAttempts else {
            writeDebugLog("[Karaoke] no lyrics for \(trackId) after \(attempts) attempts, closing custom lyrics view")
            onNoLyrics()
            return
        }
        attempts += 1
        writeDebugLog("[Karaoke] track changed to \(trackId) with the custom lyrics view open, fetching lyrics (attempt \(attempts))")
        prefetchLyricsIfNeeded(trackId: trackId)

        let work = DispatchWorkItem { [weak self] in
            self?.retryWork = nil
            self?.sync()
        }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval, execute: work)
    }
}

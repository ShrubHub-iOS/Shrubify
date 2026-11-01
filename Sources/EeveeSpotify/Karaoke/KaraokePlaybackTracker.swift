import Foundation

struct KaraokePlaybackSnapshot: Equatable {
    var positionMs = 0
    var durationMs = 0
    var isPlaying = false
    var trackID: String?
}

/// Receives validated facts from the player bridge. The open lyrics screen polls
/// live state; interpolation is only for the interval between those samples.
final class KaraokePlaybackTracker {
    static let shared = KaraokePlaybackTracker()
    private let queue = DispatchQueue(label: "com.shrubify.lyrics.clock")
    private var position: Double = 0
    private var duration: Double = 0
    private var stamp: TimeInterval = 0
    private var speed: Double = 1
    private var playing = false
    private var observedID: String?
    private var fetchedID: String?
    private var pendingSeek: (seconds: Double, stamp: TimeInterval)?

    private init() {}
    private func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
    private func milliseconds(_ seconds: Double) -> Int {
        guard seconds.isFinite else { return 0 }
        return Int(min(Double(Int.max / 2), max(0, seconds) * 1000))
    }

    func didSeek(milliseconds: Int) {
        guard milliseconds >= 0 else { return }
        queue.sync {
            position = Double(milliseconds) / 1000
            stamp = uptime()
            pendingSeek = (position, stamp)
        }
    }

    /// Dictionaries originate from the exception-guarded Objective-C bridge.
    /// No KVC or guessed scalar selectors execute in Swift.
    func processStateChange(state: AnyObject) {
        guard let facts = state as? NSDictionary,
              let raw = facts["position"] as? NSNumber, raw.doubleValue.isFinite else { return }
        let value = max(0, raw.doubleValue)
        let paused = (facts["paused"] as? NSNumber)?.boolValue
        let reportedDuration = (facts["duration"] as? NSNumber)?.doubleValue
        let reportedSpeed = (facts["speed"] as? NSNumber)?.doubleValue
        let uri = facts["uri"] as? String
        let id = uri.flatMap { $0.hasPrefix("spotify:track:") ? String($0.dropFirst(14)) : nil }
        queue.sync {
            let now = uptime()
            let changed = uri != nil && id != observedID
            if changed { pendingSeek = nil; position = 0 }
            let stale = pendingSeek.map { target -> Bool in
                let expected = target.seconds + (playing ? max(0, now - target.stamp) * speed : 0)
                return now - target.stamp < 5 && abs(value - expected) > 0.75
            } ?? false
            if !stale {
                position = value
                stamp = now
                pendingSeek = nil
                if let paused { playing = !paused }
            }
            if let reportedSpeed, reportedSpeed.isFinite { speed = max(0, reportedSpeed) }
            if let reportedDuration, reportedDuration.isFinite { duration = max(0, reportedDuration) }
            if uri != nil {
                observedID = id
                if changed {
                    fetchedID = id
                    KaraokeLyricsStore.shared.notify()
                }
            }
        }
    }

    func snapshot() -> KaraokePlaybackSnapshot {
        queue.sync {
            let elapsed = stamp == 0 || !playing ? 0 : max(0, uptime() - stamp) * speed
            let current = duration > 0 ? min(duration, position + elapsed) : position + elapsed
            return KaraokePlaybackSnapshot(positionMs: milliseconds(current), durationMs: milliseconds(duration), isPlaying: playing, trackID: observedID ?? fetchedID)
        }
    }
    func currentPositionMs() -> Int { snapshot().positionMs }
    func isPlaying() -> Bool { snapshot().isPlaying }
    func playerReportedTrackId() -> String? { queue.sync { observedID } }
    func currentTrackId() -> String? { queue.sync { observedID ?? fetchedID } }
    func updateTrackIdFromLyricsFetch(_ id: String) {
        guard !id.isEmpty else { return }
        queue.sync {
            if fetchedID != id { fetchedID = id; KaraokeLyricsStore.shared.notify() }
        }
    }
}

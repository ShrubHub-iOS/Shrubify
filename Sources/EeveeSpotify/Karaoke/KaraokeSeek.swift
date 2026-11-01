import EeveeSpotifyC
import Foundation

enum KaraokeSeek {
    private static let playerLock = NSLock()
    private static weak var storedPlayer: AnyObject?
    static var player: AnyObject? {
        get { playerLock.lock(); defer { playerLock.unlock() }; return storedPlayer }
        set { playerLock.lock(); storedPlayer = newValue; playerLock.unlock() }
    }

    static func observe(_ state: AnyObject) {
        if let facts = ShrubPlaybackFacts(state) { KaraokePlaybackTracker.shared.processStateChange(state: facts as NSDictionary) }
    }

    static func refresh() -> KaraokePlaybackSnapshot {
        if let player, let facts = ShrubReadLivePlayback(player) {
            KaraokePlaybackTracker.shared.processStateChange(state: facts as NSDictionary)
        }
        return KaraokePlaybackTracker.shared.snapshot()
    }

    static func setPaused(_ paused: Bool) -> Bool {
        guard Thread.isMainThread, let player else { return false }
        return ShrubSetPlaybackPaused(player, paused)
    }

    static func seek(milliseconds: Int, trackID: String? = nil) -> Bool {
        guard Thread.isMainThread, milliseconds >= 0 else { return false }
        if let trackID, let playing = KaraokePlaybackTracker.shared.playerReportedTrackId(), playing != trackID { return false }
        let seconds = Double(milliseconds) / 1000
        if let player, ShrubSeekPlaybackSeconds(player, seconds) { KaraokePlaybackTracker.shared.didSeek(milliseconds: milliseconds); return true }
        if let player = statefulPlayer, ShrubSeekPlaybackSeconds(player, seconds) { KaraokePlaybackTracker.shared.didSeek(milliseconds: milliseconds); return true }
        return false
    }
}

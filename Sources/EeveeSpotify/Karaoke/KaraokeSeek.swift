import EeveeSpotifyC
import Foundation

enum KaraokeSeek {
    static weak var player: AnyObject?

    static func seek(milliseconds: Int) -> Bool {
        guard Thread.isMainThread, milliseconds >= 0 else { return false }
        let seconds = Double(milliseconds) / 1000
        if let player, ShrubSeekPlaybackSeconds(player, seconds) { KaraokePlaybackTracker.shared.didSeek(milliseconds: milliseconds); return true }
        if let player = statefulPlayer, ShrubSeekPlaybackSeconds(player, seconds) { KaraokePlaybackTracker.shared.didSeek(milliseconds: milliseconds); return true }
        return false
    }
}

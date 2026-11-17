import Foundation
import UIKit

/// Replay reads the same captured player as Evolved. No second player hook or
/// competing lyrics overlay is installed.
func activateShrubifyPlaybackSupport() {
    DispatchQueue.main.async {
        KaraokeSeek.player = statefulPlayer as AnyObject?
        KaraokeGestureTrigger.shared.attachIfNeeded()
    }
}

extension Notification.Name {
    static let eeveeKaraokeLyricsChanged = Notification.Name("ShrubifyPlaybackMetadataChanged")
}

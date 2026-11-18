import Foundation
import EeveeSpotifyC

/// A private protocol declaration is not a runtime guarantee. Keep native
/// objects on the player/UI thread and return only checked, immutable facts.
enum CurrentSpotifyTrack {
    private static func read<T>(_ body: @escaping (AnyObject?) -> T) -> T {
        let work = {
            let track = ShrubReadCurrentTrack(statefulPlayer as AnyObject?, nowPlayingScrollViewController as AnyObject?)
            return body(track as AnyObject?)
        }
        return Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)
    }
    static var snapshot: SafeTrackMetadata? { read { SafeTrackMetadata(track: $0) } }
    static func matchesIfPresent(title: String, artist: String) -> Bool {
        read { track in
            guard let track else { return true }
            guard let info = SafeTrackMetadata(track: track) else { return false }
            return info.title == title && info.artist == artist
        }
    }
    // Renderers check identity at display-link frequency. Do not copy the full
    // metadata dictionary, read colors, or query title/artist on that path.
    static var identifier: String? { read { ShrubTrackIdentifier($0) } }
}

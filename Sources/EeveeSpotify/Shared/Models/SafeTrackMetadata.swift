import Foundation
#if canImport(EeveeSpotifyC)
import EeveeSpotifyC
#endif

/// Typed display data obtained through the exception/ABI-checked ObjC bridge.
/// Nil means the custom UI must leave the native presentation in place.
struct SafeTrackMetadata: Equatable {
    let title: String
    let artist: String
    let metadata: [String: String]

    init?(track: AnyObject?) {
        guard let track, let facts = ShrubReadTrackMetadata(track),
              let title = facts["title"] as? String, !title.isEmpty else { return nil }
        self.title = title
        self.artist = facts["artist"] as? String ?? ""
        self.metadata = facts["metadata"] as? [String: String] ?? [:]
    }
}

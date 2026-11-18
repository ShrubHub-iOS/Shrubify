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
    let identifier: String?
    let extractedColor: String?
    var durationMs: Int? { Self.durationMilliseconds(in: metadata) }

    init?(track: AnyObject?) {
        guard let track, let facts = ShrubReadTrackMetadata(track),
              let title = facts["title"] as? String, !title.isEmpty else { return nil }
        self.title = title
        self.artist = facts["artist"] as? String ?? ""
        self.identifier = (facts["identifier"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.extractedColor = (facts["color"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.metadata = facts["metadata"] as? [String: String] ?? [:]
    }

    static func durationMilliseconds(in metadata: [String: String]) -> Int? {
        func milliseconds(_ key: String, scale: Double) -> Int? {
            guard let raw = metadata[key], let value = Double(raw), value.isFinite, value > 0,
                  let ms = Int(exactly: (value * scale).rounded()), ms > 0 else { return nil }
            return ms
        }
        for key in ["duration_ms", "durationMs", "durationInMilliseconds"] {
            if let ms = milliseconds(key, scale: 1) { return ms }
        }
        for key in ["duration_seconds", "durationSeconds"] {
            if let ms = milliseconds(key, scale: 1000) { return ms }
        }
        // Legacy unsuffixed duration is mixed-unit. Avoid using an ambiguous
        // value as a hard duration gate (e.g. 30000s vs a 30s clip).
        guard let raw = metadata["duration"], let value = Double(raw) else { return nil }
        if value < 1000 { return milliseconds("duration", scale: 1000) }
        return value >= 60000 ? milliseconds("duration", scale: 1) : nil
    }
}

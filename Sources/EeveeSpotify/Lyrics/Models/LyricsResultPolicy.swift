import Foundation

enum LyricsResultPolicy {
    static func matchesRequestedTrack(requested: String?, current: String?) -> Bool {
        guard let requested, !requested.isEmpty else { return false }
        return requested == current
    }
}

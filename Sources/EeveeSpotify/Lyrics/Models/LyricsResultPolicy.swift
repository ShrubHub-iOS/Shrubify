import Foundation

enum LyricsResultPolicy {
    static func matchesRequestedTrack(requested: String?, current: String?) -> Bool {
        guard let requested, !requested.isEmpty else { return false }
        return requested == current
    }

    static func shouldKeepActiveLookup(active: String, incoming: String, playing: String?) -> Bool {
        active != incoming && incoming != playing
    }
}

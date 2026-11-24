import Foundation

struct LyricsPlusPayload: Decodable {
    private struct Number: Decodable {
        let value: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            value = (try? container.decode(Double.self))
                ?? (try? container.decode(String.self)).flatMap(Double.init)
        }
    }

    private struct Timing: Decodable {
        let time: Number?
        let duration: Number?
        let text: String
        let syllabus: [Timing]?
    }

    private struct Metadata: Decodable {
        let title: String?
        let artist: String?
        let language: String?
        let duration: Number?
    }

    private struct Processing: Decodable {
        let selectedSongMetadata: Metadata?
    }

    private let type: String
    private let metadata: Metadata?
    private let processingTime: Processing?
    private let lyrics: [Timing]

    var language: String? { metadata?.language }
    var isTimed: Bool { ["word", "syllable", "line"].contains(type.lowercased()) }

    func matches(_ query: LyricsSearchQuery) -> Bool {
        let selected = processingTime?.selectedSongMetadata
        if let title = selected?.title ?? metadata?.title,
           !LyricsMatch.titlesMatch(title, anyOf: [query.title] + query.titleVariants) { return false }
        if let artist = selected?.artist ?? metadata?.artist,
           !query.allArtistNames.contains(where: { LyricsMatch.sameArtist(artist, $0) }) { return false }
        let duration = selected?.duration?.value.flatMap { Self.milliseconds($0 * 1000) }
        return LyricsMatch.lengthMatches(duration, query.durationMs, slackMs: 4500)
    }

    var lines: [LyricsLineDto] {
        let wordTimed = ["word", "syllable"].contains(type.lowercased())
        return lyrics.compactMap { line in
            let start = isTimed ? line.time?.value.flatMap(Self.milliseconds) : nil
            let end = start.flatMap { start in
                line.duration?.value.flatMap(Self.milliseconds).flatMap { $0 > 0 ? start + $0 : nil }
            }
            let words = wordTimed && start != nil ? line.syllabus?.compactMap { element -> LyricsWordDto? in
                guard !element.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let onset = element.time?.value.flatMap(Self.milliseconds) else { return nil }
                let end = element.duration?.value.flatMap(Self.milliseconds).flatMap { $0 > 0 ? onset + $0 : nil }
                return LyricsWordDto(text: element.text, startMs: onset, endMs: end)
            } : nil
            guard !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || words?.isEmpty == false else { return nil }
            return LyricsLineDto(content: line.text, offsetMs: start, endOffsetMs: end, words: words)
        }
    }

    private static func milliseconds(_ value: Double) -> Int? {
        guard value.isFinite, (0...86_400_000).contains(value) else { return nil }
        return Int(value.rounded())
    }
}

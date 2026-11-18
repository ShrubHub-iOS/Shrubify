import Foundation

/// Feed Shrubify's original renderer with the current provider DTOs. Word and
/// syllable times remain intact; line-only sources light the whole line at once.
enum KaraokeLyricsAdapter {
    static func convert(lines source: [LyricsLineDto], timeSynced: Bool,
                        providerName: String, contributors: [LyricsContributor] = []) -> KaraokeLyricsDto? {
        guard timeSynced else { return nil }
        let sorted = source.enumerated().filter { ($0.element.offsetMs ?? -1) >= 0 }
            .sorted { $0.element.offsetMs == $1.element.offsetMs ? $0.offset < $1.offset : $0.element.offsetMs! < $1.element.offsetMs! }
            .map(\.element)
        var result: [KaraokeLineDto] = []
        for (index, line) in sorted.enumerated() {
            guard let start = line.offsetMs else { continue }
            let following = sorted.dropFirst(index + 1).compactMap(\.offsetMs).first { $0 > start }
            let declaredEnd = line.endOffsetMs.flatMap { $0 >= start ? $0 : nil }
            let end = declaredEnd ?? following ?? (start > Int.max - 4000 ? Int.max : start + 4000)
            let words = (line.words ?? []).filter { $0.startMs >= 0 && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            var syllables: [KaraokeSyllableDto] = []
            if !words.isEmpty {
                var cursor = line.content.startIndex
                let ranges: [Range<String.Index>?] = words.map { word in
                    let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let range = line.content.range(of: text, options: .caseInsensitive, range: cursor..<line.content.endIndex)
                    if let range { cursor = range.upperBound }
                    return range
                }
                for (wordIndex, word) in words.enumerated() {
                    let nextStart = words.dropFirst(wordIndex + 1).first?.startMs
                    let wordEnd = max(word.startMs, word.endMs ?? nextStart ?? end)
                    var joined = false
                    if wordIndex + 1 < ranges.count, let here = ranges[wordIndex], let next = ranges[wordIndex + 1] {
                        joined = !line.content[here.upperBound..<next.lowerBound].contains(where: { $0.isWhitespace })
                    }
                    syllables.append(KaraokeSyllableDto(text: word.text.trimmingCharacters(in: .whitespacesAndNewlines),
                        startMs: word.startMs, endMs: wordEnd, isPartOfWord: joined))
                }
            } else {
                syllables = line.content.split(whereSeparator: { $0.isWhitespace }).map {
                    KaraokeSyllableDto(text: String($0), startMs: start, endMs: start, isPartOfWord: false)
                }
            }
            guard !syllables.isEmpty else { continue }
            result.append(KaraokeLineDto(syllables: syllables, startMs: start,
                                        endMs: max(end, syllables.map(\.endMs).max() ?? end)))
        }
        guard !result.isEmpty else { return nil }
        let uploader = contributors.first { $0.role == .uploader }
        let maker = contributors.first { $0.role == .maker }
        return KaraokeLyricsDto(lines: result, songWriters: [], providerCode: nil,
            providerName: providerName, uploaderName: uploader?.name, uploaderUrl: uploader?.url?.absoluteString,
            makerName: maker?.name, makerUrl: maker?.url?.absoluteString)
    }
}

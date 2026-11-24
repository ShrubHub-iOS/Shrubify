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
            let content = line.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? words.map(\.text).joined(separator: " ") : line.content
            var syllables = timedFragments(words, content: content, start: start, end: end)
            if syllables.isEmpty { syllables = untimedFragments(content[...], at: start) }
            guard !syllables.isEmpty else { continue }
            result.append(KaraokeLineDto(syllables: syllables, startMs: start,
                                        endMs: max(end, syllables.map(\.endMs).max() ?? end),
                                        originalText: content))
        }
        guard !result.isEmpty else { return nil }
        let uploader = contributors.first { $0.role == .uploader }
        let maker = contributors.first { $0.role == .maker }
        return KaraokeLyricsDto(lines: result, songWriters: [], providerCode: nil,
            providerName: providerName, uploaderName: uploader?.name, uploaderUrl: uploader?.url?.absoluteString,
            makerName: maker?.name, makerUrl: maker?.url?.absoluteString)
    }

    private static func untimedFragments(_ text: Substring, at time: Int) -> [KaraokeSyllableDto] {
        text.split(whereSeparator: \.isWhitespace).map {
            KaraokeSyllableDto(text: String($0), startMs: time, endMs: time, isPartOfWord: false)
        }
    }

    private static func timedFragments(_ words: [LyricsWordDto], content: String, start: Int, end: Int) -> [KaraokeSyllableDto] {
        var fragments: [KaraokeSyllableDto] = []
        var cursor = content.startIndex
        for (index, word) in words.enumerated() {
            let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let match = content.range(of: text, options: [.caseInsensitive, .widthInsensitive],
                                            range: cursor..<content.endIndex) else { continue }
            let gap = content[cursor..<match.lowerBound]
            let nextStart = words.dropFirst(index + 1).first(where: { $0.startMs > word.startMs })?.startMs
            let wordEnd = max(word.startMs, word.endMs ?? nextStart ?? end)
            if let previous = fragments.indices.last, gap.first?.isWhitespace != true {
                fragments[previous].isPartOfWord = true
            }
            let gapFragments = untimedFragments(gap, at: fragments.last?.endMs ?? start)
            fragments.append(contentsOf: gapFragments)
            if !gapFragments.isEmpty, gap.last?.isWhitespace != true, let previous = fragments.indices.last {
                fragments[previous].isPartOfWord = true
            }
            fragments.append(KaraokeSyllableDto(text: String(content[match]), startMs: word.startMs,
                                                endMs: wordEnd, isPartOfWord: false))
            cursor = match.upperBound
        }
        if cursor < content.endIndex, !fragments.isEmpty {
            let tail = content[cursor...]
            if let previous = fragments.indices.last, tail.first?.isWhitespace != true {
                fragments[previous].isPartOfWord = true
            }
            fragments.append(contentsOf: untimedFragments(tail, at: fragments.last?.endMs ?? start))
        }
        return fragments
    }

}

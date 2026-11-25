import Foundation

struct KaraokeSyllableDto: Equatable {
    var text: String
    var startMs: Int
    var endMs: Int
    var isPartOfWord: Bool
}

extension Array where Element == KaraokeSyllableDto {
    // isPartOfWord glues a syllable to the next one, so spacing and grouping follow the previous flag.
    var plainText: String {
        var text = ""
        var previousIsPartOfWord = false
        for syllable in self {
            if !text.isEmpty && !previousIsPartOfWord {
                text += " "
            }
            text += syllable.text
            previousIsPartOfWord = syllable.isPartOfWord
        }
        return text
    }
}

enum KaraokeTextDirection {
    case leftToRight
    case rightToLeft
}

struct KaraokeLineDto: Equatable {
    struct Highlight: Equatable {
        let range: Range<String.Index>
        let start: Int
        let end: Int

        func opacity(at position: Int) -> Double {
            let ramp = min(80, max(1, (end - start) / 3))
            let attack = Double(position - start) / Double(ramp)
            let release = Double(end - position) / Double(ramp)
            let progress = max(0, min(1, attack, release))
            return progress * progress * (3 - 2 * progress)
        }
    }
    var syllables: [KaraokeSyllableDto]
    var startMs: Int
    var endMs: Int
    var originalText: String? = nil

    var hasWordTiming: Bool { syllables.contains { $0.endMs > $0.startMs } }
    var plainText: String { originalText ?? syllables.plainText }

    func highlightRange(at position: Int) -> Range<String.Index>? {
        highlight(at: position)?.range
    }

    func highlight(at position: Int) -> Highlight? {
        let text = plainText
        var cursor = text.startIndex
        for syllable in syllables {
            guard let match = text.range(of: syllable.text, options: [.caseInsensitive, .widthInsensitive],
                                         range: cursor..<text.endIndex) else { continue }
            if syllable.endMs > syllable.startMs, position >= syllable.startMs, position < syllable.endMs {
                return Highlight(range: match, start: syllable.startMs, end: syllable.endMs)
            }
            cursor = match.upperBound
        }
        return nil
    }

    var words: [[KaraokeSyllableDto]] {
        var result: [[KaraokeSyllableDto]] = []
        var current: [KaraokeSyllableDto] = []
        for syllable in syllables {
            if current.isEmpty || current.last?.isPartOfWord == true {
                current.append(syllable)
            } else {
                result.append(current)
                current = [syllable]
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // Hebrew/Arabic/Syriac/Thaana blocks read RTL, Latin/Cyrillic/Greek LTR; nil for lines with neither ("♪", "(2x)").
    var strongDirection: KaraokeTextDirection? {
        for scalar in plainText.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x05FF,  // Hebrew
                 0x0600...0x06FF,  // Arabic (includes Persian, Urdu, etc.)
                 0x0700...0x074F,  // Syriac
                 0x0750...0x077F,  // Arabic Supplement
                 0x0780...0x07BF,  // Thaana
                 0x0800...0x085F,  // Samaritan & Mandaic
                 0x0870...0x089F,  // Arabic Extended-B
                 0x08A0...0x08FF,  // Arabic Extended-A
                 0xFB1D...0xFB4F,  // Hebrew Presentation Forms
                 0xFB50...0xFDFF,  // Arabic Presentation Forms-A
                 0xFE70...0xFEFF,  // Arabic Presentation Forms-B
                 0x10EC0...0x10EFF: // Arabic Extended-C
                return .rightToLeft
            case 0x0041...0x005A, 0x0061...0x007A,  // Basic Latin
                 0x00C0...0x00D6, 0x00D8...0x00F6, 0x00F8...0x00FF, // Latin-1 Supplement
                 0x0100...0x024F,  // Latin Extended-A & B
                 0x0370...0x03FF,  // Greek
                 0x0400...0x04FF:  // Cyrillic
                return .leftToRight
            default:
                continue
            }
        }
        return nil
    }
}

struct KaraokeLyricsDto: Equatable {
    var timingLabel: String {
        let timed = lines.filter(\.hasWordTiming).count
        if timed == 0 { return "Line sync" }
        return timed == lines.count ? "Word sync" : "Partial word sync"
    }

    func activeLineIndex(at position: Int, requiresActiveInterval: Bool = false) -> Int? {
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lines[middle].startMs <= position { lower = middle + 1 }
            else { upper = middle }
        }
        guard lower > 0 else { return nil }
        let index = lower - 1
        return requiresActiveInterval && position >= lines[index].endMs ? nil : index
    }

    /// Keep the last line through short breaks between lines. Word highlighting
    /// still follows the provider's exact timestamps.
    func previewLineIndex(at position: Int) -> Int? {
        guard let index = activeLineIndex(at: position) else { return nil }
        let line = lines[index]
        if position < line.endMs { return index }
        guard index + 1 < lines.count, position - line.endMs < 4_000 else { return nil }
        return index
    }

    var lines: [KaraokeLineDto]

    var isRTL: Bool {
        var rtl = 0, ltr = 0
        for line in lines {
            switch line.strongDirection {
            case .rightToLeft: rtl += 1
            case .leftToRight: ltr += 1
            case nil: continue
            }
        }
        return rtl > ltr
    }

    var songWriters: [String]
    var providerCode: String?
    /// Display name for the credits footer. Nil keeps the old behaviour (Spicy Lyrics when `providerCode` is set).
    var providerName: String? = nil
    var uploaderName: String? = nil
    var uploaderUrl: String? = nil
    var makerName: String? = nil
    var makerUrl: String? = nil
}

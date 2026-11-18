import SwiftUI

struct KaraokeLineLayout {
    let words: [[KaraokeSyllableDto]]
    let isRTL: Bool
}

extension KaraokeTextAlignment {
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

@available(iOS 15.0, *)
struct KaraokeLineView: View {
    let layout: KaraokeLineLayout
    let currentMs: Int
    let isActiveLine: Bool
    let availableWidth: CGFloat
    let alignment: HorizontalAlignment
    var fontSize: CGFloat = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        KaraokeFlowLayout(spacing: 8, alignment: alignment) {
            ForEach(Array(layout.words.enumerated()), id: \.offset) { _, word in
                KaraokeWordView(syllables: word, currentMs: currentMs, isActiveLine: isActiveLine, isRTL: layout.isRTL, fontSize: fontSize)
            }
        }
        .frame(width: availableWidth)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)

        .scaleEffect(reduceMotion ? 1 : (isActiveLine ? 1.015 : 1), anchor: .center)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isActiveLine)
        // Mirrors word/row order for RTL lines; the fill gradient is flipped separately below.
        .environment(\.layoutDirection, layout.isRTL ? .rightToLeft : .leftToRight)
    }


}

@available(iOS 15.0, *)
private struct KaraokeWordView: View {
    let syllables: [KaraokeSyllableDto]
    let currentMs: Int
    let isActiveLine: Bool
    let isRTL: Bool

    let fontSize: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var wordStartMs: Int { syllables.first?.startMs ?? 0 }
    private var wordEndMs: Int { syllables.last?.endMs ?? wordStartMs }

    private var wordProgress: Double {
        guard isActiveLine, wordEndMs > wordStartMs else {
            return currentMs >= wordEndMs ? 1 : 0
        }
        return KaraokeTiming.progress(position: currentMs, start: wordStartMs, end: wordEndMs)
    }

    private var scale: Double { KaraokeAnimationCurve.wordScale.value(at: wordProgress) }
    private var glow: Double { KaraokeAnimationCurve.glow.value(at: wordProgress) }
    private var yOffsetFraction: Double { KaraokeAnimationCurve.yOffset.value(at: wordProgress) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(syllables.enumerated()), id: \.offset) { _, syllable in
                KaraokeSyllableTextView(
                    syllable: syllable,
                    currentMs: currentMs,
                    isActiveLine: isActiveLine,
                    isRTL: isRTL,
                    fontSize: fontSize
                )
            }
        }
        .scaleEffect(reduceMotion ? 1 : scale)
        // Keep the emphasis proportional to the selected type size.
        .offset(y: reduceMotion ? 0 : CGFloat(yOffsetFraction) * fontSize)
        .shadow(color: .white.opacity(glow * 0.36), radius: CGFloat(glow * 3))
    }
}

@available(iOS 15.0, *)
private struct KaraokeSyllableTextView: View {
    let syllable: KaraokeSyllableDto
    let currentMs: Int
    let isActiveLine: Bool
    let isRTL: Bool

    let fontSize: CGFloat

    // LinearGradient never mirrors .leading/.trailing for RTL, so pick the physical edges here.
    private var gradientStart: UnitPoint { isRTL ? .trailing : .leading }
    private var gradientEnd: UnitPoint { isRTL ? .leading : .trailing }

    private var progress: Double {
        guard isActiveLine, syllable.endMs > syllable.startMs else {
            return currentMs >= syllable.endMs ? 1 : 0
        }
        return KaraokeTiming.progress(position: currentMs, start: syllable.startMs, end: syllable.endMs)
    }

    var body: some View {
        Text(syllable.text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(isActiveLine ? 1 : KaraokeReadability.surroundingTextOpacity), location: 0),
                        .init(color: .white.opacity(isActiveLine ? 1 : KaraokeReadability.surroundingTextOpacity), location: progress),
                        .init(color: .white.opacity(isActiveLine ? KaraokeReadability.unsungTextOpacity : KaraokeReadability.surroundingTextOpacity), location: progress),
                        .init(color: .white.opacity(isActiveLine ? KaraokeReadability.unsungTextOpacity : KaraokeReadability.surroundingTextOpacity), location: 1),
                    ],
                    startPoint: gradientStart,
                    endPoint: gradientEnd
                )
            )
    }
}

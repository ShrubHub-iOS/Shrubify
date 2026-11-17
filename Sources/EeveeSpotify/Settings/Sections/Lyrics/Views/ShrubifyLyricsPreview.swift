import SwiftUI

/// Inspired by Evolved's production-renderer preview; uses original sample text.
@available(iOS 16.0, *)
struct ShrubifyLyricsPreview: View {
    let options: KaraokeOptions

    private func layout(_ text: String) -> KaraokeLineLayout {
        let words = text.split(separator: " ").enumerated().map { index, word in
            [KaraokeSyllableDto(text: String(word), startMs: index * 1000,
                endMs: (index + 1) * 1000, isPartOfWord: false)]
        }
        return KaraokeLineLayout(words: words, isRTL: false)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: CGFloat(options.resolvedLineSpacing)) {
                    previewLine("Find your rhythm", active: true, width: geometry.size.width)
                    previewLine("Stay a little longer", active: false, width: geometry.size.width)
                }
                .padding(.vertical, 16)
            }
            .allowsHitTesting(false)
            .background(LinearGradient(colors: [EeveeTheme.accent.opacity(0.3), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(height: 280)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lyrics typography preview")
        .accessibilityValue("\(Int(options.resolvedFontSize)) point text, \(Int(options.resolvedLineSpacing)) point spacing")
    }

    private func previewLine(_ text: String, active: Bool, width: CGFloat) -> some View {
        KaraokeLineView(layout: layout(text), currentMs: 1400, isActiveLine: active,
            availableWidth: max(0, width - 48), alignment: options.textAlignment.horizontalAlignment,
            fontSize: CGFloat(options.resolvedFontSize))
    }
}

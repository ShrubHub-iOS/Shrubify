import Foundation

enum KaraokeTextAlignment: String, Codable, CaseIterable {
    case leading
    case center
    case trailing

    var displayName: String {
        "karaoke_alignment_\(rawValue)".localized
    }
}

struct KaraokeOptions: Codable, Hashable {
    var textAlignment: KaraokeTextAlignment = .center
    var reversedDirection = false
    var enabled = true
    var customLyricsOnly = false
    var blurIntensity: Double = 1.5
    var timingOffsetMs = 0
    var fontSize: Double = 30
    var lineSpacing: Double = 16

    var resolvedBlurRadius: Double { Self.clamp(blurIntensity, to: 0...4, fallback: 1.5) * 10 }
    var resolvedFontSize: Double { Self.clamp(fontSize, to: 22...40, fallback: 30) }
    var resolvedLineSpacing: Double { Self.clamp(lineSpacing, to: 8...32, fallback: 16) }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

    init(textAlignment: KaraokeTextAlignment = .center, reversedDirection: Bool = false, enabled: Bool = true, blurIntensity: Double = 1.5) {
        self.textAlignment = textAlignment
        self.reversedDirection = reversedDirection
        self.enabled = enabled
        self.blurIntensity = blurIntensity
    }

    private enum CodingKeys: String, CodingKey {
        case textAlignment, reversedDirection, enabled, blurIntensity, customLyricsOnly, timingOffsetMs, fontSize, lineSpacing
    }

    // Settings saved before these fields existed must keep decoding.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textAlignment = try container.decodeIfPresent(KaraokeTextAlignment.self, forKey: .textAlignment) ?? .center
        reversedDirection = try container.decodeIfPresent(Bool.self, forKey: .reversedDirection) ?? false
        customLyricsOnly = try container.decodeIfPresent(Bool.self, forKey: .customLyricsOnly) ?? false
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        timingOffsetMs = ShrubifyBetaSupport.timingOffset(try container.decodeIfPresent(Int.self, forKey: .timingOffsetMs) ?? 0)
        fontSize = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 30, to: 22...40, fallback: 30)
        lineSpacing = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 16, to: 8...32, fallback: 16)
        blurIntensity = Self.clamp(try container.decodeIfPresent(Double.self, forKey: .blurIntensity) ?? 1.5, to: 0...4, fallback: 1.5)
    }
}

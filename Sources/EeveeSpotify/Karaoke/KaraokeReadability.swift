import Foundation

/// Cap the artwork's linear-light luminance while preserving hue. This gives
/// text a contrast floor across the whole background without black containers.
enum KaraokeReadability {
    static let maximumBackgroundLuminance = 0.10
    static let unsungTextOpacity = 0.64
    static let surroundingTextOpacity = 0.82

    static func linear(_ channel: Double) -> Double {
        let c = min(1, max(0, channel.isFinite ? channel : 0))
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    static func encoded(_ channel: Double) -> Double {
        channel <= 0.0031308 ? channel * 12.92 : 1.055 * pow(channel, 1 / 2.4) - 0.055
    }
    static func toneMap(red: Double, green: Double, blue: Double) -> (red: Double, green: Double, blue: Double) {
        let r = linear(red), g = linear(green), b = linear(blue)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let scale = luminance > maximumBackgroundLuminance ? maximumBackgroundLuminance / luminance : 1
        return (encoded(r * scale), encoded(g * scale), encoded(b * scale))
    }
}

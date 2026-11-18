import UIKit

/// Work on a small sRGB thumbnail once per artwork update, off the main thread.
/// Blur and the Metal renderer only blend these capped colors; they add no light.
enum KaraokeArtworkToneMap {
    static func image(from source: UIImage) -> UIImage? {
        let side = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        let thumbnail = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.black.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: side, height: side))
            source.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let sourceImage = thumbnail.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let rendered = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: space, bitmapInfo: info) else { return false }
            context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return nil }
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = KaraokeReadability.toneMap(red: Double(pixels[index]) / 255,
                green: Double(pixels[index + 1]) / 255, blue: Double(pixels[index + 2]) / 255)
            pixels[index] = UInt8(min(255, max(0, floor(color.red * 255))))
            pixels[index + 1] = UInt8(min(255, max(0, floor(color.green * 255))))
            pixels[index + 2] = UInt8(min(255, max(0, floor(color.blue * 255))))
            pixels[index + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: side * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: info),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: image)
    }
}

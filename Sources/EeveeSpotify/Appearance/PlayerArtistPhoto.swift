import UIKit
import ImageIO

enum PlayerArtistPhoto {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 12
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    static func artistID(from uri: String?) -> String? {
        guard let uri, uri.hasPrefix("spotify:artist:") else { return nil }
        let id = String(uri.dropFirst("spotify:artist:".count))
        return id.range(of: #"^[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil ? id : nil
    }

    @MainActor
    static func load(id: String, biography: @escaping @MainActor (String?) -> Void,
                     completion: @escaping @MainActor (UIImage?) -> Void) {
        let cachedImage = cache.object(forKey: id as NSString)
        if let cachedImage { completion(cachedImage) }
        guard let profile = URL(string: "https://open.spotify.com/artist/\(id)") else {
            biography(nil)
            if cachedImage == nil { completion(nil) }
            return
        }
        session.dataTask(with: profile) { data, response, _ in
            guard let data, data.count <= 1_000_000,
                  let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.url?.host == "open.spotify.com", response.url?.lastPathComponent == id,
                  let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    biography(nil)
                    if cachedImage == nil { completion(nil) }
                }
                return
            }
            let bio = SpotifyArtistBiography.extract(from: html)
            DispatchQueue.main.async { biography(bio) }
            guard cachedImage == nil else { return }
            guard let url = imageURL(in: html) else { DispatchQueue.main.async { completion(nil) }; return }
            session.dataTask(with: url) { data, response, _ in
                var photo: UIImage?
                if let data, data.count <= 4_000_000, let response = response as? HTTPURLResponse,
                   response.statusCode == 200, response.url?.host == "i.scdn.co",
                   let source = CGImageSourceCreateWithData(data as CFData, nil),
                   let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 960
                   ] as CFDictionary) {
                    let image = UIImage(cgImage: bitmap)
                    photo = image
                    cache.setObject(image, forKey: id as NSString, cost: bitmap.bytesPerRow * bitmap.height)
                }
                let image = photo
                DispatchQueue.main.async { completion(image) }
            }.resume()
        }.resume()
    }

    static func imageURL(in html: String) -> URL? {
        let pattern = #"<meta\s+property="og:image"\s+content="(https://i\.scdn\.co/image/[A-Za-z0-9]+)"\s*/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return URL(string: String(html[range]))
    }
}

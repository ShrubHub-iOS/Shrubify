import UIKit
import Combine

final class ImageViewModel: ObservableObject {
    @Published private(set) var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()
    private var task: URLSessionDataTask?

    init(urlString: String?) {
        guard let raw = urlString,
              let url = URL(string: raw), url.scheme == "https" else { return }
        if let cached = Self.cache.object(forKey: raw as NSString) {
            image = cached
            return
        }
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let data = data, data.count < 3_000_000,
                  let picture = UIImage(data: data) else { return }
            Self.cache.setObject(picture, forKey: raw as NSString)
            DispatchQueue.main.async { [weak self] in self?.image = picture }
        }
        task?.resume()
    }

    deinit { task?.cancel() }
}

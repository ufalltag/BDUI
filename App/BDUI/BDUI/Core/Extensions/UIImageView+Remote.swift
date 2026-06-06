import UIKit

private let remoteImageCache = NSCache<NSString, UIImage>()

extension UIImageView {
    /// Loads a remote image, caching the decoded result by URL.
    func setRemoteImage(_ urlString: String) {
        if let cached = remoteImageCache.object(forKey: urlString as NSString) {
            image = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            remoteImageCache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async { self?.image = image }
        }.resume()
    }
}

/// Renders a 0–5 rating as filled/empty stars.
func starString(for rating: Double, max: Int = 5) -> String {
    let full = Int(rating.rounded())
    return String(repeating: "★", count: min(full, max)) +
           String(repeating: "☆", count: Swift.max(0, max - full))
}

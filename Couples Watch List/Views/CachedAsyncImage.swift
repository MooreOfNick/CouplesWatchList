import SwiftUI
import UIKit

private final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 150
        c.totalCostLimit = 75 * 1024 * 1024
        return c
    }()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            uiImage = await load(url)
        }
    }

    private func load(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let cached = ImageCache.shared.image(for: url) { return cached }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        ImageCache.shared.store(image, for: url)
        return image
    }
}

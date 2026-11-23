import UIKit
import Photos

/// A small, thread-safe image pipeline on top of `PHCachingImageManager`.
/// It keeps decoded thumbnails in an `NSCache` so a swipe never waits on disk,
/// and it tells PhotoKit to warm up the next pages before the user gets there.
final class ImageStore {
    static let shared = ImageStore()

    private let manager = PHCachingImageManager()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 28
        cache.totalCostLimit = 180 * 1024 * 1024
    }

    static var screenScale: CGFloat {
        UIScreen.main.scale
    }

    static func target(for size: CGSize) -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: max(size.width, 1) * scale,
                      height: max(size.height, 1) * scale)
    }

    private func key(_ asset: PHAsset, _ size: CGSize) -> NSString {
        let w = Int(size.width.rounded())
        let h = Int(size.height.rounded())
        return "\(asset.localIdentifier)|\(w)x\(h)" as NSString
    }

    func cached(for asset: PHAsset, target: CGSize) -> UIImage? {
        cache.object(forKey: key(asset, target))
    }

    func load(for asset: PHAsset, target: CGSize, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = key(asset, target)
        if let hit = cache.object(forKey: cacheKey) {
            completion(hit)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        manager.requestImage(for: asset,
                             targetSize: target,
                             contentMode: .aspectFit,
                             options: options) { [weak self] image, _ in
            guard let self, let image else { return }
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            self.cache.setObject(image, forKey: cacheKey, cost: cost)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Warms PhotoKit's own cache for the pages the user is about to reach.
    func prefetch(_ assets: [PHAsset], target: CGSize) {
        guard !assets.isEmpty else { return }
        manager.startCachingImages(for: assets,
                                   targetSize: target,
                                   contentMode: .aspectFit,
                                   options: nil)
    }
}

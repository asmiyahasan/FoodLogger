import CoreGraphics
import Foundation
import SwiftData

/// Small decoded meal photos kept in memory, so lists don't decode full photos on every redraw.
/// A meal's photo never changes after it's saved, so the meal's ID is a safe key.
enum ThumbnailCache {
    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.countLimit = 300
        return cache
    }()

    private static func key(for meal: Meal) -> NSString {
        String(describing: meal.persistentModelID) as NSString
    }

    static func cached(for meal: Meal) -> CGImage? {
        cache.object(forKey: key(for: meal))
    }

    /// Returns the thumbnail, decoding it in the background the first time.
    static func thumbnail(for meal: Meal) async -> CGImage? {
        let key = key(for: meal)
        if let hit = cache.object(forKey: key) { return hit }
        guard let data = meal.photo else { return nil }
        let image = await Task.detached(priority: .userInitiated) {
            DecodedImage(ImagePrep.thumbnail(data, maxPixelSize: 144))   // 48 pt at 3x
        }.value.image
        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}

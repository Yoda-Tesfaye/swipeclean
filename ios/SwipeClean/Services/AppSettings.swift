import Foundation
import SwiftUI
import Combine

/// User preferences: batch size per mode and haptic feedback.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var photoBatch: Int {
        didSet { defaults.set(photoBatch, forKey: Keys.photoBatch) }
    }

    @Published var videoBatch: Int {
        didSet { defaults.set(videoBatch, forKey: Keys.videoBatch) }
    }

    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Keys.haptics) }
    }

    private enum Keys {
        static let photoBatch = "settings.batch.photos"
        static let videoBatch = "settings.batch.videos"
        static let haptics = "settings.haptics"
    }

    private let defaults = UserDefaults.standard

    private init() {
        photoBatch = defaults.object(forKey: Keys.photoBatch) as? Int ?? 30
        videoBatch = defaults.object(forKey: Keys.videoBatch) as? Int ?? 30
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    }

    func batch(for mode: AssetMode) -> Int {
        switch mode {
        case .photos: return photoBatch
        case .videos: return videoBatch
        }
    }

    func setBatch(_ value: Int, for mode: AssetMode) {
        let clamped = min(max(value, 5), 100)
        switch mode {
        case .photos: photoBatch = clamped
        case .videos: videoBatch = clamped
        }
    }

    static let batchChoices = [10, 15, 20, 30, 50]
}

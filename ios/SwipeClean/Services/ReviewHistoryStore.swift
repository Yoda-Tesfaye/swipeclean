import Foundation

enum AssetMode: String, CaseIterable, Identifiable {
    case photos
    case videos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: return "照片"
        case .videos: return "视频"
        }
    }

    var pluralTitle: String {
        switch self {
        case .photos: return "照片"
        case .videos: return "视频"
        }
    }
}

/// Remembers which assets were already reviewed so a second launch never shows
/// them again. Persisted as a small JSON file inside Application Support.
final class ReviewHistoryStore {
    static let shared = ReviewHistoryStore()

    private struct Payload: Codable {
        var photos: [String]
        var videos: [String]
    }

    private var viewed: [AssetMode: Set<String>] = [.photos: [], .videos: []]
    private var saveWork: DispatchWorkItem?
    private let fileURL: URL

    private init() {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("SwipeClean", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("viewed.json")
        loadFromDisk()
    }

    // MARK: - Queries

    func isViewed(_ identifier: String, mode: AssetMode) -> Bool {
        viewed[mode]?.contains(identifier) ?? false
    }

    func count(mode: AssetMode) -> Int {
        viewed[mode]?.count ?? 0
    }

    // MARK: - Mutations

    func markViewed(_ identifier: String, mode: AssetMode) {
        var set = viewed[mode] ?? []
        guard !set.contains(identifier) else { return }
        set.insert(identifier)
        viewed[mode] = set
        scheduleSave()
    }

    func unmarkViewed(_ identifier: String, mode: AssetMode) {
        guard var set = viewed[mode], set.remove(identifier) != nil else { return }
        viewed[mode] = set
        scheduleSave()
    }

    func remove(_ identifiers: Set<String>, mode: AssetMode) {
        guard var set = viewed[mode], !set.isEmpty else { return }
        set.subtract(identifiers)
        viewed[mode] = set
        scheduleSave()
    }

    /// Drops identifiers whose assets no longer exist (deleted elsewhere).
    func prune(mode: AssetMode, valid: Set<String>) {
        guard var set = viewed[mode], !set.isEmpty else { return }
        let pruned = set.intersection(valid)
        guard pruned.count != set.count else { return }
        set = pruned
        viewed[mode] = set
        scheduleSave()
    }

    func resetAll() {
        viewed = [.photos: [], .videos: []]
        saveNow()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func saveNow() {
        let payload = Payload(photos: Array(viewed[.photos] ?? []),
                              videos: Array(viewed[.videos] ?? []))
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Losing history is not worth crashing over.
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }
        viewed[.photos] = Set(payload.photos)
        viewed[.videos] = Set(payload.videos)
    }
}

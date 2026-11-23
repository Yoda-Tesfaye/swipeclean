import Foundation
import Photos
import SwiftUI
import UIKit
import Combine

struct BatchPrompt: Identifiable {
    let id = UUID()
}

/// Owns the whole review session: the library snapshot, the cursor, the
/// "to delete" bin, the 30-item checkpoint rhythm and the undo history.
final class ReviewEngine: ObservableObject {

    enum Phase: Equatable {
        case starting
        case needsPermission
        case denied
        case ready
        case empty
        case finished
    }

    let batchSize = 30

    // MARK: - Published state

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var items: [PHAsset] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var bin: [PHAsset] = []
    @Published private(set) var reviewedCount: Int = 0
    @Published private(set) var deletedCount: Int = 0
    @Published private(set) var reviewedInBatch: Int = 0
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var isDeleting: Bool = false
    @Published var pendingBatch: BatchPrompt?
    @Published var toast: String?

    // MARK: - Private state

    private var history: [(index: Int, binned: Bool)] = []
    private var toastWork: DispatchWorkItem?

    // MARK: - Derived state

    var current: PHAsset? {
        guard index >= 0, index < items.count else { return nil }
        return items[index]
    }

    var remaining: Int {
        max(items.count - index, 0)
    }

    var progress: Double {
        let total = reviewedCount + remaining
        guard total > 0 else { return 0 }
        return min(max(Double(reviewedCount) / Double(total), 0), 1)
    }

    var keptCount: Int {
        max(reviewedCount - deletedCount - bin.count, 0)
    }

    // MARK: - Lifecycle

    func start() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            loadLibrary()
        case .notDetermined:
            phase = .needsPermission
        default:
            phase = .denied
        }
    }

    /// Called when the app comes back to the foreground (for example after the
    /// user granted access in Settings).
    func recheck() {
        guard phase == .denied || phase == .needsPermission else { return }
        start()
    }

    func requestAccess() {
        phase = .starting
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                if status == .authorized || status == .limited {
                    self.loadLibrary()
                } else {
                    self.phase = .denied
                }
            }
        }
    }

    func loadLibrary() {
        phase = .starting
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d",
                                       PHAssetMediaType.image.rawValue,
                                       PHAssetMediaType.video.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var list: [PHAsset] = []
        list.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            list.append(asset)
        }

        items = list
        index = 0
        reviewedCount = 0
        deletedCount = 0
        reviewedInBatch = 0
        bin.removeAll()
        history.removeAll()
        canUndo = false
        pendingBatch = nil
        phase = list.isEmpty ? .empty : .ready
        prefetchNeighbours()
        Haptics.prepare()
    }

    func rescan() {
        loadLibrary()
    }

    // MARK: - Navigation

    func moveForward() {
        guard phase == .ready, index < items.count else { return }
        history.append((index: index, binned: false))
        reviewedCount += 1
        reviewedInBatch += 1
        index += 1
        prefetchNeighbours()
        evaluatePosition()
    }

    func moveBackward() {
        guard phase == .ready, index > 0 else { return }
        index -= 1
        if let last = history.last, last.index == index {
            history.removeLast()
            reviewedCount = max(reviewedCount - 1, 0)
            reviewedInBatch = max(reviewedInBatch - 1, 0)
            if last.binned {
                removeBin(at: index)
            }
        }
        canUndo = !bin.isEmpty
        prefetchNeighbours()
    }

    func markCurrentForDeletion() {
        guard phase == .ready, let asset = current else { return }
        bin.append(asset)
        history.append((index: index, binned: true))
        reviewedCount += 1
        reviewedInBatch += 1
        index += 1
        canUndo = true
        prefetchNeighbours()
        evaluatePosition()
    }

    func undoLastAction() {
        guard let asset = bin.last else { return }
        bin.removeLast()
        let id = asset.localIdentifier
        if let target = items.firstIndex(where: { $0.localIdentifier == id }) {
            index = target
            if let historyIndex = history.lastIndex(where: { $0.index == target && $0.binned }) {
                history.remove(at: historyIndex)
            }
            reviewedCount = max(reviewedCount - 1, 0)
            reviewedInBatch = max(reviewedInBatch - 1, 0)
        }
        canUndo = !bin.isEmpty
        prefetchNeighbours()
        showToast("已撤销")
    }

    func removeBin(_ asset: PHAsset) {
        bin.removeAll { $0.localIdentifier == asset.localIdentifier }
        canUndo = !bin.isEmpty
    }

    func removeBin(at itemIndex: Int) {
        guard itemIndex >= 0, itemIndex < items.count else { return }
        let id = items[itemIndex].localIdentifier
        bin.removeAll { $0.localIdentifier == id }
        canUndo = !bin.isEmpty
    }

    // MARK: - Batch checkpoint

    private func evaluatePosition() {
        if index >= items.count {
            scheduleFinish()
            return
        }

        guard reviewedInBatch >= batchSize else { return }

        if bin.isEmpty {
            reviewedInBatch = 0
            return
        }

        guard pendingBatch == nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            guard self.pendingBatch == nil,
                  self.phase == .ready,
                  !self.bin.isEmpty,
                  self.reviewedInBatch >= self.batchSize else { return }
            Haptics.warning()
            self.pendingBatch = BatchPrompt()
        }
    }

    private func scheduleFinish() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            guard self.index >= self.items.count else { return }
            self.phase = .finished
        }
    }

    func skipBatch() {
        pendingBatch = nil
        reviewedInBatch = 0
    }

    func confirmBatchDeletion() {
        let assets = bin
        pendingBatch = nil
        reviewedInBatch = 0
        guard !assets.isEmpty else { return }
        delete(assets)
    }

    func deleteAllBin() {
        let assets = bin
        pendingBatch = nil
        reviewedInBatch = 0
        guard !assets.isEmpty else { return }
        delete(assets)
    }

    // MARK: - Deletion

    private func delete(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        isDeleting = true
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isDeleting = false
                if success {
                    self.applyDeletion(assets)
                } else {
                    Haptics.warning()
                    self.showToast(error?.localizedDescription ?? "删除失败，请稍后重试")
                }
            }
        }
    }

    private func applyDeletion(_ assets: [PHAsset]) {
        let ids = Set(assets.map { $0.localIdentifier })
        let currentID = current?.localIdentifier

        items.removeAll { ids.contains($0.localIdentifier) }
        bin.removeAll { ids.contains($0.localIdentifier) }
        history.removeAll()
        canUndo = !bin.isEmpty
        deletedCount += assets.count

        if let currentID, let newIndex = items.firstIndex(where: { $0.localIdentifier == currentID }) {
            index = newIndex
        } else {
            index = min(index, items.count)
        }

        if index >= items.count || items.isEmpty {
            phase = .finished
        } else {
            phase = .ready
        }

        prefetchNeighbours()
        Haptics.success()
        showToast("已删除 \(assets.count) 项")

        if phase == .ready, reviewedInBatch >= batchSize, !bin.isEmpty {
            evaluatePosition()
        }
    }

    // MARK: - Prefetch

    private func prefetchNeighbours() {
        guard !items.isEmpty else { return }
        let lower = max(index - 1, 0)
        let upper = min(index + 2, items.count - 1)
        guard lower <= upper else { return }
        let window = Array(items[lower...upper])
        let target = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        ImageStore.shared.prefetch(window, target: ImageStore.target(for: target))
    }

    // MARK: - Toast

    func showToast(_ text: String) {
        toastWork?.cancel()
        toast = text
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self.toast = nil
            }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }
}

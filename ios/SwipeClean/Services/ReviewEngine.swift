import Foundation
import Photos
import SwiftUI
import UIKit
import Combine

struct BatchPrompt: Identifiable {
    let id = UUID()
}

/// One review deck: either photos or videos. Owns the shuffled unseen queue,
/// the "to delete" bin, the 30-item checkpoint rhythm and the undo stack.
final class ReviewEngine: ObservableObject {

    enum Phase: Equatable {
        case loading
        case ready
        case finished
        case empty
    }

    let mode: AssetMode
    @Published var batchSize: Int = 30
    private let history: ReviewHistoryStore

    // MARK: - Published state

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var items: [PHAsset] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var bin: [PHAsset] = []
    @Published private(set) var batchCandidates: [PHAsset] = []
    @Published private(set) var reviewedCount: Int = 0
    @Published private(set) var reviewedInBatch: Int = 0
    @Published private(set) var deletedCount: Int = 0
    @Published private(set) var historyCount: Int = 0
    @Published private(set) var totalInLibrary: Int = 0
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var isDeleting: Bool = false
    @Published var pendingBatch: BatchPrompt?
    @Published var toast: String?

    // MARK: - Private state

    private var stack: [(index: Int, binned: Bool)] = []
    private var toastWork: DispatchWorkItem?

    // MARK: - Init

    init(mode: AssetMode, history: ReviewHistoryStore = .shared) {
        self.mode = mode
        self.history = history
    }

    // MARK: - Derived state

    var current: PHAsset? {
        guard index >= 0, index < items.count else { return nil }
        return items[index]
    }

    var remaining: Int {
        guard index < items.count else { return 0 }
        let selected = Set(bin.map(\.localIdentifier))
        return items[index...].reduce(into: 0) { count, asset in
            if !selected.contains(asset.localIdentifier) { count += 1 }
        }
    }

    var progress: Double {
        let total = reviewedCount + remaining
        guard total > 0 else { return 0 }
        return min(max(Double(reviewedCount) / Double(total), 0), 1)
    }

    var isReady: Bool { phase == .ready }

    // MARK: - Loading

    func load() {
        phase = .loading
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", mediaTypeValue)

        let result = PHAsset.fetchAssets(with: options)
        var all: [PHAsset] = []
        all.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            all.append(asset)
        }

        let allIdentifiers = Set(all.map { $0.localIdentifier })
        history.prune(mode: mode, valid: allIdentifiers)

        let unseen = all.filter { !history.isViewed($0.localIdentifier, mode: mode) }

        totalInLibrary = all.count
        items = unseen.shuffled()
        index = 0
        reviewedCount = 0
        reviewedInBatch = 0
        deletedCount = 0
        bin.removeAll()
        batchCandidates.removeAll()
        stack.removeAll()
        canUndo = false
        pendingBatch = nil
        historyCount = history.count(mode: mode)

        if all.isEmpty {
            phase = .empty
        } else if items.isEmpty {
            phase = .finished
        } else {
            phase = .ready
        }
        prefetchNeighbours()
        Haptics.prepare()
    }

    func reload() {
        load()
    }

    private var mediaTypeValue: Int {
        switch mode {
        case .photos: return PHAssetMediaType.image.rawValue
        case .videos: return PHAssetMediaType.video.rawValue
        }
    }

    // MARK: - Navigation

    func moveForward() {
        guard phase == .ready, let asset = current else { return }
        history.markViewed(asset.localIdentifier, mode: mode)
        stack.append((index: index, binned: false))
        reviewedCount += 1
        reviewedInBatch += 1
        index = nextAvailableIndex(after: index) ?? items.count
        refreshHistoryCount()
        prefetchNeighbours()
        evaluatePosition()
    }

    func moveBackward() {
        guard let target = previousAvailableIndex(before: index) else { return }
        index = target
        if let stackIndex = stack.lastIndex(where: { $0.index == target }), !stack[stackIndex].binned {
            stack.remove(at: stackIndex)
            reviewedCount = max(reviewedCount - 1, 0)
            reviewedInBatch = max(reviewedInBatch - 1, 0)
        }
        if let asset = current {
            history.unmarkViewed(asset.localIdentifier, mode: mode)
        }
        refreshHistoryCount()
        prefetchNeighbours()
    }

    func markCurrentForDeletion() {
        guard phase == .ready, let asset = current else { return }
        history.markViewed(asset.localIdentifier, mode: mode)
        bin.append(asset)
        batchCandidates.append(asset)
        stack.append((index: index, binned: true))
        reviewedCount += 1
        reviewedInBatch += 1
        index = nextAvailableIndex(after: index - 1) ?? items.count
        canUndo = true
        refreshHistoryCount()
        prefetchNeighbours()
        evaluatePosition()
    }

    func undoLastAction() {
        guard let asset = bin.last else { return }
        bin.removeLast()
        let identifier = asset.localIdentifier
        if let target = items.firstIndex(where: { $0.localIdentifier == identifier }) {
            index = target
            if let stackIndex = stack.lastIndex(where: { $0.index == target && $0.binned }) {
                stack.remove(at: stackIndex)
            }
            history.unmarkViewed(identifier, mode: mode)
            reviewedCount = max(reviewedCount - 1, 0)
            reviewedInBatch = max(reviewedInBatch - 1, 0)
        }
        canUndo = !bin.isEmpty
        refreshHistoryCount()
        prefetchNeighbours()
        showToast("已撤销")
    }

    func previousAvailableIndex(before position: Int) -> Int? {
        guard position > 0 else { return nil }
        let selected = Set(bin.map(\.localIdentifier))
        for candidate in stride(from: min(position - 1, items.count - 1), through: 0, by: -1) {
            if !selected.contains(items[candidate].localIdentifier) { return candidate }
        }
        return nil
    }

    func nextAvailableIndex(after position: Int) -> Int? {
        guard position + 1 < items.count else { return nil }
        let selected = Set(bin.map(\.localIdentifier))
        for candidate in (position + 1)..<items.count {
            if !selected.contains(items[candidate].localIdentifier) { return candidate }
        }
        return nil
    }

    func removeBin(_ asset: PHAsset) {
        bin.removeAll { $0.localIdentifier == asset.localIdentifier }
        canUndo = !bin.isEmpty
    }

    func toggleBatchSelection(_ asset: PHAsset) {
        if bin.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            removeBin(asset)
        } else if batchCandidates.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            bin.append(asset)
            canUndo = true
        }
    }

    func removeBin(at itemIndex: Int) {
        guard itemIndex >= 0, itemIndex < items.count else { return }
        let identifier = items[itemIndex].localIdentifier
        bin.removeAll { $0.localIdentifier == identifier }
        canUndo = !bin.isEmpty
    }

    // MARK: - Batch checkpoint

    private func evaluatePosition() {
        if reviewedInBatch >= batchSize, !bin.isEmpty, pendingBatch == nil {
            scheduleBatchPrompt()
            return
        }

        if index >= items.count {
            scheduleFinish()
            return
        }

        if reviewedInBatch >= batchSize {
            reviewedInBatch = 0
        }
    }

    private func scheduleBatchPrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            guard self.pendingBatch == nil,
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
        if index >= items.count {
            phase = .finished
        }
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
        let identifiers = Set(assets.map { $0.localIdentifier })
        let currentIdentifier = current?.localIdentifier

        items.removeAll { identifiers.contains($0.localIdentifier) }
        bin.removeAll { identifiers.contains($0.localIdentifier) }
        batchCandidates.removeAll { identifiers.contains($0.localIdentifier) }
        historyCount = history.count(mode: mode)
        deletedCount += assets.count
        stack.removeAll()
        canUndo = !bin.isEmpty

        if let currentIdentifier, let newIndex = items.firstIndex(where: { $0.localIdentifier == currentIdentifier }) {
            index = newIndex
        } else {
            index = min(index, items.count)
        }

        if items.isEmpty {
            phase = totalInLibrary == 0 ? .empty : .finished
        } else if index >= items.count {
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

    // MARK: - Helpers

    private func refreshHistoryCount() {
        historyCount = history.count(mode: mode)
    }

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

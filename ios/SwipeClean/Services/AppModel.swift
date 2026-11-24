import Foundation
import Photos
import SwiftUI
import UIKit
import Combine

enum HomeTab: String, CaseIterable, Identifiable, Hashable {
    case photos
    case videos
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: return "照片"
        case .videos: return "视频"
        case .settings: return "设置"
        }
    }

    var symbol: String {
        switch self {
        case .photos: return "photo"
        case .videos: return "play.rectangle"
        case .settings: return "gearshape"
        }
    }
}

final class AppModel: ObservableObject {

    enum Auth: Equatable {
        case checking
        case request
        case denied
        case ready
    }

    @Published private(set) var auth: Auth = .checking
    @Published var tab: HomeTab = .photos
    @Published var toast: String?

    let history = ReviewHistoryStore.shared
    let settings = AppSettings.shared
    let photos: ReviewEngine
    let videos: ReviewEngine

    private var toastWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init() {
        photos = ReviewEngine(mode: .photos, history: history)
        videos = ReviewEngine(mode: .videos, history: history)

        Haptics.enabled = settings.haptics
        photos.batchSize = settings.photoBatch
        videos.batchSize = settings.videoBatch

        settings.$photoBatch
            .sink { [weak self] value in
                self?.photos.batchSize = value
            }
            .store(in: &cancellables)

        settings.$videoBatch
            .sink { [weak self] value in
                self?.videos.batchSize = value
            }
            .store(in: &cancellables)

        settings.$haptics
            .sink { value in
                Haptics.enabled = value
            }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    func start() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            activate()
        case .notDetermined:
            auth = .request
        default:
            auth = .denied
        }
    }

    func requestAccess() {
        auth = .checking
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                if status == .authorized || status == .limited {
                    self.activate()
                } else {
                    self.auth = .denied
                }
            }
        }
    }

    func recheck() {
        guard auth != .ready else { return }
        start()
    }

    private func activate() {
        auth = .ready
        photos.load()
        videos.load()
    }

    // MARK: - History

    func reloadAll() {
        photos.load()
        videos.load()
    }

    func resetHistory() {
        history.resetAll()
        reloadAll()
        showToast("浏览记录已重置")
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

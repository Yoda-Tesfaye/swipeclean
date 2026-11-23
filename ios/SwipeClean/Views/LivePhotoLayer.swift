import SwiftUI
import Photos
import PhotosUI
import UIKit

/// Plays the motion + audio of a Live Photo through `PHLivePhotoView`.
struct LivePhotoLayer: View {
    let asset: PHAsset

    @StateObject private var loader = LivePhotoLoader()

    var body: some View {
        LivePhotoSurface(livePhoto: loader.livePhoto)
            .onAppear { loader.load(asset) }
            .onDisappear { loader.unload() }
    }
}

struct LivePhotoSurface: UIViewRepresentable {
    let livePhoto: PHLivePhoto?

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.isMuted = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        guard view.livePhoto !== livePhoto else { return }
        view.livePhoto = livePhoto
        guard livePhoto != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            view.startPlayback(with: .full)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PHLivePhotoView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width,
               height: proposal.height ?? uiView.intrinsicContentSize.height)
    }
}

final class LivePhotoLoader: ObservableObject {
    @Published private(set) var livePhoto: PHLivePhoto?

    private var currentID: String?
    private var requestID: PHImageRequestID?

    func load(_ asset: PHAsset) {
        guard currentID != asset.localIdentifier else { return }
        unload()
        currentID = asset.localIdentifier
        AudioSession.activatePlayback()

        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        requestID = PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: CGSize(width: 1400, height: 1400),
            contentMode: .aspectFit,
            options: options
        ) { [weak self] photo, _ in
            guard let self, let photo else { return }
            DispatchQueue.main.async {
                guard self.currentID == asset.localIdentifier else { return }
                self.livePhoto = photo
            }
        }
    }

    func unload() {
        if let requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
        livePhoto = nil
        currentID = nil
    }
}

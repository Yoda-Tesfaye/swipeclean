import SwiftUI
import Photos
import AVFoundation
import UIKit
import Combine

/// Plays the video of the page that is currently on screen, muted like the
/// Photos app does. The view is re-created when the page changes so playback
/// never leaks between pages.
struct VideoLayer: View {
    let asset: PHAsset
    @ObservedObject private var settings = AppSettings.shared

    @StateObject private var loader = VideoLoader()

    var body: some View {
        VideoSurface(player: loader.player, hdr: settings.videoHDR)
            .onAppear { loader.load(asset) }
            .onDisappear { loader.unload() }
    }
}

struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer?
    var hdr: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .clear
        view.set(player: player, hdr: hdr)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.set(player: player, hdr: hdr)
    }
}

final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    func set(player: AVPlayer?, hdr: Bool) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
        playerLayer.videoGravity = .resizeAspect
        if #available(iOS 26.0, *) {
            playerLayer.preferredDynamicRange = hdr ? .high : .standard
        }
    }
}

final class VideoLoader: ObservableObject {
    @Published private(set) var player: AVPlayer?

    private var observer: NSObjectProtocol?
    private var currentID: String?

    func load(_ asset: PHAsset) {
        guard currentID != asset.localIdentifier else { return }
        unload()
        currentID = asset.localIdentifier

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let self, let avAsset else { return }
            DispatchQueue.main.async {
                guard self.currentID == asset.localIdentifier else { return }
                let item = AVPlayerItem(asset: avAsset)
                let player = AVPlayer(playerItem: item)
                player.isMuted = false
                AudioSession.activatePlayback()
                player.actionAtItemEnd = .none
                self.observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak player] _ in
                    player?.seek(to: .zero)
                    player?.play()
                }
                self.player = player
                player.play()
            }
        }
    }

    func unload() {
        player?.pause()
        player = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        currentID = nil
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

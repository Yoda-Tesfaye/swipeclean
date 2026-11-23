import SwiftUI
import Photos
import UIKit

enum CardVerdict: Equatable {
    case none
    case delete
    case undo
}

/// Displays a photo or video poster. The caller sizes the frame, so the image
/// keeps its native aspect ratio without letterboxing; `fills` is used by the
/// small deck thumbnails, where cropping looks better than bars.
struct AssetCard: View {
    let asset: PHAsset
    let target: CGSize
    var isCurrent: Bool = true
    var fills: Bool = false
    var verdict: CardVerdict = .none
    var verdictProgress: Double = 0

    @State private var image: UIImage?
    @ObservedObject private var settings = AppSettings.shared

    private var useHDR: Bool {
        asset.mediaType == .video ? settings.videoHDR : settings.photoHDR
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.surface

                if let image {
                    HDRImageView(image: image,
                                 hdr: useHDR,
                                 contentMode: fills ? .scaleAspectFill : .scaleAspectFit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white.opacity(0.4))
                }

                if asset.mediaType == .video && isCurrent {
                    VideoLayer(asset: asset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .allowsHitTesting(false)
                }

                if isCurrent, asset.mediaType == .image, asset.mediaSubtypes.contains(.photoLive) {
                    LivePhotoLayer(asset: asset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .allowsHitTesting(false)
                }

                verdictOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 14)
        .onAppear(perform: loadImage)
        .onChange(of: useHDR) { _ in
            loadImage()
        }
        .onChange(of: target) { _ in
            loadImage()
        }
    }

    // MARK: - Verdict overlay

    @ViewBuilder
    private var verdictOverlay: some View {
        if verdict != .none && verdictProgress > 0.02 {
            ZStack {
                (verdict == .delete ? Theme.danger : Theme.success)
                    .opacity(0.32 * verdictProgress)

                VStack(spacing: 10) {
                    Image(systemName: verdict == .delete ? "trash.fill" : "arrow.uturn.backward")
                        .font(.system(size: 40, weight: .bold))
                    Text(verdict == .delete ? "删除" : "撤销")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.black.opacity(0.28)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5))
                .scaleEffect(0.86 + 0.14 * verdictProgress)
                .opacity(min(1, verdictProgress * 1.5))
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Loading

    private func loadImage() {
        if let hit = ImageStore.shared.cached(for: asset, target: target, hdr: useHDR) {
            image = hit
            return
        }
        ImageStore.shared.load(for: asset, target: target, hdr: useHDR) { loaded in
            guard let loaded else { return }
            image = loaded
        }
    }
}

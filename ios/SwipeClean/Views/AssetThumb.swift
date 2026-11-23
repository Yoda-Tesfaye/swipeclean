import SwiftUI
import Photos
import UIKit

/// Square thumbnail used by the batch and bin sheets.
struct AssetThumb: View {
    let asset: PHAsset
    var corner: CGFloat = 12

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.surface

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }

                if asset.mediaType == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                                .padding(6)
                        }
                    }
                }
            }
            .onAppear {
                load(target: ImageStore.target(for: geo.size))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .contentShape(Rectangle())
    }

    private func load(target: CGSize) {
        if let hit = ImageStore.shared.cached(for: asset, target: target) {
            image = hit
            return
        }
        ImageStore.shared.load(for: asset, target: target) { loaded in
            guard let loaded else { return }
            image = loaded
        }
    }
}

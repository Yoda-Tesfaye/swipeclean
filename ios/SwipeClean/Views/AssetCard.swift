import SwiftUI
import Photos
import UIKit

enum CardVerdict: Equatable {
    case none
    case delete
    case undo
}

struct AssetCard: View {
    let asset: PHAsset
    let target: CGSize
    var isCurrent: Bool = true
    var verdict: CardVerdict = .none
    var verdictProgress: Double = 0

    @State private var image: UIImage?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.surface

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white.opacity(0.4))
                }

                if asset.mediaType == .video && isCurrent {
                    VideoLayer(asset: asset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    footer
                }

                verdictOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 12)
        .onAppear(perform: loadImage)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                if let date = asset.creationDate {
                    Text(Self.dayFormatter.string(from: date))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                Text(asset.mediaType == .video ? "视频" : "照片")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer(minLength: 0)

            if asset.mediaType == .video {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(Self.durationText(asset.duration))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .padding(.top, 46)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }

    // MARK: - Verdict overlay

    @ViewBuilder
    private var verdictOverlay: some View {
        if verdict != .none && verdictProgress > 0.02 {
            ZStack {
                (verdict == .delete ? Theme.danger : Theme.success)
                    .opacity(0.35 * verdictProgress)

                VStack(spacing: 10) {
                    Image(systemName: verdict == .delete ? "trash.fill" : "arrow.uturn.backward")
                        .font(.system(size: 44, weight: .bold))
                    Text(verdict == .delete ? "删除" : "撤销")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 2))
                .scaleEffect(0.86 + 0.14 * verdictProgress)
                .opacity(min(1, verdictProgress * 1.5))
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Loading

    private func loadImage() {
        if let hit = ImageStore.shared.cached(for: asset, target: target) {
            image = hit
            return
        }
        ImageStore.shared.load(for: asset, target: target) { loaded in
            guard let loaded else { return }
            image = loaded
        }
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

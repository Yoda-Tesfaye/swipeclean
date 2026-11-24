import SwiftUI
import Photos
import UIKit

/// A Liquid-Glass inspired treatment: translucent material, a specular edge
/// and a soft floating shadow. Uses public Material APIs so it runs on iOS 16+.
extension View {
    func glassSurface<S: InsettableShape>(_ shape: S) -> some View {
        self
            .background(shape.fill(.ultraThinMaterial))
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}

/// Blurred, darkened copy of the current asset behind the deck, like the
/// ambient wallpaper the reference app builds its glass controls on.
struct AmbientBackground: View {
    let asset: PHAsset?

    @State private var image: UIImage?
    @State private var previousImage: UIImage?
    @State private var requestedIdentifier: String?
    @State private var crossfade: Double = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.background

                if let previousImage {
                    backgroundImage(previousImage, size: geo.size)
                        .opacity(1 - crossfade)
                }

                if let image {
                    backgroundImage(image, size: geo.size)
                        .opacity(crossfade)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear(perform: load)
        .onChange(of: asset?.localIdentifier) { _ in
            load()
        }
    }

    private func load() {
        guard let asset else { return }
        let identifier = asset.localIdentifier
        requestedIdentifier = identifier
        ImageStore.shared.load(for: asset, target: CGSize(width: 90, height: 90)) { loaded in
            guard let loaded else { return }
            DispatchQueue.main.async {
                guard requestedIdentifier == identifier else { return }
                previousImage = image
                image = loaded
                crossfade = 0
                withAnimation(.easeInOut(duration: 0.85)) {
                    crossfade = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    guard requestedIdentifier == identifier else { return }
                    previousImage = nil
                }
            }
        }
    }

    private func backgroundImage(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 48)
            .opacity(0.55)
            .overlay(Color.black.opacity(0.35))
    }
}

/// Press starts the feedback immediately: the control scales down on touch-down
/// and springs back on release (Apple's first principle: respond instantly).
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.85)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}

struct CircleAction: View {
    let icon: String
    let title: String
    let tint: Color
    let iconColor: Color
    var usesMaterial: Bool = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(iconColor)
                    .frame(width: 64, height: 64)
                    .background {
                        if usesMaterial {
                            Circle().fill(.ultraThinMaterial)
                        } else {
                            Circle().fill(tint)
                        }
                    }
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

struct HintOverlay: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 18) {
                Text("怎么用")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                row(icon: "arrow.left.arrow.right", title: "左右滑动", detail: "切换照片和视频，一直滑到相册末尾")
                row(icon: "arrow.up", title: "上划", detail: "把当前内容加入删除备选")
                row(icon: "arrow.down", title: "下划", detail: "撤销最近一次加入备选的内容")
                row(icon: "clock.badge.checkmark", title: "每 30 项", detail: "弹一次确认，批量删除前面选中的内容")

                Button(action: onClose) {
                    Text("开始浏览")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 26)
            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 18)
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.accent.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

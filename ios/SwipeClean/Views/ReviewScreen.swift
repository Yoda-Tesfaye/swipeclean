import SwiftUI
import Photos

/// Full-screen review deck, opened from the photos or videos tab.
struct ReviewScreen: View {
    @ObservedObject var engine: ReviewEngine
    @Environment(\.dismiss) private var dismiss

    @State private var chromeVisible = true
    @State private var showBin = false
    @State private var showDetails = false
    @State private var isFavorite = false

    var body: some View {
        ZStack {
            AmbientBackground(asset: engine.current)
                .ignoresSafeArea()

            switch engine.phase {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.white.opacity(0.5))
            case .empty:
                emptyState
            case .ready:
                readyContent
            case .finished:
                finishedState
            }

            if engine.isDeleting {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
            }

            if let toast = engine.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, 150)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showBin) {
            BinSheet(engine: engine)
        }
        .sheet(isPresented: $showDetails) {
            if let asset = engine.current {
                AssetDetailSheet(asset: asset)
            }
        }
        .onAppear(perform: syncFavorite)
        .onChange(of: engine.index) { _ in
            syncFavorite()
        }
    }

    // MARK: - Ready

    private var readyContent: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .opacity(chromeVisible ? 1 : 0)
                .allowsHitTesting(chromeVisible)

            CardPager(engine: engine, chromeVisible: $chromeVisible)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(alignment: .top) {
                    if engine.reviewedCount == 0 {
                        swipeHint
                            .padding(.top, 6)
                    }
                }
                .sheet(item: $engine.pendingBatch, onDismiss: {
                    engine.skipBatch()
                }) { _ in
                    BatchSheet(engine: engine)
                }

            bottomBar
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .opacity(chromeVisible ? 1 : 0)
                .allowsHitTesting(chromeVisible)
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                CircleIconButton(icon: "chevron.left") {
                    dismiss()
                }

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Text("\(engine.reviewedCount) / \(engine.reviewedCount + engine.remaining)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("本组 \(engine.reviewedInBatch)/\(engine.batchSize)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Button {
                    showBin = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(engine.bin.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassSurface(Capsule())
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(4, geo.size.width * engine.progress))
                }
            }
            .frame(height: 3)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Spacer()

                bottomControl(icon: isFavorite ? "heart.fill" : "heart",
                              label: "收藏",
                              tint: isFavorite ? Theme.danger : .white) {
                    toggleFavorite()
                }

                Spacer()

                bottomControl(icon: "info.circle",
                              label: "详情",
                              tint: .white) {
                    showDetails = true
                }

                Spacer()

                bottomControl(icon: "arrow.uturn.backward",
                              label: "撤回",
                              tint: engine.bin.isEmpty ? Theme.textTertiary : .white,
                              enabled: !engine.bin.isEmpty) {
                    engine.undoLastAction()
                }

                Spacer()
            }
            .padding(.horizontal, 8)

            Text("上滑删除 · 左右切换")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func bottomControl(icon: String,
                               label: String,
                               tint: Color,
                               enabled: Bool = true,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 52, height: 52)
                    .glassSurface(Circle())

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(label)
    }

    private var swipeHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
            Text("上滑删除")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassSurface(Capsule())
        .transition(.opacity)
    }

    private func syncFavorite() {
        isFavorite = engine.current?.isFavorite ?? false
    }

    private func toggleFavorite() {
        guard let asset = engine.current else { return }
        let target = !isFavorite
        isFavorite = target
        Haptics.tap()
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest(for: asset)?.isFavorite = target
        }) { success, _ in
            DispatchQueue.main.async {
                if success {
                    engine.showToast(target ? "已收藏" : "已取消收藏")
                } else {
                    isFavorite = !target
                    Haptics.warning()
                    engine.showToast("操作失败，请重试")
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Theme.textSecondary)
            Text(engine.mode == .photos ? "没有可浏览的照片" : "没有可浏览的视频")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("先去系统相册拍点内容，或者到设置里重置浏览记录。")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                dismiss()
            } label: {
                Text("返回")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            Spacer()
        }
    }

    // MARK: - Finished

    private var finishedState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54, weight: .regular))
                .foregroundColor(Theme.accent)

            Text("\(engine.mode.title)看完了")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("本次浏览 \(engine.reviewedCount) 项 · 删除 \(engine.deletedCount) 项")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)

            if !engine.bin.isEmpty {
                Button {
                    engine.deleteAllBin()
                } label: {
                    Text("删除备选 \(engine.bin.count) 项")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.danger))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Button {
                dismiss()
            } label: {
                Text("返回相册")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)

            Text("想再刷一遍？到「设置」里重置浏览记录")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }
}

struct CircleIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .glassSurface(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(icon == "chevron.left" ? "返回" : "关闭")
    }
}

import SwiftUI
import Photos

/// Full-screen review deck. Follows the reference app's immersion: the photo
/// runs under floating Liquid Glass chrome, the header sits on top, and the
/// info panel pulls up from the bottom instead of presenting a sheet.
struct ReviewScreen: View {
    @ObservedObject var engine: ReviewEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var chromeVisible = true
    @State private var showBin = false
    @State private var showInfo = false
    @State private var isFavorite = false

    private var motion: Animation? {
        AppMotion.spring(reduceMotion: reduceMotion)
    }

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
                viewer
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
                        .padding(.bottom, 170)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showBin) {
            BinSheet(engine: engine)
        }
        .onAppear(perform: syncFavorite)
        .onChange(of: engine.index) { _ in
            syncFavorite()
            if showInfo {
                withAnimation(motion) {
                    showInfo = false
                }
            }
        }
    }

    // MARK: - Viewer

    private var viewer: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                CardPager(engine: engine, chromeVisible: $chromeVisible)
                    .overlay(alignment: .top) {
                        if engine.reviewedCount == 0 {
                            swipeHint
                                .padding(.top, 74)
                        }
                    }

                header

                if showInfo, let asset = engine.current {
                    AssetInfoPanel(asset: asset) {
                        closeInfo()
                    }
                    .frame(height: min(geo.size.height * 0.56, 560))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }
        .animation(motion, value: showInfo)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .floatingGlass(Circle())
            .accessibilityLabel("返回")

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(relativeDateText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(engine.mode.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .floatingGlass(Capsule())

            Spacer(minLength: 0)

            Button {
                showBin = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(engine.bin.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundColor(.white)
                .frame(height: 44)
                .padding(.horizontal, 14)
            }
            .floatingGlass(Capsule())
            .accessibilityLabel("删除备选")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .opacity(chromeVisible ? 1 : 0)
        .allowsHitTesting(chromeVisible)
        .animation(.easeOut(duration: 0.18), value: chromeVisible)
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                controlButton(isFavorite ? "heart.fill" : "heart",
                              tint: isFavorite ? Theme.danger : .white,
                              enabled: true,
                              label: isFavorite ? "取消收藏" : "收藏") {
                    toggleFavorite()
                }

                controlButton("info.circle",
                              tint: showInfo ? Theme.accent : .white,
                              enabled: true,
                              label: "详情") {
                    toggleInfo()
                }

                controlButton("arrow.uturn.backward",
                              tint: engine.bin.isEmpty ? Theme.textTertiary : .white,
                              enabled: !engine.bin.isEmpty,
                              label: "撤回上一步") {
                    engine.undoLastAction()
                }
            }
            .padding(.horizontal, 6)
            .floatingGlass(Capsule())

            Text("上滑删除 · 左右切换")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .opacity(chromeVisible ? 1 : 0)
        .allowsHitTesting(chromeVisible)
        .animation(.easeOut(duration: 0.18), value: chromeVisible)
    }

    private func controlButton(_ icon: String,
                               tint: Color,
                               enabled: Bool,
                               label: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 56, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
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

    private var relativeDateText: String {
        guard let date = engine.current?.creationDate else { return "照片" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date, to: Date())
        if let years = components.year, years >= 1 { return "\(years) 年前" }
        if let months = components.month, months >= 1 { return "\(months) 个月前" }
        if let days = components.day, days >= 1 { return "\(days) 天前" }
        return "今天"
    }

    // MARK: - Actions

    private func toggleInfo() {
        Haptics.tap()
        withAnimation(motion) {
            showInfo.toggle()
        }
    }

    private func closeInfo() {
        withAnimation(motion) {
            showInfo = false
        }
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
            PHAssetChangeRequest(for: asset).isFavorite = target
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
                .floatingGlass(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(icon == "chevron.left" ? "返回" : "关闭")
    }
}

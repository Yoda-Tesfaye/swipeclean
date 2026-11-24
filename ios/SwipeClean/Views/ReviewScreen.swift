import SwiftUI
import Photos
import CoreLocation

/// Full-screen review deck. Follows the reference app's immersion: the photo
/// runs under floating Liquid Glass chrome, the header sits on top, and the
/// info panel pulls up from the bottom instead of presenting a sheet.
struct ReviewScreen: View {
    @ObservedObject var engine: ReviewEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("review.firstGestureHintShown") private var hasSeenFirstGestureHint = false

    @State private var chromeVisible = true
    @State private var showBin = false
    @State private var showInfo = false
    @State private var isFavorite = false
    @State private var placeTitle = ""
    @State private var showFirstGestureHint = false

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

            if showFirstGestureHint, engine.phase == .ready {
                Text("左右切换 · 上滑删除 · 下滑撤回")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassSurface(Capsule())
                    .frame(maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .sheet(item: $engine.pendingBatch, onDismiss: {
            engine.skipBatch()
        }) { _ in
            BatchSheet(engine: engine)
        }
        .onAppear {
            syncFavorite()
            loadPlaceTitle()
            guard !hasSeenFirstGestureHint, engine.current != nil else { return }
            hasSeenFirstGestureHint = true
            withAnimation(.easeOut(duration: 0.22)) {
                showFirstGestureHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showFirstGestureHint = false
                }
            }
        }
        .onChange(of: engine.index) { _ in
            syncFavorite()
            loadPlaceTitle()
            if showInfo {
                withAnimation(motion) {
                    showInfo = false
                }
            }
        }
    }

    // MARK: - Viewer

    private var viewer: some View {
        ZStack(alignment: .top) {
            if showInfo, let asset = engine.current {
                AssetInfoPanel(asset: asset) {
                    closeInfo()
                }
                .transition(.opacity)
                .ignoresSafeArea()
                .zIndex(2)
            } else {
                CardPager(engine: engine, chromeVisible: $chromeVisible)
                header
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showInfo {
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

            GeometryReader { _ in
                let width: CGFloat = 124
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: width, height: 5)
                    Capsule()
                        .fill(LinearGradient(colors: [.white, .white.opacity(0.88)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, width * engine.progress), height: 5)
                }
                .clipShape(Capsule())
                .animation(.spring(response: 0.52, dampingFraction: 0.8), value: engine.progress)
                .frame(width: width, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 124, height: 44)
            .accessibilityElement()
            .accessibilityLabel("浏览进度")
            .accessibilityValue("\(Int(engine.progress * 100))%")

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
        .sheet(isPresented: $showBin) {
            BinSheet(engine: engine)
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                roundControlButton(isFavorite ? "heart.fill" : "heart",
                                   tint: isFavorite ? Theme.danger : .white,
                                   label: isFavorite ? "取消收藏" : "收藏",
                                   action: toggleFavorite)

                Spacer(minLength: 18)

                Button(action: toggleInfo) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(relativeDateText)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if engine.current?.location != nil, !placeTitle.isEmpty {
                                Text(placeTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(showInfo ? Theme.accent : .white)
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: 230, minHeight: 44, maxHeight: 44)
                    .contentShape(Capsule())
                    .floatingGlass(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("照片详情")

                Spacer(minLength: 18)

                roundControlButton("arrow.uturn.backward",
                                   tint: engine.bin.isEmpty ? Theme.textTertiary : .white,
                                   label: "撤回上一步",
                                   enabled: !engine.bin.isEmpty,
                                   action: engine.undoLastAction)
            }
            .frame(maxWidth: .infinity)

        }
        .opacity(chromeVisible ? 1 : 0)
        .allowsHitTesting(chromeVisible)
        .animation(.easeOut(duration: 0.18), value: chromeVisible)
    }

    private func roundControlButton(_ icon: String,
                                    tint: Color,
                                    label: String,
                                    enabled: Bool = true,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .floatingGlass(Circle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
        .accessibilityLabel(label)
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

    private func loadPlaceTitle() {
        placeTitle = ""
        guard let location = engine.current?.location else { return }
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let title = [placemark.locality, placemark.subLocality, placemark.name]
                .compactMap { $0 }
                .first { !$0.isEmpty } ?? ""
            DispatchQueue.main.async {
                guard engine.current?.location?.coordinate.latitude == location.coordinate.latitude,
                      engine.current?.location?.coordinate.longitude == location.coordinate.longitude else { return }
                placeTitle = title
            }
        }
    }

    private func toggleFavorite() {
        guard let asset = engine.current else { return }
        let target = !isFavorite
        isFavorite = target
        Haptics.tap()

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            isFavorite = !target
            Haptics.warning()
            engine.showToast("需要相册写入权限，请到设置里开启")
            return
        }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = target
        }) { success, error in
            DispatchQueue.main.async {
                guard success else {
                    isFavorite = !target
                    Haptics.warning()
                    engine.showToast(error?.localizedDescription ?? "收藏失败，请检查相册权限")
                    return
                }

                // Read the value back from the library: limited access can
                // report success without the favorite sticking.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let refreshed = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil).firstObject
                    let actual = refreshed?.isFavorite ?? target
                    isFavorite = actual
                    if actual != target {
                        Haptics.warning()
                        engine.showToast("相册未同步，请把照片权限改为「完全访问」")
                    }
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

import SwiftUI
import Photos

/// Full-screen review deck, opened from the photos or videos tab.
struct ReviewScreen: View {
    @ObservedObject var engine: ReviewEngine
    @Environment(\.dismiss) private var dismiss

    @State private var chromeVisible = true
    @State private var showBin = false
    @State private var showDetails = false

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
        VStack(spacing: 12) {
            if engine.canUndo {
                Button {
                    engine.undoLastAction()
                } label: {
                    Label("撤销上一步", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassSurface(Capsule())
                }
                .buttonStyle(.plain)
            }

            if engine.current != nil {
                Button {
                    showDetails = true
                } label: {
                    HStack(spacing: 7) {
                        Text(relativeDateText)
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassSurface(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 46) {
                CircleAction(icon: "checkmark",
                             title: "保留",
                             tint: .clear,
                             iconColor: .white,
                             usesMaterial: true) {
                    engine.moveForward()
                }

                CircleAction(icon: "trash.fill",
                             title: "删除",
                             tint: Theme.danger,
                             iconColor: .white) {
                    engine.markCurrentForDeletion()
                }
            }

            Text("上划删除 · 下划撤销 · 左右切换")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var relativeDateText: String {
        guard let date = engine.current?.creationDate else { return "详情" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date, to: Date())
        if let years = components.year, years >= 1 { return "\(years) 年前" }
        if let months = components.month, months >= 1 { return "\(months) 个月前" }
        if let days = components.day, days >= 1 { return "\(days) 天前" }
        return "今天"
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
                .frame(width: 38, height: 38)
                .glassSurface(Circle())
        }
        .buttonStyle(.plain)
    }
}

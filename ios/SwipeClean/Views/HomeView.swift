import SwiftUI
import Photos

struct HomeView: View {
    @ObservedObject var app: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $app.tab)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.tab {
        case .photos:
            DeckHome(engine: app.photos, settings: app.settings, onReset: { app.resetHistory() })
        case .videos:
            DeckHome(engine: app.videos, settings: app.settings, onReset: { app.resetHistory() })
        case .settings:
            StatsView(app: app)
        }
    }
}

struct TabBar: View {
    @Binding var selection: HomeTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(selection == tab ? .white : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(selection == tab ? Color.white.opacity(0.16) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 46)
        .padding(.bottom, 8)
    }
}

struct DeckHome: View {
    @ObservedObject var engine: ReviewEngine
    @ObservedObject var settings: AppSettings
    var onReset: () -> Void

    @State private var showReview = false
    @State private var showBin = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 4)

                Spacer(minLength: 8)

                content(size: geo.size)

                Spacer(minLength: 8)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 104)
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            ReviewScreen(engine: engine)
        }
        .sheet(isPresented: $showBin) {
            BinSheet(engine: engine)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Menu {
                Section("每组数量") {
                    ForEach(AppSettings.batchChoices, id: \.self) { choice in
                        Button {
                            settings.setBatch(choice, for: engine.mode)
                        } label: {
                            if engine.batchSize == choice {
                                Label("\(choice) 项", systemImage: "checkmark")
                            } else {
                                Text("\(choice) 项")
                            }
                        }
                    }
                }
                Button(role: .destructive) {
                    onReset()
                } label: {
                    Label("重置浏览记录", systemImage: "arrow.counterclockwise")
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: engine.mode == .photos ? "photo" : "play.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                    Text(engine.mode.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(engine.remaining)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textTertiary)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
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
                .background(Capsule().fill(Color.white.opacity(engine.bin.isEmpty ? 0.06 : 0.16)))
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Deck area

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch engine.phase {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: size.height * 0.55)

        case .ready:
            FanStack(engine: engine) {
                showReview = true
            }
            .frame(height: min(size.height * 0.60, 560))

        case .finished:
            StatusCard(
                icon: "checkmark.seal.fill",
                title: "\(engine.mode.title)看完了",
                message: "已浏览 \(engine.historyCount) 项，没有新的内容了。\n想再清一遍？重置浏览记录即可重新随机排列。",
                primaryTitle: "重置浏览记录",
                primaryAction: onReset,
                secondaryTitle: "去设置",
                secondaryAction: nil
            )
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, minHeight: size.height * 0.55)

        case .empty:
            StatusCard(
                icon: engine.mode == .photos ? "photo.on.rectangle.angled" : "play.rectangle",
                title: engine.mode == .photos ? "相册里没有照片" : "相册里没有视频",
                message: "拍点内容，或者从「最近删除」恢复一些之后再来。",
                primaryTitle: "重新扫描",
                primaryAction: { engine.reload() },
                secondaryTitle: nil,
                secondaryAction: nil
            )
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, minHeight: size.height * 0.55)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            if engine.phase == .ready {
                Text("轻点卡片开始 · 上滑删除 · 下滑撤销")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Text("每浏览 \(engine.batchSize) 项确认一次 · 已浏览的不会再次出现")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Fan

struct FanStack: View {
    @ObservedObject var engine: ReviewEngine
    var onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.64, 300)
            let height = min(width * 1.42, max(geo.size.height - 12, 200))
            let size = CGSize(width: width, height: height)

            ZStack {
                if engine.index + 2 < engine.items.count {
                    card(engine.items[engine.index + 2], size: size)
                        .rotationEffect(.degrees(9))
                        .offset(x: width * 0.11, y: -height * 0.02)
                        .scaleEffect(0.88)
                        .opacity(0.55)
                }

                if engine.index + 1 < engine.items.count {
                    card(engine.items[engine.index + 1], size: size)
                        .rotationEffect(.degrees(-8))
                        .offset(x: -width * 0.06, y: -height * 0.01)
                        .scaleEffect(0.94)
                        .opacity(0.8)
                }

                if let asset = engine.current {
                    card(asset, size: size)
                        .onTapGesture(perform: onTap)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func card(_ asset: PHAsset, size: CGSize) -> some View {
        AssetCard(asset: asset, target: ImageStore.target(for: size), isCurrent: false)
            .frame(width: size.width, height: size.height)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 3)
            )
    }
}

// MARK: - Status card

struct StatusCard: View {
    let icon: String
    let title: String
    let message: String
    let primaryTitle: String
    var primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.accent)

            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

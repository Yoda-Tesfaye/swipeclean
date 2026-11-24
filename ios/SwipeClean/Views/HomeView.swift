import SwiftUI
import Photos

struct HomeView: View {
    @ObservedObject var app: AppModel

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $app.tab) {
                tab(.photos)
                tab(.videos)
                tab(.settings)
            }
            .tint(Theme.accent)
        } else {
            ZStack(alignment: .bottom) {
                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                TabBar(selection: $app.tab)
            }
        }
    }

    @available(iOS 26.0, *)
    private func tab(_ tab: HomeTab) -> some View {
        selectedContent(for: tab)
            .tabItem {
                Label(tab.title, systemImage: tab.symbol)
            }
            .tag(tab)
    }

    @ViewBuilder
    private var selectedContent: some View {
        selectedContent(for: app.tab)
    }

    @ViewBuilder
    private func selectedContent(for tab: HomeTab) -> some View {
        switch tab {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragTranslation: CGFloat = 0

    private let barHeight: CGFloat = 56
    private let inset: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(HomeTab.allCases.count)
            let itemWidth = (geo.size.width - inset * 2) / count
            let index = CGFloat(HomeTab.allCases.firstIndex(of: selection) ?? 0)
            let baseX = inset + index * itemWidth

            barContents(itemWidth: itemWidth, baseX: baseX, width: geo.size.width)
            .frame(width: geo.size.width, height: barHeight)
            .contentShape(Capsule())
            .simultaneousGesture(dragGesture(itemWidth: itemWidth, baseX: baseX, count: count))
        }
        .frame(height: barHeight)
        .padding(.horizontal, 46)
        .padding(.bottom, 8)
    }

    private func barContents(itemWidth: CGFloat, baseX: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .frame(width: width, height: barHeight)
                .floatingGlassPanel(Capsule())

            Capsule()
                .frame(width: itemWidth, height: barHeight)
                .floatingGlass(Capsule())
                .offset(x: baseX + dragTranslation)

            HStack(spacing: 0) {
                ForEach(HomeTab.allCases) { tab in
                    Button {
                        select(tab)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(selection == tab ? .white : Theme.textSecondary)
                        .frame(width: itemWidth, height: barHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, inset)
        }
    }

    private func select(_ tab: HomeTab) {
        guard tab != selection else { return }
        Haptics.tap()
        withAnimation(animation) {
            selection = tab
        }
    }

    private var animation: Animation? {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0.12)
    }

    private func dragGesture(itemWidth: CGFloat, baseX: CGFloat, count: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let minX = -(baseX - inset)
                let maxX = (count - 1) * itemWidth + inset - baseX
                dragTranslation = min(max(value.translation.width, minX), maxX)
            }
            .onEnded { value in
                let projected = baseX + value.predictedEndTranslation.width
                let raw = (projected - inset) / itemWidth
                let target = min(max(Int(raw.rounded()), 0), Int(count) - 1)
                Haptics.tap()
                withAnimation(animation) {
                    selection = HomeTab.allCases[target]
                    dragTranslation = 0
                }
            }
    }
}

struct DeckHome: View {
    @ObservedObject var engine: ReviewEngine
    @ObservedObject var settings: AppSettings
    var onReset: () -> Void

    @State private var showReview = false
    @State private var showBin = false

    var body: some View {
        ZStack {
            AmbientBackground(asset: engine.current)
                .ignoresSafeArea()

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
                .floatingGlass(Capsule())
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
                .floatingGlass(Capsule())
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
            let size = cardSize(in: geo.size)

            ZStack {
                if engine.index + 2 < engine.items.count {
                    card(engine.items[engine.index + 2], size: size, fill: true)
                        .rotationEffect(.degrees(9))
                        .offset(x: size.width * 0.11, y: -size.height * 0.02)
                        .scaleEffect(0.88)
                        .opacity(0.55)
                }

                if engine.index + 1 < engine.items.count {
                    card(engine.items[engine.index + 1], size: size, fill: true)
                        .rotationEffect(.degrees(-8))
                        .offset(x: -size.width * 0.06, y: -size.height * 0.01)
                        .scaleEffect(0.94)
                        .opacity(0.8)
                }

                if let asset = engine.current {
                    card(asset, size: size, fill: false)
                        .onTapGesture(perform: onTap)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func cardSize(in container: CGSize) -> CGSize {
        let maxWidth = min(container.width * 0.60, 310)
        let ratio = aspectRatio(of: engine.current)
        var width = maxWidth
        var height = width / ratio
        let maxHeight = max(container.height - 10, 160)
        if height > maxHeight {
            height = maxHeight
            width = height * ratio
        }
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    private func aspectRatio(of asset: PHAsset?) -> CGFloat {
        guard let asset, asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 0.75 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    private func card(_ asset: PHAsset, size: CGSize, fill: Bool) -> some View {
        AssetCard(asset: asset, target: ImageStore.target(for: size), isCurrent: false, fills: fill)
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
            .buttonStyle(PressableStyle())
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



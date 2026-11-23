import SwiftUI

struct StatsView: View {
    @ObservedObject var app: AppModel
    @State private var showSettings = false
    @State private var showReset = false

    private var totalViewed: Int {
        app.photos.historyCount + app.videos.historyCount
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("使用统计")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)

                ModeStatsCard(engine: app.photos)
                ModeStatsCard(engine: app.videos)

                Button {
                    showReset = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("重置浏览记录")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("已浏览 \(totalViewed) 个项目，重置后可再清理一遍")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(app: app, settings: app.settings)
        }
        .confirmationDialog("重置浏览记录？", isPresented: $showReset, titleVisibility: .visible) {
            Button("重置", role: .destructive) {
                app.resetHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有照片和视频都会重新加入随机浏览队列，可以再清理一遍。")
        }
    }
}

struct ModeStatsCard: View {
    @ObservedObject var engine: ReviewEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: engine.mode == .photos ? "photo" : "play.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text(engine.mode.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("剩余 \(engine.remaining)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                stat(icon: "eye", label: "查看", value: engine.historyCount, color: .white)
                stat(icon: "trash", label: "删除", value: engine.deletedCount, color: Theme.danger)
                stat(icon: "tray.and.arrow.down", label: "待删除", value: engine.bin.count, color: Theme.success)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func stat(icon: String, label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color.opacity(0.9))

            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

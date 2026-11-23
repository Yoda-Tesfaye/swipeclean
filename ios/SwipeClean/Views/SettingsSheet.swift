import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var app: AppModel
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("设定")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    CircleIconButton(icon: "xmark") {
                        dismiss()
                    }
                }
                .padding(.top, 10)

                group {
                    batchRow(for: .photos)
                    separator
                    batchRow(for: .videos)
                }

                group {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("震动反馈")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            Text("滑动手势的触感")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.haptics)
                            .labelsHidden()
                            .tint(Theme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                group {
                    toggleRow(title: "照片 HDR",
                              subtitle: "以高动态范围显示 HDR 照片",
                              isOn: $settings.photoHDR)
                    separator
                    toggleRow(title: "视频 HDR",
                              subtitle: "以 HDR 播放视频，关闭则按 SDR 显示",
                              isOn: $settings.videoHDR)
                }

                group {
                    Button {
                        app.resetHistory()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("重置浏览记录")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                Text("让所有内容重新随机出现")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Text("版本")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("1.8.0")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func batchRow(for mode: AssetMode) -> some View {
        Menu {
            ForEach(AppSettings.batchChoices, id: \.self) { choice in
                Button {
                    settings.setBatch(choice, for: mode)
                } label: {
                    if settings.batch(for: mode) == choice {
                        Label("\(choice) 项", systemImage: "checkmark")
                    } else {
                        Text("\(choice) 项")
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode == .photos ? "照片每组数量" : "视频每组数量")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Text("浏览 \(settings.batch(for: mode)) 项后弹出确认")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Text("\(settings.batch(for: mode))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}







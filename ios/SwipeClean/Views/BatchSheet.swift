import SwiftUI
import Photos

/// Shown every `batchSize` reviewed items, styled like the reference app:
/// "回顾完毕" + pending grid + 放弃 / 确认删除.
struct BatchSheet: View {
    @ObservedObject var engine: ReviewEngine

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                Text("回顾完毕")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("请确认要删除的\(engine.mode.title)")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 34)
            .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(engine.bin, id: \.localIdentifier) { asset in
                        AssetThumb(asset: asset)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Theme.success))
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5))
                                    .padding(7)
                            }
                            .onTapGesture {
                                engine.removeBin(asset)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.easeOut(duration: 0.16), value: engine.bin.count)

                if engine.bin.isEmpty {
                    Text("备选已清空，这些内容会被保留")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 30)
                }
            }

            HStack(spacing: 12) {
                Button {
                    engine.skipBatch()
                } label: {
                    Text("放弃，再来一组")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(PressableStyle())

                Button {
                    engine.confirmBatchDeletion()
                } label: {
                    Text("确认删除")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().fill(Theme.danger))
                }
                .buttonStyle(PressableStyle())
                .disabled(engine.bin.isEmpty)
                .opacity(engine.bin.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 26)

            Text("删除后会移入「最近删除」，30 天内可在系统相册恢复")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .padding(.bottom, 26)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}


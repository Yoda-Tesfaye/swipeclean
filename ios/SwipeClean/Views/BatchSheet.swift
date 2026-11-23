import SwiftUI
import Photos

/// Shown every `batchSize` reviewed items: the pending bin, with the option to
/// pull items out before deleting the rest.
struct BatchSheet: View {
    @ObservedObject var engine: ReviewEngine

    private let columns = [GridItem(.adaptive(minimum: 98), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(engine.bin, id: \.localIdentifier) { asset in
                        AssetThumb(asset: asset)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Theme.success))
                                    .padding(6)
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

            footer
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("确认删除这 \(engine.bin.count) 项？")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("点击缩略图可移出备选，只保留你真正想删的内容")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    engine.skipBatch()
                } label: {
                    Text("跳过，继续下一组")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)

                Button {
                    engine.confirmBatchDeletion()
                } label: {
                    Text("确认删除")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.danger))
                }
                .buttonStyle(.plain)
                .disabled(engine.bin.isEmpty)
                .opacity(engine.bin.isEmpty ? 0.45 : 1)
            }

            Text("删除后会移入「最近删除」，30 天内可在系统相册恢复")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(Theme.background.opacity(0.96))
    }
}

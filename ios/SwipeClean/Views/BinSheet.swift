import SwiftUI
import Photos

/// The "pending deletion" drawer that is always reachable from the top bar.
struct BinSheet: View {
    @ObservedObject var engine: ReviewEngine
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 98), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                if engine.bin.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 30, weight: .light))
                            .foregroundColor(Theme.textTertiary)
                        Text("备选区是空的")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(engine.bin, id: \.localIdentifier) { asset in
                            AssetThumb(asset: asset)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        engine.removeBin(asset)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundColor(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }

            footer
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("删除备选")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(engine.bin.count) 项等待确认")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button("完成") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                engine.deleteAllBin()
                dismiss()
            } label: {
                Text("删除 \(engine.bin.count) 项")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.danger))
            }
            .buttonStyle(.plain)
            .disabled(engine.bin.isEmpty)
            .opacity(engine.bin.isEmpty ? 0.4 : 1)

            Text("删除后会移入系统「最近删除」")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
    }
}

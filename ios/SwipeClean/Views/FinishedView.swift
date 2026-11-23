import SwiftUI

struct FinishedView: View {
    @ObservedObject var engine: ReviewEngine

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 58, weight: .regular))
                    .foregroundColor(Theme.accent)

                Text("这一轮看完了")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 18)

                Text("相册里没有更多待浏览的内容")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    StatTile(value: "\(engine.reviewedCount)", label: "已浏览")
                    StatTile(value: "\(engine.deletedCount)", label: "已删除")
                    StatTile(value: "\(engine.bin.count)", label: "备选")
                }
                .padding(.top, 28)
                .padding(.horizontal, 22)

                if !engine.bin.isEmpty {
                    Button {
                        engine.deleteAllBin()
                    } label: {
                        Text("删除备选 \(engine.bin.count) 项")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.danger))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                }

                Button {
                    engine.rescan()
                } label: {
                    Label("重新扫描相册", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.top, 12)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 24)

            if engine.isDeleting {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
            }
        }
    }
}

import SwiftUI
import Photos

struct ReviewScreen: View {
    @ObservedObject var engine: ReviewEngine

    @State private var chromeVisible = true
    @State private var showBin = false
    @State private var showHint = !UserDefaults.standard.bool(forKey: "swipeclean.hint.seen.v1")

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
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

            if engine.isDeleting {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
            }

            if showHint {
                HintOverlay {
                    UserDefaults.standard.set(true, forKey: "swipeclean.hint.seen.v1")
                    withAnimation(.easeOut(duration: 0.2)) {
                        showHint = false
                    }
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showBin) {
            BinSheet(engine: engine)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SwipeClean")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("本组 \(engine.reviewedInBatch)/\(engine.batchSize) · 剩余 \(engine.remaining) 项")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                binButton
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(4, geo.size.width * engine.progress))
                }
            }
            .frame(height: 4)
        }
    }

    private var binButton: some View {
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
            .background(Capsule().fill(Color.white.opacity(engine.bin.isEmpty ? 0.07 : 0.16)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            if engine.canUndo {
                Button {
                    engine.undoLastAction()
                } label: {
                    Label("撤销上一步", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 46) {
                CircleAction(icon: "checkmark",
                             title: "保留",
                             tint: Color.white.opacity(0.13),
                             iconColor: .white) {
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
}

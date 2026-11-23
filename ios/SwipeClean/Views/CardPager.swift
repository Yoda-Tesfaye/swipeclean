import SwiftUI
import Photos

/// A three-card carousel that mirrors the iOS Photos feeling: the page follows
/// the finger 1:1, neighbours sit slightly scaled back, and a release either
/// settles back or advances with an interactive spring.
struct CardPager: View {
    @ObservedObject var engine: ReviewEngine
    @Binding var chromeVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: CGSize = .zero
    @State private var busy = false
    @State private var armed = false
    @State private var axis: DragAxis?

    private var spring: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.16)
        }
        return .interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.2)
    }

    private struct Page: Identifiable {
        let index: Int
        let asset: PHAsset
        var id: String { asset.localIdentifier }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let target = ImageStore.target(for: size)

            ZStack {
                ForEach(pages, id: \.id) { page in
                    cardView(page: page, size: size, target: target)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
            .onTapGesture { toggleChrome() }
            .accessibilityAction(named: Text("删除")) {
                engine.markCurrentForDeletion()
            }
            .accessibilityAction(named: Text("保留")) {
                engine.moveForward()
            }
        }
    }

    // MARK: - Pages

    private var pages: [Page] {
        guard !engine.items.isEmpty else { return [] }
        let lower = max(engine.index - 1, 0)
        let upper = min(engine.items.count - 1, engine.index + 1)
        guard lower <= upper else { return [] }
        return (lower...upper).map { index in
            Page(index: index, asset: engine.items[index])
        }
    }

    private func cardView(page: Page, size: CGSize, target: CGSize) -> some View {
        let isCurrent = page.index == engine.index
        let offsetX = CGFloat(page.index - engine.index) * size.width + drag.width
        let cardSize = Self.fittedSize(for: page.asset, in: size)

        var verdict: CardVerdict = .none
        if isCurrent {
            if drag.height < -12 {
                verdict = .delete
            } else if drag.height > 12 {
                verdict = .undo
            }
        }
        let progress = isCurrent ? min(max(abs(drag.height) / 150, 0), 1) : 0

        return AssetCard(asset: page.asset,
                         target: target,
                         isCurrent: isCurrent,
                         verdict: verdict,
                         verdictProgress: progress)
            .frame(width: cardSize.width, height: cardSize.height)
            .scaleEffect(isCurrent ? 1 : 0.93)
            .opacity(isCurrent ? 1 : 0.7)
            .offset(x: offsetX, y: isCurrent ? drag.height : 0)
            .zIndex(isCurrent ? 1 : 0)
    }

    /// Native aspect ratio, limited by the available box. No letterboxing.
    static func fittedSize(for asset: PHAsset, in container: CGSize) -> CGSize {
        let width = max(CGFloat(asset.pixelWidth), 1)
        let height = max(CGFloat(asset.pixelHeight), 1)
        let ratio = width / height
        var fittedWidth = container.width
        var fittedHeight = fittedWidth / ratio
        if fittedHeight > container.height {
            fittedHeight = container.height
            fittedWidth = fittedHeight * ratio
        }
        return CGSize(width: max(fittedWidth, 1), height: max(fittedHeight, 1))
    }

    // MARK: - Gesture

    private enum DragAxis {
        case horizontal
        case vertical
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !busy else { return }
                var translation = value.translation

                if axis == nil {
                    let horizontal = abs(translation.width)
                    let vertical = abs(translation.height)
                    if max(horizontal, vertical) > 8 {
                        axis = horizontal > vertical ? .horizontal : .vertical
                    }
                }

                switch axis {
                case .horizontal:
                    translation.height = 0
                    if engine.index == 0 && translation.width > 0 {
                        translation.width *= 0.3
                    }
                    if engine.index >= max(engine.items.count - 1, 0) && translation.width < 0 {
                        translation.width *= 0.3
                    }
                case .vertical:
                    // A vertical swipe stays exactly on the Y axis: no sideways drift.
                    translation.width = 0
                    if translation.height > 0 && engine.bin.isEmpty {
                        translation.height *= 0.12
                    }
                case .none:
                    translation = .zero
                }

                if translation.height < -90 && !armed {
                    armed = true
                    Haptics.tap()
                } else if translation.height > -60 {
                    armed = false
                }

                drag = translation
            }
            .onEnded { value in
                armed = false
                let finishedAxis = axis
                axis = nil
                guard !busy else { return }
                endDrag(value: value, size: size, axis: finishedAxis)
            }
    }

    private func endDrag(value: DragGesture.Value, size: CGSize, axis: DragAxis?) {
        let translation = value.translation
        let predicted = value.predictedEndTranslation

        switch axis {
        case .horizontal:
            let threshold = max(64, size.width * 0.22)
            if translation.width < -threshold || predicted.width < -size.width * 0.6 {
                page(forward: true, size: size)
            } else if translation.width > threshold || predicted.width > size.width * 0.6 {
                page(forward: false, size: size)
            } else {
                settle()
            }
        case .vertical:
            if translation.height < -70 || predicted.height < -260 {
                commitDelete(size: size)
            } else if translation.height > 70 || predicted.height > 260 {
                commitUndo(size: size)
            } else {
                settle()
            }
        case .none:
            settle()
        }
    }

    private func settle() {
        withAnimation(spring) {
            drag = .zero
        }
    }

    private func page(forward: Bool, size: CGSize) {
        busy = true
        Haptics.tap()
        withAnimation(spring) {
            drag = .zero
            if forward {
                engine.moveForward()
            } else {
                engine.moveBackward()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            busy = false
        }
    }

    private func commitDelete(size: CGSize) {
        busy = true
        Haptics.commit()
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeIn(duration: 0.18)) {
            drag = CGSize(width: 0, height: -size.height * 1.25)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                drag = .zero
                engine.markCurrentForDeletion()
            }
            busy = false
        }
    }

    private func commitUndo(size: CGSize) {
        guard !engine.bin.isEmpty else {
            settle()
            return
        }
        busy = true
        Haptics.bump()
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeIn(duration: 0.16)) {
            drag = CGSize(width: 0, height: size.height * 1.25)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                drag = .zero
                engine.undoLastAction()
            }
            busy = false
        }
    }

    private func toggleChrome() {
        withAnimation(.easeOut(duration: 0.18)) {
            chromeVisible.toggle()
        }
    }
}

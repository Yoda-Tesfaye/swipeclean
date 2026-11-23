import SwiftUI

struct RootView: View {
    @StateObject private var engine = ReviewEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .overlay(alignment: .bottom) {
            if let toast = engine.toast {
                ToastView(text: toast)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 132)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: engine.toast)
        .onAppear {
            engine.start()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                engine.recheck()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .starting:
            SplashView()
        case .needsPermission:
            PermissionView(engine: engine)
        case .denied:
            DeniedView(engine: engine)
        case .empty:
            EmptyLibraryView(engine: engine)
        case .ready:
            ReviewScreen(engine: engine)
        case .finished:
            FinishedView(engine: engine)
        }
    }
}

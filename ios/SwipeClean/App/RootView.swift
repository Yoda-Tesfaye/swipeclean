import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch app.auth {
            case .checking:
                SplashView()
            case .request:
                PermissionView {
                    app.requestAccess()
                }
            case .denied:
                DeniedView(
                    onOpenSettings: openSettings,
                    onRetry: { app.start() }
                )
            case .ready:
                HomeView(app: app)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(text: toast)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: app.toast)
        .onAppear {
            app.start()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                app.recheck()
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

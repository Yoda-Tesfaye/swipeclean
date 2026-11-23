import SwiftUI
import UIKit

/// Liquid Glass helpers modelled on the reference app (`floatingGlass()`):
/// real system glass on iOS 26+, material fallback on older systems.
///
/// Built with the iOS 26 SDK (Xcode 26). The `#available` branch is required
/// because the app still deploys back to iOS 16.
extension View {

    /// Interactive floating chrome: back buttons, toolbars, pill menus.
    @ViewBuilder
    func floatingGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(shape.fill(.regularMaterial))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
        }
    }

    /// Non-interactive glass surface, used for the pull-up info panel.
    @ViewBuilder
    func floatingGlassPanel<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(shape.fill(.regularMaterial))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
        }
    }
}

enum AppMotion {
    /// The reference app's viewer spring.
    static func spring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.08)
    }
}

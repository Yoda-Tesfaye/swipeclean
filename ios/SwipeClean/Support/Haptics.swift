import UIKit

enum Haptics {
    /// Mirrors the "震动反馈" setting.
    static var enabled = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        guard enabled else { return }
        light.prepare()
        medium.prepare()
        rigid.prepare()
        notification.prepare()
    }

    static func tap() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.7)
    }

    static func bump() {
        guard enabled else { return }
        medium.impactOccurred()
    }

    static func commit() {
        guard enabled else { return }
        rigid.impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        notification.notificationOccurred(.warning)
    }
}

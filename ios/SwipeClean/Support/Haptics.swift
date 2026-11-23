import UIKit

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
        rigid.prepare()
        notification.prepare()
    }

    static func tap() {
        light.impactOccurred(intensity: 0.7)
    }

    static func bump() {
        medium.impactOccurred()
    }

    static func commit() {
        rigid.impactOccurred()
    }

    static func success() {
        notification.notificationOccurred(.success)
    }

    static func warning() {
        notification.notificationOccurred(.warning)
    }
}

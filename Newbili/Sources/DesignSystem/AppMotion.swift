import Foundation
import SwiftUI

/// Shared interaction timing used by player and engagement feedback.
/// These tokens remain independent of any alternate visual theme.
enum AppMotion {
    static let feedbackDuration: TimeInterval = 0.15

    static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion
            ? .easeOut(duration: 0.10)
            : .timingCurve(0.33, 0, 0.67, 1, duration: feedbackDuration)
    }

    static func topLevel(reduceMotion: Bool) -> Animation? {
        reduceMotion
            ? nil
            : .timingCurve(0.33, 0, 0.67, 1, duration: feedbackDuration)
    }

    static func confirmation(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.24, dampingFraction: 0.72)
    }
}

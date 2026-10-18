import Foundation
import SwiftUI

/// Shared interaction timing used by player and engagement feedback.
/// These tokens remain independent of any alternate visual theme.
enum AppMotion {
    static let feedbackDuration: TimeInterval = 0.15
    static let chromeHideDuration: TimeInterval = 0.20

    static func navigation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9)
    }

    static func press(isPressed: Bool, reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.08) }
        return isPressed ? .easeOut(duration: 0.065) : .spring(response: 0.25, dampingFraction: 0.82)
    }

    static func chrome(showing: Bool, reduceMotion: Bool) -> Animation {
        .easeOut(duration: reduceMotion ? 0.1 : showing ? 0.16 : chromeHideDuration)
    }

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

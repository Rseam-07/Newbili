import SwiftUI
import UIKit

/// Neutral depth for dark content surfaces. Light appearance keeps the
/// existing system colors; glass continues to use the system material.
enum AppSurfaceColors {
    static let page = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1)
            : .systemBackground
    })
    static let groupedPage = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1)
            : .systemGroupedBackground
    })
    static let groupedCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.112, blue: 0.135, alpha: 1)
            : .secondarySystemGroupedBackground
    })
    static let darkGlassTint = Color(red: 0.73, green: 0.80, blue: 0.94).opacity(0.055)
    static let darkHomeGradient = [
        Color(red: 0.07, green: 0.078, blue: 0.10),
        Color(red: 0.085, green: 0.09, blue: 0.115),
        Color(red: 0.045, green: 0.052, blue: 0.065)
    ]
}

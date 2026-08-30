import SwiftUI

enum HomeEditorialPalette {
    static let background = Color(red: 0.018, green: 0.018, blue: 0.020)
    static let surface = Color(red: 0.070, green: 0.070, blue: 0.078)
    static let elevatedSurface = Color(red: 0.105, green: 0.105, blue: 0.116)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let tertiaryText = Color.white.opacity(0.54)
    static let divider = Color.white.opacity(0.14)
    static let strongDivider = Color.white.opacity(0.26)
    static let accent = Color(red: 0.984, green: 0.447, blue: 0.600)
    static let selectedFill = Color.white
    static let selectedForeground = Color.black
}

nonisolated enum HomeEditorialLayoutPolicy {
    static let wideLayoutMinimumWidth: CGFloat = 700

    static func horizontalInset(containerWidth: CGFloat) -> CGFloat {
        if containerWidth >= 1_100 { return 48 }
        if containerWidth >= wideLayoutMinimumWidth { return 28 }
        return 16
    }

    static func heroHeight(containerWidth: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let inset = horizontalInset(containerWidth: containerWidth)
        let availableWidth = max(containerWidth - inset * 2, 0)
        if containerWidth >= wideLayoutMinimumWidth {
            let viewportLimit = viewportHeight > 0 ? viewportHeight * 0.44 : 420
            return min(max(availableWidth * 0.42, 320), min(viewportLimit, 420))
        }
        return min(max(availableWidth * 0.66, 238), 276)
    }

    static func heroCornerRadius(containerWidth: CGFloat) -> CGFloat {
        containerWidth >= wideLayoutMinimumWidth ? 28 : 22
    }

    static func usesWideFeatureCard(containerWidth: CGFloat) -> Bool {
        containerWidth >= wideLayoutMinimumWidth
    }

    static func wideFeatureCardHeight(containerWidth: CGFloat) -> CGFloat {
        min(max(containerWidth * 0.32, 286), 340)
    }
}

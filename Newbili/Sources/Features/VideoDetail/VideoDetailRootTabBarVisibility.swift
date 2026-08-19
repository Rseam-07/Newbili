import SwiftUI

enum PlaybackDetailTabBarRestoreTiming {
    case alongsideNavigationTransition
    case afterNavigationTransition
}

extension View {
    @ViewBuilder
    func hideRootTabBarWhenNeeded(
        _ isHidden: Bool,
        restoreTiming: PlaybackDetailTabBarRestoreTiming = .alongsideNavigationTransition
    ) -> some View {
        if isHidden {
            hidesRootTabBarOnPush(
                restoresAfterTransition: restoreTiming == .afterNavigationTransition
            )
        } else {
            self
        }
    }
}

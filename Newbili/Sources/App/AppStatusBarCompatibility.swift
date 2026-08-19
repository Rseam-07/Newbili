import UIKit

/// SwiftUI's root host owns the status-bar style on current iOS releases.
/// Playback pages use this compatibility path so their black portrait chrome
/// retains readable system glyphs without changing the page color scheme.
@MainActor
enum AppStatusBarCompatibility {
    static func applyPlaybackPresentation(
        isHidden: Bool,
        style: UIStatusBarStyle = .lightContent
    ) {
        UIApplication.shared.statusBarStyle = style
        UIApplication.shared.setStatusBarHidden(isHidden, with: .none)
    }

    static func restoreDefaultPresentation() {
        UIApplication.shared.statusBarStyle = .default
        UIApplication.shared.setStatusBarHidden(false, with: .none)
    }
}

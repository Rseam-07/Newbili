import UIKit

struct VideoDetailFullscreenMorphState {
    enum Phase: Equatable {
        case entering
        case exiting
    }

    let phase: Phase
    let snapshot: PlaybackTransitionSnapshot
    let sourceFrame: CGRect
    let targetFrame: CGRect
    let orientation: UIDeviceOrientation
    let usesWindowMask: Bool
    var progress: Double
    var opacity: Double

    var isActive: Bool {
        opacity > 0
    }
}

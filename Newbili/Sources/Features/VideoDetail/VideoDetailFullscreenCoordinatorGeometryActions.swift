import UIKit

extension VideoDetailFullscreenCoordinator {
    func requestInlineFullscreenGeometry(for mode: PlayerFullscreenMode) {
        let scene = UIApplication.shared.videoDetailKeyWindow?.windowScene
            ?? UIApplication.shared.playbackDetailForegroundWindowScene
        AppOrientationLock.requestPlaybackDetailGeometry(for: mode, in: scene)
    }

    func requestInlineFullscreenGeometryAfterLayout(for mode: PlayerFullscreenMode) {
        let revision = stateRevision
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self,
                  self.isCurrentStateRevision(revision),
                  self.mode == mode
            else { return }
            self.requestInlineFullscreenGeometry(for: mode)
        }
    }

    func requestInlinePortraitGeometry() {
        let scene = UIApplication.shared.videoDetailKeyWindow?.windowScene
            ?? UIApplication.shared.playbackDetailForegroundWindowScene
        AppOrientationLock.update(
            to: .portrait,
            in: scene,
            requestsGeometryUpdate: true
        )
    }

    func requestInlinePortraitGeometryAfterLayout() {
        let revision = stateRevision
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self,
                  self.isCurrentStateRevision(revision),
                  self.mode == nil
            else { return }
            self.requestInlinePortraitGeometry()
        }
    }

    func preferredLandscapeDeviceOrientation() -> UIDeviceOrientation {
        if let orientation = UIApplication.shared.videoDetailKeyWindow?.windowScene?.effectiveGeometry.interfaceOrientation
            ?? UIApplication.shared.playbackDetailForegroundWindowScene?.effectiveGeometry.interfaceOrientation,
           orientation.isLandscape {
            return orientation == .landscapeLeft ? .landscapeRight : .landscapeLeft
        }
        return .landscapeLeft
    }
}

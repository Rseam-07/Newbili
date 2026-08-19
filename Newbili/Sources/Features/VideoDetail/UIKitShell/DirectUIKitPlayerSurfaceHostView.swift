import AVFoundation
import UIKit

@MainActor
protocol VideoDetailPlayerSurfaceHostingView: AnyObject {
    var hostedView: UIView { get }

    func attach(to parent: UIViewController)
    func setPlayerViewModel(_ playerViewModel: PlayerStateViewModel)
    func setPictureInPictureEnabled(_ isEnabled: Bool)
    func setPrefersNativePlaybackControls(_ isEnabled: Bool)
    func setVideoGravity(_ gravity: AVLayerVideoGravity)
    func refreshLayoutImmediately()
    func tearDown()
}

extension VideoDetailPlayerSurfaceHostingView {
    func tearDown() {}
    func setPrefersNativePlaybackControls(_: Bool) {}
}

extension UIKitPlayerSurfaceHostView: VideoDetailPlayerSurfaceHostingView {
    var hostedView: UIView { self }
}

/// Keeps the video surface entirely in UIKit.
/// SwiftUI continues to own playback controls and danmaku in the overlay host.
@MainActor
final class DirectUIKitPlayerSurfaceHostView: UIView, VideoDetailPlayerSurfaceHostingView {
    private var viewModel: PlayerStateViewModel
    private var isPictureInPictureEnabled: Bool
    private var prefersNativePlaybackControls: Bool
    private let surfaceView = VideoSurfaceContainerView()
    private var isTornDown = false

    var hostedView: UIView { self }

    init(
        viewModel: PlayerStateViewModel,
        isPictureInPictureEnabled: Bool,
        prefersNativePlaybackControls: Bool = false
    ) {
        self.viewModel = viewModel
        self.isPictureInPictureEnabled = isPictureInPictureEnabled
        self.prefersNativePlaybackControls = prefersNativePlaybackControls
        super.init(frame: .zero)

        backgroundColor = .black
        isUserInteractionEnabled = prefersNativePlaybackControls
        surfaceView.backgroundColor = .black
        surfaceView.disablesImplicitLayoutAnimations = true
        surfaceView.configureSurfaceHandoff(
            usesLiveSurfaceDuringLayoutTransition: true,
            isLayoutTransitioning: true
        )
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surfaceView)
        NSLayoutConstraint.activate([
            surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        bindSurface(to: viewModel, startsPlayback: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(to _: UIViewController) {
        // Rebind after entering the controller hierarchy so AVPlayerViewController
        // can install itself when native controls are selected.
        bindSurface(to: viewModel, startsPlayback: false)
    }

    func setPlayerViewModel(_ playerViewModel: PlayerStateViewModel) {
        guard !isTornDown else { return }
        guard viewModel !== playerViewModel else { return }
        viewModel.detachSurface(
            surfaceView,
            preservesReadinessDuringSurfaceHandoff: viewModel.hasPresentedPlayback
        )
        viewModel = playerViewModel
        bindSurface(to: playerViewModel, startsPlayback: playerViewModel.wantsAutoplay)
    }

    func setPictureInPictureEnabled(_ isEnabled: Bool) {
        guard !isTornDown else { return }
        isPictureInPictureEnabled = isEnabled
        surfaceView.setPictureInPictureEnabled(isEnabled)
        viewModel.setPictureInPictureEnabled(isEnabled)
    }

    func setPrefersNativePlaybackControls(_ isEnabled: Bool) {
        guard prefersNativePlaybackControls != isEnabled else {
            if isEnabled {
                bindSurface(to: viewModel, startsPlayback: false)
            }
            return
        }
        prefersNativePlaybackControls = isEnabled
        isUserInteractionEnabled = isEnabled
        bindSurface(to: viewModel, startsPlayback: false)
    }

    func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        guard !isTornDown else { return }
        viewModel.setVideoGravity(gravity)
    }

    func refreshLayoutImmediately() {
        guard !isTornDown else { return }
        UIView.performWithoutAnimation {
            setNeedsLayout()
            layoutIfNeeded()
            surfaceView.configureBoundsRefresh(for: viewModel)
            surfaceView.invalidateVideoLayout()
            viewModel.refreshSurfaceLayout()
        }
    }

    func tearDown() {
        guard !isTornDown else { return }
        isTornDown = true
        surfaceView.detachPlayerSurface()
        surfaceView.removeFromSuperview()
    }

    private func bindSurface(to playerViewModel: PlayerStateViewModel, startsPlayback: Bool) {
        surfaceView.configureBoundsRefresh(for: playerViewModel)
        surfaceView.setPictureInPictureEnabled(isPictureInPictureEnabled)
        surfaceView.setShowsSystemPlaybackControls(prefersNativePlaybackControls)
        surfaceView.setPlayerViewModel(
            playerViewModel,
            prefersNativePlaybackControls: prefersNativePlaybackControls
        )
        playerViewModel.setPictureInPictureEnabled(isPictureInPictureEnabled)
        playerViewModel.attachSurface(
            surfaceView,
            prefersNativePlaybackControls: prefersNativePlaybackControls,
            preservesReadinessDuringSurfaceHandoff: surfaceView.isLiveSurfaceHandoffActive
        )
        playerViewModel.endSurfaceMigrationHold()
        surfaceView.setNeedsLayout()
        surfaceView.invalidateVideoLayout()
        if startsPlayback {
            playerViewModel.play()
        }
    }

}

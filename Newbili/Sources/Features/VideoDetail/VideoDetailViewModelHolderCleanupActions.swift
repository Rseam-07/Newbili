import Foundation

@MainActor
struct VideoDetailViewModelHolderCleanupActions {
    let viewModel: VideoDetailViewModel

    func makeCleanupPlayback() -> () -> Void {
        { [viewModel] in
            Task { @MainActor [viewModel] in
                if AudioMiniPlayerCoordinator.shared.shouldKeepAlive(viewModel) {
                    viewModel.persistVideoListenPlaybackSession()
                } else {
                    viewModel.stopPlaybackForNavigation()
                }
            }
        }
    }
}

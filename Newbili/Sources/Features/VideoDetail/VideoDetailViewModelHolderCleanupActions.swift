import Foundation

@MainActor
struct VideoDetailViewModelHolderCleanupActions {
    let viewModel: VideoDetailViewModel

    func makeCleanupPlayback() -> () -> Void {
        { [viewModel] in
            Task { @MainActor [viewModel] in
                viewModel.stopPlaybackForNavigation()
            }
        }
    }
}

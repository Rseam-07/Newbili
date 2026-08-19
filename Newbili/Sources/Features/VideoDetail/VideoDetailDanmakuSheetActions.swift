import Foundation

@MainActor
struct VideoDetailDanmakuSheetActions {
    let viewModel: VideoDetailViewModel

    func toggleDanmaku() {
        viewModel.toggleDanmaku()
    }

    func updateDanmakuSettings(_ settings: DanmakuSettings) {
        viewModel.updateDanmakuSettings(settings)
    }
}

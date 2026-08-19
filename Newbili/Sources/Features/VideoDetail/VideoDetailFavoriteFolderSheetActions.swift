import Foundation

@MainActor
struct VideoDetailFavoriteFolderSheetActions {
    let viewModel: VideoDetailViewModel

    func loadFavoriteFolders(forceRefresh: Bool) async {
        await viewModel.loadFavoriteFoldersForCurrentVideo(forceRefresh: forceRefresh)
    }

    func saveFavoriteFolders(selectedIDs: Set<Int>) async -> Bool {
        return await viewModel.setFavoriteFolders(selectedIDs: selectedIDs)
    }
}

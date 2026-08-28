import Combine
import SwiftUI

nonisolated struct UploaderAccountContext: Equatable, Sendable {
    let mainCredentialVersion: Int
    let dynamicFeedCredentialVersion: Int
    let interactionCredentialVersion: Int
    let multiAccountExperimentEnabled: Bool

    @MainActor
    init(sessionStore: SessionStore, libraryStore: LibraryStore) {
        mainCredentialVersion = sessionStore.playbackCredentialVersion
        dynamicFeedCredentialVersion = sessionStore.dynamicFeedAccountCredentialVersion
        interactionCredentialVersion = sessionStore.interactionAccountCredentialVersion
        multiAccountExperimentEnabled = libraryStore.multiAccountExperimentEnabled
    }
}

@MainActor
final class UploaderViewModelHolder: ObservableObject {
    @Published var viewModel: UploaderViewModel?
    private var cancellable: AnyCancellable?
    private var lastSnapshot: UploaderRenderSnapshot?
    private var accountContext: UploaderAccountContext?

    func configure(
        owner: VideoOwner,
        api: BiliAPIClient,
        sessionStore: SessionStore,
        libraryStore: LibraryStore,
        accountContext: UploaderAccountContext
    ) {
        guard viewModel?.seedOwner.mid != owner.mid || self.accountContext != accountContext else { return }
        let viewModel = UploaderViewModel(
            seedOwner: owner,
            api: api,
            sessionStore: sessionStore,
            libraryStore: libraryStore
        )
        self.accountContext = accountContext
        self.viewModel = viewModel
        lastSnapshot = UploaderRenderSnapshot(viewModel)
        cancellable = viewModel.objectWillChange.sink { [weak self, weak viewModel] _ in
            Task { @MainActor [weak self, weak viewModel] in
                guard let self, let viewModel else { return }
                let snapshot = UploaderRenderSnapshot(viewModel)
                guard snapshot != self.lastSnapshot else { return }
                self.lastSnapshot = snapshot
                self.objectWillChange.send()
            }
        }
    }
}

private struct UploaderRenderSnapshot: Equatable {
    let state: LoadingState
    let profileState: LoadingState
    let profileRevision: Int
    let videosRevision: Int
    let videoOrder: UploaderVideoOrder
    let hasMoreVideos: Bool
    let dynamicItemsRevision: Int
    let videoCount: Int
    let dynamicItemCount: Int
    let firstVideoID: String?
    let lastVideoID: String?
    let firstDynamicItemID: String?
    let lastDynamicItemID: String?
    let isFollowing: Bool
    let followerCount: Int?
    let followingCount: Int?
    let likeCount: Int?
    let archiveCount: Int?
    let isMutatingFollow: Bool
    let followMessage: String?
    let dynamicState: LoadingState

    init(_ viewModel: UploaderViewModel) {
        state = viewModel.state
        profileState = viewModel.profileState
        profileRevision = viewModel.profileRevision
        videosRevision = viewModel.videosRevision
        videoOrder = viewModel.videoOrder
        hasMoreVideos = viewModel.hasMoreVideos
        dynamicItemsRevision = viewModel.dynamicItemsRevision
        videoCount = viewModel.videos.count
        dynamicItemCount = viewModel.dynamicItems.count
        firstVideoID = viewModel.videos.first?.id
        lastVideoID = viewModel.videos.last?.id
        firstDynamicItemID = viewModel.dynamicItems.first?.id
        lastDynamicItemID = viewModel.dynamicItems.last?.id
        isFollowing = viewModel.isFollowing
        followerCount = viewModel.followerCount
        followingCount = viewModel.followingCount
        likeCount = viewModel.likeCount
        archiveCount = viewModel.archiveCount
        isMutatingFollow = viewModel.isMutatingFollow
        followMessage = viewModel.followMessage
        dynamicState = viewModel.dynamicState
    }
}

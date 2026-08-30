import Foundation

nonisolated struct HomeFeedImageLookaheadRequest: Equatable {
    let feedRootBVID: String
    let startIndex: Int
    let profile: HomeFeedCoverPrefetchProfile
    let windowContentIdentity: [String]

    static func contentIdentity(
        for videos: [VideoItem],
        startIndex: Int,
        limit: Int
    ) -> [String] {
        guard limit > 0, startIndex < videos.count else { return [] }
        let lowerBound = max(0, startIndex)
        let upperBound = min(videos.count, lowerBound + limit)
        return videos[lowerBound..<upperBound].map { video in
            "\(video.bvid)\u{1F}\(video.pic ?? "")"
        }
    }

    static func clearingAttemptIfCurrent(
        current: Self?,
        attempted: Self
    ) -> Self? {
        current == attempted ? nil : current
    }
}

@MainActor
final class HomeFeedMediaPreloadCoordinator {
    let api: BiliAPIClient
    let libraryStore: LibraryStore
    var imagePrefetchTask: Task<Void, Never>?
    var imageLookaheadTask: Task<Void, Never>?
    var playbackPreloadTask: Task<Void, Never>?
    var imagePrefetchProfile: HomeFeedCoverPrefetchProfile?
    var imageLookaheadRequest: HomeFeedImageLookaheadRequest?
    var imageLookaheadFeedRootBVID = ""

    init(api: BiliAPIClient, libraryStore: LibraryStore) {
        self.api = api
        self.libraryStore = libraryStore
    }

    deinit {
        imagePrefetchTask?.cancel()
        imageLookaheadTask?.cancel()
        playbackPreloadTask?.cancel()
    }
}

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var videos: [VideoItem] = []
    private(set) var videoCells: [HomeVideoCellModel] = []
    @Published private(set) var featuredItems: [HomeFeaturedItem] = []
    @Published private(set) var lastSeenMarkerIndex: Int?
    @Published var state: LoadingState = .loading
    @Published var mode: HomeFeedMode = .recommend
    @Published var isRefreshing = false
    @Published var isUserRefreshing = false

    static let userRefreshRecommendationCount = 10
    private let libraryStore: LibraryStore
    private let sessionStore: SessionStore
    var requestRevision = 0
    var lastUserRefreshDate: Date?
    private var recommendContextCancellable: AnyCancellable?
    let pageCoordinator: HomeFeedPageCoordinator
    let snapshotCoordinator: HomeFeedSnapshotCoordinator
    let mediaPreloadCoordinator: HomeFeedMediaPreloadCoordinator
    let exposureRecorder: HomeFeedExposureRecorder
    var cellStore = HomeFeedCellStore()
    var featuredPopularCellStore = HomeFeedCellStore()
    var featuredPopularCells: [HomeVideoCellModel] = []
    var featuredPopularLastRefreshDate: Date?
    var recommendMetadataHydrationTasks: [String: Task<Void, Never>] = [:]

    init(
        api: BiliAPIClient,
        libraryStore: LibraryStore,
        sessionStore: SessionStore,
        initialMode: HomeFeedMode = .recommend
    ) {
        self.libraryStore = libraryStore
        self.sessionStore = sessionStore
        pageCoordinator = HomeFeedPageCoordinator(
            api: api,
            libraryStore: libraryStore
        )
        snapshotCoordinator = HomeFeedSnapshotCoordinator(
            libraryStore: libraryStore,
            sessionStore: sessionStore
        )
        mediaPreloadCoordinator = HomeFeedMediaPreloadCoordinator(
            api: api,
            libraryStore: libraryStore
        )
        exposureRecorder = HomeFeedExposureRecorder(pageCoordinator: pageCoordinator)
        mode = initialMode
        recommendContextCancellable = Publishers.CombineLatest4(
            libraryStore.$guestModeEnabled,
            libraryStore.$homeRecommendFeedSourcePreference,
            sessionStore.$sessdata,
            sessionStore.$accessKey
        )
            .removeDuplicates { lhs, rhs in
                lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2 && lhs.3 == rhs.3
            }
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.reloadForRecommendContextChange() }
            }
    }

    deinit {
        recommendMetadataHydrationTasks.values.forEach { $0.cancel() }
    }

    func updateFeed(_ newVideos: [VideoItem]) {
        videoCells = cellStore.update(with: newVideos)
        rebuildFeaturedItems()
        videos = newVideos
    }

    var featuredCurrentFeedItemCount: Int {
        featuredItems.lazy.filter { $0.source == .currentFeed }.count
    }

    func updateFeaturedPopularVideos(_ videos: [VideoItem], refreshedAt date: Date) {
        featuredPopularCells = featuredPopularCellStore.update(with: videos)
        featuredPopularLastRefreshDate = date
        rebuildFeaturedItems()
    }

    private func rebuildFeaturedItems() {
        let currentFeedCandidates = Array(videoCells.prefix(HomeFeaturedMixPolicy.maximumItemCount))
        let popularCandidates = Array(featuredPopularCells.prefix(HomeFeaturedMixPolicy.maximumItemCount))
        let currentByID = Dictionary(
            currentFeedCandidates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let popularByID = Dictionary(
            popularCandidates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let selections = HomeFeaturedMixPolicy.selections(
            currentFeedIDs: currentFeedCandidates.map(\.id),
            popularIDs: popularCandidates.map(\.id),
            includesPopular: mode == .recommend
        )
        let nextItems = selections.compactMap { selection -> HomeFeaturedItem? in
            let cell = switch selection.source {
            case .currentFeed: currentByID[selection.id]
            case .popular: popularByID[selection.id]
            }
            guard let cell else { return nil }
            return HomeFeaturedItem(cell: cell, source: selection.source)
        }
        guard featuredItems != nextItems else { return }
        featuredItems = nextItems
    }

    func updateLastSeenMarkerIndex(_ index: Int?) {
        guard let index, index > 0, index < videos.count else {
            lastSeenMarkerIndex = nil
            return
        }
        lastSeenMarkerIndex = index
    }

    func recordRecommendExposure(_ video: VideoItem, index: Int) {
        guard mode == .recommend else { return }
        HomeRecommendFeedbackCenter.shared.recordExposure(
            video: video,
            index: index,
            source: libraryStore.homeRecommendFeedSourcePreference
        )
    }

    func updateImagePrefetchProfile(_ profile: HomeFeedCoverPrefetchProfile) {
        mediaPreloadCoordinator.updateImagePrefetchProfile(profile)
        mediaPreloadCoordinator.scheduleImagePrefetch(for: videos)
    }

    func scheduleImageLookahead(visibleIndex: Int) {
        mediaPreloadCoordinator.scheduleImageLookahead(for: videos, visibleIndex: visibleIndex)
    }

    func recordRecommendClick(_ video: VideoItem) {
        guard mode == .recommend else { return }
        HomeRecommendFeedbackCenter.shared.recordClick(
            video: video,
            source: libraryStore.homeRecommendFeedSourcePreference
        )
    }

}

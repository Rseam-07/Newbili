import Combine
import Foundation

@MainActor
final class DynamicViewModel: ObservableObject {
    @Published var items: [DynamicFeedItem] = [] {
        didSet {
            itemsRevision &+= 1
        }
    }
    @Published private(set) var topUploaderStripItems: [DynamicTopUploaderStripItem] = [] {
        didSet {
            topUploaderStripRevision &+= 1
        }
    }
    @Published private(set) var isTopUploaderStripLoading = false
    @Published private(set) var isRefreshing = false
    @Published var state: LoadingState = .idle
    @Published private(set) var itemsRevision = 0
    @Published private(set) var topUploaderStripRevision = 0

    private let lifecycleCoordinator: DynamicFeedLifecycleCoordinator
    private let likeControllers: DynamicLikeControllerRegistry
    private var filterCancellable: AnyCancellable?

    var hasMoreItems: Bool {
        lifecycleCoordinator.hasMoreItems
    }

    init(api: BiliAPIClient, libraryStore: LibraryStore, sessionStore: SessionStore) {
        likeControllers = DynamicLikeControllerRegistry(
            api: api,
            sessionStore: sessionStore,
            libraryStore: libraryStore
        )
        let contentFilter = DynamicFeedContentFilter(libraryStore: libraryStore)
        let resourcePrefetchCoordinator = DynamicFeedResourcePrefetchCoordinator(
            api: api,
            libraryStore: libraryStore
        )
        lifecycleCoordinator = DynamicFeedLifecycleCoordinator(
            api: api,
            sessionStore: sessionStore,
            libraryStore: libraryStore,
            contentFilter: contentFilter,
            resourcePrefetchCoordinator: resourcePrefetchCoordinator
        )
        filterCancellable = libraryStore.$blocksAdDynamics
            .combineLatest(libraryStore.$blocksGoodsDynamics)
            .combineLatest(libraryStore.$blockedDynamicKeywords)
            .removeDuplicates { lhs, rhs in
                lhs.0.0 == rhs.0.0
                    && lhs.0.1 == rhs.0.1
                    && lhs.1 == rhs.1
            }
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyCurrentFilter()
            }
    }

    func loadInitial() async {
        guard items.isEmpty else { return }
        guard lifecycleCoordinator.isLoggedIn else {
            prepareLoggedOutState()
            return
        }
        state = .loading
        isTopUploaderStripLoading = true
        let likeBaseline = likeControllers.reconciliationBaseline()
        do {
            replaceItems(
                try await lifecycleCoordinator.loadInitialPage(),
                likeBaseline: likeBaseline
            )
            refreshTopUploaderStrip()
            state = .loaded
        } catch {
            isTopUploaderStripLoading = false
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        guard lifecycleCoordinator.isLoggedIn, !isRefreshing else {
            if !lifecycleCoordinator.isLoggedIn {
                prepareLoggedOutState()
            }
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false
        }
        state = .loading
        isTopUploaderStripLoading = true
        let likeBaseline = likeControllers.reconciliationBaseline()
        do {
            let refreshedItems = try await lifecycleCoordinator.refreshPage()
            replaceItems(refreshedItems, likeBaseline: likeBaseline)
            refreshTopUploaderStrip()
            state = .loaded
        } catch {
            isTopUploaderStripLoading = false
            state = .failed(error.localizedDescription)
        }
    }

    func loadMoreIfNeeded(current item: DynamicFeedItem?) async {
        guard let item, items.last?.id == item.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard lifecycleCoordinator.isLoggedIn else {
            prepareLoggedOutState()
            return
        }
        guard lifecycleCoordinator.hasMoreItems, !state.isLoading else { return }
        state = .loading
        let likeBaseline = likeControllers.reconciliationBaseline()
        do {
            replaceItems(
                try await lifecycleCoordinator.loadMorePage(),
                likeBaseline: likeBaseline
            )
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func likeController(for item: DynamicFeedItem) -> DynamicLikeController {
        likeControllers.controller(for: item)
    }

    private func prepareLoggedOutState() {
        lifecycleCoordinator.prepareLoggedOutState()
        likeControllers.hardReset(keepingCapacity: false)
        items = []
        topUploaderStripItems = []
        isTopUploaderStripLoading = false
        state = .idle
    }

    private func applyCurrentFilter() {
        let filteredItems = lifecycleCoordinator.filteredCurrentItems()
        likeControllers.prune(keepingDynamicIDs: Set(filteredItems.map(\.id)))
        items = filteredItems
    }

    private func replaceItems(
        _ newItems: [DynamicFeedItem],
        likeBaseline: DynamicLikeControllerRegistry.ReconciliationBaseline
    ) {
        likeControllers.reconcile(
            items: newItems,
            baseline: likeBaseline,
            pruningMissingItems: true
        )
        items = newItems
    }

    private func refreshTopUploaderStrip() {
        isTopUploaderStripLoading = true
        lifecycleCoordinator.refreshTopUploaderStripItems { [weak self] items in
            self?.topUploaderStripItems = items
            self?.isTopUploaderStripLoading = false
        }
    }
}

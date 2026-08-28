import Combine
import Foundation

nonisolated enum DynamicLikeMutationOutcome: Equatable {
    case updated(isLiked: Bool)
    case failed(message: String)
    case ignored
}

nonisolated enum DynamicLikeStatus: Equatable {
    case loading
    case ready(isLiked: Bool, likeCount: Int)
    case failed(message: String)
}

nonisolated struct DynamicLikeFeedSnapshot: Equatable, Sendable {
    let dynamicID: String
    let isLiked: Bool
    let likeCount: Int

    init(dynamicID: String, isLiked: Bool, likeCount: Int) {
        self.dynamicID = dynamicID
        self.isLiked = isLiked
        self.likeCount = max(0, likeCount)
    }

    init(item: DynamicFeedItem) {
        self.init(
            dynamicID: item.id,
            isLiked: item.isLiked,
            likeCount: item.likeCount ?? 0
        )
    }
}

nonisolated struct DynamicLikeAccountContext: Equatable, Sendable {
    let interactionIdentityKey: String
    let adoptsDynamicFeedState: Bool

    @MainActor
    init(sessionStore: SessionStore, libraryStore: LibraryStore) {
        let multiAccountEnabled = libraryStore.multiAccountExperimentEnabled
        let dynamicFeed = sessionStore.credentialSnapshot(
            for: .dynamicFeed,
            multiAccountEnabled: multiAccountEnabled
        )
        let interaction = sessionStore.credentialSnapshot(
            for: .interaction,
            multiAccountEnabled: multiAccountEnabled
        )
        interactionIdentityKey = sessionStore.accountCacheIdentityKey(
            for: .interaction,
            multiAccountEnabled: multiAccountEnabled
        )
        adoptsDynamicFeedState = dynamicFeed.isLoggedIn
            && interaction.isLoggedIn
            && dynamicFeed.accountMID == interaction.accountMID
    }

    init(interactionIdentityKey: String, adoptsDynamicFeedState: Bool) {
        self.interactionIdentityKey = interactionIdentityKey
        self.adoptsDynamicFeedState = adoptsDynamicFeedState
    }
}

@MainActor
final class DynamicLikeController: ObservableObject {
    typealias Mutation = (_ dynamicID: String, _ liked: Bool) async throws -> Void
    typealias Hydration = (_ dynamicID: String) async throws -> DynamicLikeStateSnapshot

    let dynamicID: String
    @Published private(set) var status: DynamicLikeStatus
    @Published private(set) var isMutating = false
    @Published private(set) var isHydrating = false

    private let mutation: Mutation
    private let hydration: Hydration?
    private(set) var mutationRevision: UInt64 = 0

    var isLiked: Bool {
        guard case .ready(let isLiked, _) = status else { return false }
        return isLiked
    }

    var likeCount: Int {
        guard case .ready(_, let likeCount) = status else { return 0 }
        return likeCount
    }

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = status { return true }
        return false
    }

    var hydrationFailureMessage: String? {
        guard case .failed(let message) = status else { return nil }
        return message
    }

    var isBusy: Bool {
        isMutating || isHydrating
    }

    init(
        dynamicID: String,
        isLiked: Bool,
        likeCount: Int,
        mutation: @escaping Mutation
    ) {
        self.dynamicID = dynamicID
        status = .ready(isLiked: isLiked, likeCount: max(0, likeCount))
        self.mutation = mutation
        hydration = nil
    }

    init(
        dynamicID: String,
        initialStatus: DynamicLikeStatus,
        mutation: @escaping Mutation,
        hydration: Hydration?
    ) {
        self.dynamicID = dynamicID
        status = Self.normalized(initialStatus)
        self.mutation = mutation
        self.hydration = hydration
    }

    func hydrateIfNeeded(retryingFailure: Bool = false) async {
        guard !isHydrating, !isMutating, let hydration else { return }
        switch status {
        case .loading:
            break
        case .failed where retryingFailure:
            status = .loading
        case .failed, .ready:
            return
        }

        isHydrating = true
        do {
            let snapshot = try await hydration(dynamicID)
            guard !Task.isCancelled else {
                isHydrating = false
                return
            }
            status = .ready(
                isLiked: snapshot.isLiked,
                likeCount: max(0, snapshot.likeCount)
            )
        } catch is CancellationError {
            // Keep the unresolved state so a later visible card can resume hydration.
        } catch {
            status = .failed(message: error.localizedDescription)
        }
        isHydrating = false
    }

    func toggle() async -> DynamicLikeMutationOutcome {
        guard !isMutating,
              !isHydrating,
              case .ready(let previousIsLiked, let previousLikeCount) = status
        else { return .ignored }

        let targetIsLiked = !previousIsLiked
        mutationRevision &+= 1
        isMutating = true
        status = .ready(
            isLiked: targetIsLiked,
            likeCount: max(0, previousLikeCount + (targetIsLiked ? 1 : -1))
        )

        do {
            try await mutation(dynamicID, targetIsLiked)
            isMutating = false
            return .updated(isLiked: targetIsLiked)
        } catch {
            status = .ready(
                isLiked: previousIsLiked,
                likeCount: previousLikeCount
            )
            isMutating = false
            return .failed(message: error.localizedDescription)
        }
    }

    func reconcile(
        _ snapshot: DynamicLikeFeedSnapshot,
        expectedMutationRevision: UInt64?
    ) {
        guard snapshot.dynamicID == dynamicID,
              !isMutating,
              expectedMutationRevision == nil || expectedMutationRevision == mutationRevision
        else { return }
        status = .ready(
            isLiked: snapshot.isLiked,
            likeCount: max(0, snapshot.likeCount)
        )
    }

    private nonisolated static func normalized(_ status: DynamicLikeStatus) -> DynamicLikeStatus {
        guard case .ready(let isLiked, let likeCount) = status else { return status }
        return .ready(isLiked: isLiked, likeCount: max(0, likeCount))
    }
}

@MainActor
private final class DynamicLikeHydrationGate {
    private let limit: Int
    private var activeCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func run<Result>(_ operation: () async throws -> Result) async throws -> Result {
        await acquire()
        do {
            try Task.checkCancellation()
            let result = try await operation()
            release()
            return result
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async {
        if activeCount < limit {
            activeCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            activeCount = max(0, activeCount - 1)
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor
final class DynamicLikeControllerRegistry {
    nonisolated struct ReconciliationBaseline: Equatable, Sendable {
        fileprivate let revisionsByDynamicID: [String: UInt64]
        fileprivate let mutatingDynamicIDs: Set<String>
    }

    private struct CacheKey: Hashable {
        let interactionIdentityKey: String
        let dynamicID: String
    }

    private let accountContext: DynamicLikeAccountContext
    private let mutation: DynamicLikeController.Mutation
    private let hydration: DynamicLikeController.Hydration
    private let hydrationGate: DynamicLikeHydrationGate
    private var controllers: [CacheKey: DynamicLikeController] = [:]

    convenience init(
        api: BiliAPIClient,
        sessionStore: SessionStore,
        libraryStore: LibraryStore,
        maximumConcurrentHydrations: Int = 4
    ) {
        self.init(
            accountContext: DynamicLikeAccountContext(
                sessionStore: sessionStore,
                libraryStore: libraryStore
            ),
            maximumConcurrentHydrations: maximumConcurrentHydrations,
            mutation: { [api] dynamicID, liked in
                try await api.setDynamicLiked(dynamicID: dynamicID, liked: liked)
            },
            hydration: { [api] dynamicID in
                try await api.fetchDynamicLikeState(dynamicID: dynamicID)
            }
        )
    }

    init(
        accountContext: DynamicLikeAccountContext,
        maximumConcurrentHydrations: Int = 4,
        mutation: @escaping DynamicLikeController.Mutation,
        hydration: @escaping DynamicLikeController.Hydration
    ) {
        self.accountContext = accountContext
        self.mutation = mutation
        self.hydration = hydration
        hydrationGate = DynamicLikeHydrationGate(limit: maximumConcurrentHydrations)
    }

    func controller(for item: DynamicFeedItem) -> DynamicLikeController {
        controller(for: DynamicLikeFeedSnapshot(item: item))
    }

    func controller(for snapshot: DynamicLikeFeedSnapshot) -> DynamicLikeController {
        let key = cacheKey(for: snapshot.dynamicID)
        if let controller = controllers[key] {
            return controller
        }

        let initialStatus: DynamicLikeStatus = accountContext.adoptsDynamicFeedState
            ? .ready(isLiked: snapshot.isLiked, likeCount: snapshot.likeCount)
            : .loading
        let hydration: DynamicLikeController.Hydration? = accountContext.adoptsDynamicFeedState
            ? nil
            : { [hydration, hydrationGate] dynamicID in
                try await hydrationGate.run {
                    try await hydration(dynamicID)
                }
            }
        let controller = DynamicLikeController(
            dynamicID: snapshot.dynamicID,
            initialStatus: initialStatus,
            mutation: mutation,
            hydration: hydration
        )
        controllers[key] = controller
        return controller
    }

    func reconciliationBaseline() -> ReconciliationBaseline {
        ReconciliationBaseline(
            revisionsByDynamicID: Dictionary(
                uniqueKeysWithValues: controllers.values.map {
                    ($0.dynamicID, $0.mutationRevision)
                }
            ),
            mutatingDynamicIDs: Set(
                controllers.values.lazy
                    .filter(\.isMutating)
                    .map(\.dynamicID)
            )
        )
    }

    func reconcile(
        items: [DynamicFeedItem],
        baseline: ReconciliationBaseline,
        pruningMissingItems: Bool
    ) {
        reconcile(
            snapshots: items.map(DynamicLikeFeedSnapshot.init),
            baseline: baseline,
            pruningMissingItems: pruningMissingItems
        )
    }

    func reconcile(
        snapshots: [DynamicLikeFeedSnapshot],
        baseline: ReconciliationBaseline,
        pruningMissingItems: Bool
    ) {
        let visibleIDs = Set(snapshots.map(\.dynamicID))
        if accountContext.adoptsDynamicFeedState {
            for snapshot in snapshots where !baseline.mutatingDynamicIDs.contains(snapshot.dynamicID) {
                guard let controller = controllers[cacheKey(for: snapshot.dynamicID)] else { continue }
                controller.reconcile(
                    snapshot,
                    expectedMutationRevision: baseline.revisionsByDynamicID[snapshot.dynamicID] ?? 0
                )
            }
        }
        if pruningMissingItems {
            controllers = controllers.filter { key, controller in
                key.interactionIdentityKey == accountContext.interactionIdentityKey
                    && (visibleIDs.contains(key.dynamicID) || controller.isBusy)
            }
        }
    }

    func prune(keepingDynamicIDs dynamicIDs: Set<String>) {
        controllers = controllers.filter { key, controller in
            key.interactionIdentityKey == accountContext.interactionIdentityKey
                && (dynamicIDs.contains(key.dynamicID) || controller.isBusy)
        }
    }

    func hardReset(keepingCapacity: Bool = true) {
        controllers.removeAll(keepingCapacity: keepingCapacity)
    }

    private func cacheKey(for dynamicID: String) -> CacheKey {
        CacheKey(
            interactionIdentityKey: accountContext.interactionIdentityKey,
            dynamicID: dynamicID
        )
    }
}

import Foundation
import Testing
@testable import bili

@MainActor
struct DynamicLikeControllerTests {
    @Test
    func `successful mutation keeps the optimistic state`() async {
        var receivedID: String?
        var receivedLikeState: Bool?
        let controller = DynamicLikeController(
            dynamicID: "12345",
            isLiked: false,
            likeCount: 7
        ) { dynamicID, liked in
            receivedID = dynamicID
            receivedLikeState = liked
        }

        let outcome = await controller.toggle()

        #expect(outcome == .updated(isLiked: true))
        #expect(receivedID == "12345")
        #expect(receivedLikeState == true)
        #expect(controller.isLiked)
        #expect(controller.likeCount == 8)
        #expect(!controller.isMutating)
    }

    @Test
    func `failed mutation rolls back the optimistic state`() async {
        let controller = DynamicLikeController(
            dynamicID: "12345",
            isLiked: true,
            likeCount: 1
        ) { _, _ in
            throw URLError(.timedOut)
        }

        let outcome = await controller.toggle()

        if case .failed = outcome {
            // Expected: the card can surface the failure while the state is restored.
        } else {
            Issue.record("A failed mutation should return a failure outcome")
        }
        #expect(controller.isLiked)
        #expect(controller.likeCount == 1)
        #expect(!controller.isMutating)
    }

    @Test
    func `unlike count never becomes negative`() async {
        let controller = DynamicLikeController(
            dynamicID: "12345",
            isLiked: true,
            likeCount: 0
        ) { _, _ in }

        _ = await controller.toggle()

        #expect(!controller.isLiked)
        #expect(controller.likeCount == 0)
    }

    @Test
    func `a second tap is ignored while the request is in flight`() async {
        let controller = DynamicLikeController(
            dynamicID: "12345",
            isLiked: false,
            likeCount: 0
        ) { _, _ in
            try await Task.sleep(for: .milliseconds(80))
        }

        let firstMutation = Task { await controller.toggle() }
        await Task.yield()
        let secondOutcome = await controller.toggle()
        let firstOutcome = await firstMutation.value

        #expect(secondOutcome == .ignored)
        #expect(firstOutcome == .updated(isLiked: true))
        #expect(controller.likeCount == 1)
    }

    @Test
    func `refresh started before a mutation cannot overwrite its result`() async {
        let (mutationGate, mutationContinuation) = AsyncStream<Void>.makeStream()
        let registry = DynamicLikeControllerRegistry(
            accountContext: DynamicLikeAccountContext(
                interactionIdentityKey: "interaction-1",
                adoptsDynamicFeedState: true
            ),
            mutation: { _, _ in
                for await _ in mutationGate { break }
            },
            hydration: { _ in DynamicLikeStateSnapshot(isLiked: false, likeCount: 0) }
        )
        let initial = DynamicLikeFeedSnapshot(dynamicID: "race", isLiked: false, likeCount: 10)
        let controller = registry.controller(for: initial)
        let refreshBaseline = registry.reconciliationBaseline()

        let mutation = Task { await controller.toggle() }
        while !controller.isMutating {
            await Task.yield()
        }
        registry.reconcile(
            snapshots: [initial],
            baseline: refreshBaseline,
            pruningMissingItems: true
        )
        #expect(controller.isLiked)
        #expect(controller.likeCount == 11)

        mutationContinuation.yield()
        mutationContinuation.finish()
        #expect(await mutation.value == .updated(isLiked: true))

        registry.reconcile(
            snapshots: [initial],
            baseline: refreshBaseline,
            pruningMissingItems: true
        )
        #expect(controller.isLiked)
        #expect(controller.likeCount == 11)
    }

    @Test
    func `refresh started during a mutation cannot apply a stale result afterward`() async {
        let (mutationGate, mutationContinuation) = AsyncStream<Void>.makeStream()
        let registry = DynamicLikeControllerRegistry(
            accountContext: DynamicLikeAccountContext(
                interactionIdentityKey: "interaction-1",
                adoptsDynamicFeedState: true
            ),
            mutation: { _, _ in
                for await _ in mutationGate { break }
            },
            hydration: { _ in DynamicLikeStateSnapshot(isLiked: false, likeCount: 0) }
        )
        let staleSnapshot = DynamicLikeFeedSnapshot(
            dynamicID: "mutation-first",
            isLiked: false,
            likeCount: 10
        )
        let controller = registry.controller(for: staleSnapshot)
        let mutation = Task { await controller.toggle() }
        while !controller.isMutating {
            await Task.yield()
        }

        let refreshBaseline = registry.reconciliationBaseline()
        mutationContinuation.yield()
        mutationContinuation.finish()
        #expect(await mutation.value == .updated(isLiked: true))

        registry.reconcile(
            snapshots: [staleSnapshot],
            baseline: refreshBaseline,
            pruningMissingItems: true
        )
        #expect(controller.isLiked)
        #expect(controller.likeCount == 11)
    }

    @Test
    func `registry reuses the controller for the same identity and dynamic ID`() {
        let registry = makeRegistry(adoptsDynamicFeedState: true)
        let first = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "same", isLiked: false, likeCount: 1)
        )
        let second = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "same", isLiked: true, likeCount: 99)
        )

        #expect(first === second)
        #expect(!second.isLiked)
        #expect(second.likeCount == 1)
    }

    @Test
    func `reconcile updates an idle controller without replacing it`() {
        let registry = makeRegistry(adoptsDynamicFeedState: true)
        let controller = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "refresh", isLiked: false, likeCount: 2)
        )
        let baseline = registry.reconciliationBaseline()

        registry.reconcile(
            snapshots: [
                DynamicLikeFeedSnapshot(dynamicID: "refresh", isLiked: true, likeCount: 8)
            ],
            baseline: baseline,
            pruningMissingItems: true
        )

        let reused = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "refresh", isLiked: false, likeCount: 0)
        )
        #expect(reused === controller)
        #expect(reused.isLiked)
        #expect(reused.likeCount == 8)
    }

    @Test
    func `hard reset removes cached controller state`() {
        let registry = makeRegistry(adoptsDynamicFeedState: true)
        let first = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "reset", isLiked: true, likeCount: 3)
        )

        registry.hardReset(keepingCapacity: false)

        let second = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "reset", isLiked: false, likeCount: 1)
        )
        #expect(first !== second)
        #expect(!second.isLiked)
        #expect(second.likeCount == 1)
    }

    @Test
    func `different interaction identity hydrates once and never trusts feed direction`() async {
        var hydrationCount = 0
        let registry = DynamicLikeControllerRegistry(
            accountContext: DynamicLikeAccountContext(
                interactionIdentityKey: "interaction-2",
                adoptsDynamicFeedState: false
            ),
            mutation: { _, _ in },
            hydration: { _ in
                hydrationCount += 1
                try await Task.sleep(for: .milliseconds(30))
                return DynamicLikeStateSnapshot(isLiked: false, likeCount: 4)
            }
        )
        let controller = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "hydrate", isLiked: true, likeCount: 90)
        )
        let sameController = registry.controller(
            for: DynamicLikeFeedSnapshot(dynamicID: "hydrate", isLiked: true, likeCount: 91)
        )

        #expect(controller === sameController)
        #expect(controller.status == .loading)
        let firstHydration = Task { await controller.hydrateIfNeeded() }
        await Task.yield()
        let duplicateHydration = Task { await sameController.hydrateIfNeeded() }
        await firstHydration.value
        await duplicateHydration.value

        #expect(hydrationCount == 1)
        #expect(controller.status == .ready(isLiked: false, likeCount: 4))
    }

    private func makeRegistry(adoptsDynamicFeedState: Bool) -> DynamicLikeControllerRegistry {
        DynamicLikeControllerRegistry(
            accountContext: DynamicLikeAccountContext(
                interactionIdentityKey: "test-interaction",
                adoptsDynamicFeedState: adoptsDynamicFeedState
            ),
            mutation: { _, _ in },
            hydration: { _ in DynamicLikeStateSnapshot(isLiked: false, likeCount: 0) }
        )
    }
}

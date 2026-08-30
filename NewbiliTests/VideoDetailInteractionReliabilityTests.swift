import Foundation
import XCTest
@testable import bili

final class VideoDetailInteractionReliabilityTests: XCTestCase {
    func testManualPageSelectionPreservesExplicitCID() {
        XCTAssertTrue(
            VideoDetailPlaybackHistorySelectionPolicy.preservesManualPage(
                manuallySelectedCID: 202,
                currentCID: 202
            )
        )
        XCTAssertFalse(
            VideoDetailPlaybackHistorySelectionPolicy.preservesManualPage(
                manuallySelectedCID: 101,
                currentCID: 202
            )
        )
    }

    func testLikeConfirmationSurvivesStaleInteractionRefresh() {
        let confirmation = VideoDetailInteractionMutationConfirmation(
            kind: .like,
            state: VideoInteractionState(isLiked: true)
        )
        let staleState = VideoInteractionState(isLiked: false, coinCount: 1, isFavorited: true)

        let reconciled = confirmation.reconciling(staleState)

        XCTAssertTrue(reconciled.isLiked)
        XCTAssertEqual(reconciled.coinCount, 1)
        XCTAssertTrue(reconciled.isFavorited)
    }

    func testCoinConfirmationNeverMovesConfirmedCountBackwards() {
        let confirmation = VideoDetailInteractionMutationConfirmation(
            kind: .coin,
            state: VideoInteractionState(coinCount: 2)
        )

        XCTAssertEqual(
            confirmation.reconciling(VideoInteractionState(coinCount: 1)).coinCount,
            2
        )
        XCTAssertEqual(
            confirmation.reconciling(VideoInteractionState(coinCount: 3)).coinCount,
            3
        )
    }

    func testTripleConfirmationKeepsAllThreeConfirmedStatesAcrossStaleRefresh() {
        let confirmation = VideoDetailInteractionMutationConfirmation(
            kind: .triple,
            state: VideoInteractionState(
                isLiked: true,
                coinCount: 2,
                isFavorited: true
            )
        )

        let reconciled = confirmation.reconciling(
            VideoInteractionState(
                isLiked: false,
                coinCount: 0,
                isFavorited: false,
                isFollowing: true
            )
        )

        XCTAssertTrue(reconciled.isLiked)
        XCTAssertEqual(reconciled.coinCount, 2)
        XCTAssertTrue(reconciled.isFavorited)
        XCTAssertTrue(reconciled.isFollowing)
    }

    func testOnlyAmbiguousMutationFailuresTriggerStateVerification() {
        XCTAssertTrue(
            VideoDetailInteractionReliabilityPolicy.shouldVerifyAmbiguousMutationResult(
                after: URLError(.networkConnectionLost)
            )
        )
        XCTAssertTrue(
            VideoDetailInteractionReliabilityPolicy.shouldVerifyAmbiguousMutationResult(
                after: BiliAPIError.emptyData
            )
        )
        XCTAssertTrue(
            VideoDetailInteractionReliabilityPolicy.shouldVerifyAmbiguousMutationResult(
                after: BiliAPIError.api(code: -500, message: "服务器错误")
            )
        )
        XCTAssertFalse(
            VideoDetailInteractionReliabilityPolicy.shouldVerifyAmbiguousMutationResult(
                after: BiliAPIError.api(code: 34005, message: "硬币不足")
            )
        )
    }

    func testIdempotentMutationRetryPolicyAllowsPostWithoutChangingStandardAPIBehavior() throws {
        let url = try XCTUnwrap(URL(string: "https://api.bilibili.com/x/web-interface/archive/like"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        XCTAssertTrue(BiliNetworkRetryPolicy.idempotentMutation.canRetry(request))
        XCTAssertEqual(BiliNetworkRetryPolicy.idempotentMutation.attempts, 2)
        XCTAssertFalse(BiliNetworkRetryPolicy.api.canRetry(request))
    }

    func testNonIdempotentMutationPolicyNeverReplaysPost() throws {
        let url = try XCTUnwrap(URL(string: "https://api.bilibili.com/x/web-interface/archive/like/triple"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        XCTAssertEqual(BiliNetworkRetryPolicy.nonIdempotentMutation.attempts, 1)
        XCTAssertFalse(BiliNetworkRetryPolicy.nonIdempotentMutation.canRetry(request))
    }

    func testHoldProgressTrackerDeliversMilestonesAndCommitOnlyOnce() {
        var tracker = HoldProgressTracker()

        XCTAssertEqual(tracker.advance(to: 0.34), [.milestone(1)])
        XCTAssertEqual(tracker.advance(to: 0.72), [.milestone(2)])
        XCTAssertEqual(tracker.advance(to: 1), [.committed])
        XCTAssertTrue(tracker.advance(to: 1).isEmpty)
        XCTAssertTrue(tracker.isCommitted)
        XCTAssertTrue(tracker.suppressesTapOnRelease)

        tracker.reset()
        XCTAssertEqual(tracker.progress, 0)
        XCTAssertFalse(tracker.isCommitted)
    }

    func testHoldProgressCancelsBeforeASlowScrollCanCommit() {
        XCTAssertTrue(
            HoldProgressMovementPolicy.shouldCancel(
                translation: CGSize(width: 0, height: 15),
                location: CGPoint(x: 22, y: 37),
                interactiveSize: CGSize(width: 44, height: 44)
            )
        )
        XCTAssertFalse(
            HoldProgressMovementPolicy.shouldCancel(
                translation: CGSize(width: 1.5, height: 2),
                location: CGPoint(x: 22, y: 22),
                interactiveSize: CGSize(width: 44, height: 44)
            )
        )
    }

    func testHoldProgressCancelsWhenTouchLeavesTheInteractiveTarget() {
        XCTAssertTrue(
            HoldProgressMovementPolicy.shouldCancel(
                translation: CGSize(width: 4, height: 0),
                location: CGPoint(x: 45, y: 22),
                interactiveSize: CGSize(width: 44, height: 44)
            )
        )
    }

    func testHoldProgressKeepsACancelledTouchSuppressedUntilRelease() {
        XCTAssertTrue(
            HoldProgressReleasePolicy.shouldSuppressTap(
                didCommit: false,
                hasPendingSuppression: false,
                ignoredCurrentTouch: true
            )
        )
        XCTAssertFalse(
            HoldProgressReleasePolicy.shouldSuppressTap(
                didCommit: false,
                hasPendingSuppression: false,
                ignoredCurrentTouch: false
            )
        )
    }

    func testTripleResultDecodesUGCAndPGCResponseShapes() throws {
        let ugc = try JSONDecoder().decode(
            VideoTripleMutationResult.self,
            from: Data(#"{"like":true,"coin":true,"fav":true,"multiply":2}"#.utf8)
        )
        XCTAssertEqual(ugc.isLiked, true)
        XCTAssertEqual(ugc.isCoined, true)
        XCTAssertEqual(ugc.isFavorited, true)
        XCTAssertEqual(ugc.coinCount, 2)

        let pgc = try JSONDecoder().decode(
            VideoTripleMutationResult.self,
            from: Data(#"{"like":1,"coin":1,"favorite":1,"coin_number":2}"#.utf8)
        )
        XCTAssertEqual(pgc.isLiked, true)
        XCTAssertEqual(pgc.isCoined, true)
        XCTAssertEqual(pgc.isFavorited, true)
        XCTAssertEqual(pgc.coinCount, 2)
    }
}

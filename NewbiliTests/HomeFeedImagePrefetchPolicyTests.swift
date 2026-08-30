import Foundation
import XCTest
@testable import bili

final class HomeFeedImagePrefetchPolicyTests: XCTestCase {
    func testInitialPrefetchAdaptsToLayoutAndEnvironment() {
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.initialPrefetchLimit(
                layout: .singleColumn,
                isConservative: false
            ),
            5
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.initialPrefetchLimit(
                layout: .doubleColumn,
                isConservative: false
            ),
            6
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.initialPrefetchLimit(
                layout: .doubleColumn,
                isConservative: true
            ),
            3
        )
    }

    func testLookaheadStartsBeyondVisibleViewport() {
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadStartIndex(
                visibleIndex: 3,
                layout: .singleColumn
            ),
            6
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadStartIndex(
                visibleIndex: 3,
                layout: .doubleColumn
            ),
            7
        )
    }

    func testLookaheadWindowAvoidsReschedulingForEveryVisibleCard() {
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadWindowStartIndex(
                visibleIndex: 0,
                layout: .singleColumn,
                isConservative: false
            ),
            3
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadWindowStartIndex(
                visibleIndex: 4,
                layout: .singleColumn,
                isConservative: false
            ),
            3
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadWindowStartIndex(
                visibleIndex: 5,
                layout: .singleColumn,
                isConservative: false
            ),
            8
        )
    }

    func testDoubleColumnLookaheadUsesSixCardWindows() {
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadWindowStartIndex(
                visibleIndex: 0,
                layout: .doubleColumn,
                isConservative: false
            ),
            4
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadWindowStartIndex(
                visibleIndex: 5,
                layout: .doubleColumn,
                isConservative: false
            ),
            4
        )
        XCTAssertEqual(
            HomeFeedImagePrefetchPolicy.lookaheadWindowStartIndex(
                visibleIndex: 6,
                layout: .doubleColumn,
                isConservative: false
            ),
            10
        )
    }

    func testEmptyLookaheadPlanClearsItsWindowSoHydratedCoversCanRetry() {
        let profile = HomeFeedCoverPrefetchProfile.fallback(for: .singleColumn)
        let attempted = HomeFeedImageLookaheadRequest(
            feedRootBVID: "BV-root",
            startIndex: 3,
            profile: profile,
            windowContentIdentity: ["BV-a\u{1F}"]
        )

        XCTAssertNil(
            HomeFeedImageLookaheadRequest.clearingAttemptIfCurrent(
                current: attempted,
                attempted: attempted
            )
        )

        let newerRequest = HomeFeedImageLookaheadRequest(
            feedRootBVID: "BV-root",
            startIndex: 8,
            profile: profile,
            windowContentIdentity: ["BV-b\u{1F}https://example.com/b.jpg"]
        )
        XCTAssertEqual(
            HomeFeedImageLookaheadRequest.clearingAttemptIfCurrent(
                current: newerRequest,
                attempted: attempted
            ),
            newerRequest
        )
    }

    func testHydratedCoverChangesLookaheadRequestWithinTheSameWindow() {
        let profile = HomeFeedCoverPrefetchProfile.fallback(for: .singleColumn)
        let pending = HomeFeedImageLookaheadRequest(
            feedRootBVID: "BV-root",
            startIndex: 3,
            profile: profile,
            windowContentIdentity: ["BV-a\u{1F}"]
        )
        let hydrated = HomeFeedImageLookaheadRequest(
            feedRootBVID: "BV-root",
            startIndex: 3,
            profile: profile,
            windowContentIdentity: ["BV-a\u{1F}https://example.com/a.jpg"]
        )

        XCTAssertNotEqual(pending, hydrated)
    }

    func testBorderedSingleColumnProfileMatchesRenderedCoverDimensions() throws {
        let profile = HomeFeedCoverPrefetchProfile.make(
            layout: .borderedSingleColumn,
            metrics: HomeFeedLayoutMetrics(mode: .borderedSingleColumn, containerWidth: 390),
            displayScale: 3
        )
        let source = try XCTUnwrap(profile.source(for: "https://i0.hdslb.com/bfs/archive/example.jpg"))

        XCTAssertEqual(profile.targetPixelSize, 432)
        XCTAssertTrue(source.url.absoluteString.contains("/w/432/h/272/"))
    }

    func testEditorialProfileUsesOneSharedAssetSizeForCardsAndPrefetch() throws {
        let phoneProfile = HomeFeedCoverPrefetchProfile.editorial(
            containerWidth: 402,
            displayScale: 3
        )
        let padProfile = HomeFeedCoverPrefetchProfile.editorial(
            containerWidth: 1_024,
            displayScale: 2
        )
        let phoneSource = try XCTUnwrap(
            phoneProfile.source(for: "https://i0.hdslb.com/bfs/archive/example.jpg")
        )
        let padSource = try XCTUnwrap(
            padProfile.source(for: "https://i0.hdslb.com/bfs/archive/example.jpg")
        )

        XCTAssertEqual(HomeEditorialImagePolicy.maximumPixelLength(containerWidth: 402), 960)
        XCTAssertEqual(HomeEditorialImagePolicy.maximumPixelLength(containerWidth: 1_024), 1_280)
        XCTAssertEqual(phoneProfile.targetPixelSize, 960)
        XCTAssertEqual(padProfile.targetPixelSize, 1_280)
        XCTAssertTrue(phoneSource.url.absoluteString.contains("/w/960/"))
        XCTAssertTrue(padSource.url.absoluteString.contains("/w/1280/"))
    }

    func testEditorialHeroStaysCompactOnPhoneAndBoundedOnIPad() {
        XCTAssertEqual(
            HomeEditorialLayoutPolicy.heroHeight(containerWidth: 390, viewportHeight: 844),
            238,
            accuracy: 0.01
        )
        XCTAssertEqual(
            HomeEditorialLayoutPolicy.heroHeight(containerWidth: 1_024, viewportHeight: 1_366),
            406.56,
            accuracy: 0.01
        )
        XCTAssertEqual(HomeEditorialLayoutPolicy.horizontalInset(containerWidth: 390), 16)
        XCTAssertEqual(HomeEditorialLayoutPolicy.horizontalInset(containerWidth: 1_024), 28)
    }

    func testImmersiveLayoutAdaptsWideIPadAndKeepsNarrowSplitPhoneLike() {
        XCTAssertEqual(
            HomeImmersiveAdaptiveLayoutPolicy.resolve(
                preferredLayout: .singleColumn,
                containerWidth: 1_024,
                usesAccessibilitySize: false
            ),
            .doubleColumn
        )
        XCTAssertEqual(
            HomeImmersiveAdaptiveLayoutPolicy.resolve(
                preferredLayout: .borderedSingleColumn,
                containerWidth: 680,
                usesAccessibilitySize: false
            ),
            .borderedSingleColumn
        )
    }

    func testImmersiveLayoutKeepsAccessibilityContentSingleColumn() {
        XCTAssertEqual(
            HomeImmersiveAdaptiveLayoutPolicy.resolve(
                preferredLayout: .borderedDoubleColumn,
                containerWidth: 1_366,
                usesAccessibilitySize: true
            ),
            .singleColumn
        )
    }

    func testEditorialLayoutKeepsUserDensityChoiceAndStacksAccessibilityContent() {
        XCTAssertEqual(
            HomeEditorialAdaptiveLayoutPolicy.resolve(
                preferredLayout: .singleColumn,
                usesAccessibilitySize: false
            ),
            .singleColumn
        )
        XCTAssertEqual(
            HomeEditorialAdaptiveLayoutPolicy.resolve(
                preferredLayout: .borderedDoubleColumn,
                usesAccessibilitySize: true
            ),
            .borderedSingleColumn
        )
    }

    func testWideFeedMetricsGrowFromTwoToFourColumns() {
        XCTAssertEqual(
            HomeFeedLayoutMetrics(mode: .doubleColumn, containerWidth: 700).feedColumns.count,
            2
        )
        XCTAssertEqual(
            HomeFeedLayoutMetrics(mode: .doubleColumn, containerWidth: 900).feedColumns.count,
            3
        )
        XCTAssertEqual(
            HomeFeedLayoutMetrics(mode: .doubleColumn, containerWidth: 1_300).feedColumns.count,
            4
        )
    }

    func testCinematicShelvesUseActualAvailableWidthForIPadAndFoldables() {
        XCTAssertFalse(
            HomeCinematicWideLayoutPolicy.usesCinematicShelves(
                containerWidth: 759,
                viewportHeight: 1_024
            )
        )
        XCTAssertTrue(
            HomeCinematicWideLayoutPolicy.usesCinematicShelves(
                containerWidth: 760,
                viewportHeight: 1_024
            )
        )
        XCTAssertTrue(
            HomeCinematicWideLayoutPolicy.usesCinematicShelves(
                containerWidth: 1_366,
                viewportHeight: 1_024
            )
        )
        XCTAssertTrue(
            HomeCinematicWideLayoutPolicy.usesCinematicShelves(
                containerWidth: 844,
                viewportHeight: 390
            )
        )
        XCTAssertTrue(
            HomeCinematicWideLayoutPolicy.usesCinematicShelves(
                containerWidth: 700,
                viewportHeight: 390
            )
        )
        XCTAssertFalse(
            HomeCinematicWideLayoutPolicy.usesCinematicShelves(
                containerWidth: 700,
                viewportHeight: 960
            )
        )
    }

    func testCinematicHeroCompressesForIPhoneLandscapeHeight() {
        XCTAssertEqual(
            HomeCinematicWideLayoutPolicy.heroHeight(
                containerWidth: 844,
                viewportHeight: 390
            ),
            358.8,
            accuracy: 0.01
        )
        XCTAssertEqual(
            HomeCinematicWideLayoutPolicy.heroHeight(
                containerWidth: 1_024,
                viewportHeight: 1_366
            ),
            720,
            accuracy: 0.01
        )
    }

    func testCinematicShelfPlanKeepsStableGroupsAndFinalRemainder() {
        XCTAssertEqual(
            HomeCinematicShelfPlan.itemRanges(totalItemCount: 18, itemsPerShelf: 8),
            [0..<8, 8..<16, 16..<18]
        )
        XCTAssertEqual(
            HomeCinematicShelfPlan.itemRanges(totalItemCount: 0, itemsPerShelf: 8),
            []
        )
    }

    func testFeaturedMixKeepsStableOrderDeduplicatesAndAddsOnePopularItem() {
        let selections = HomeFeaturedMixPolicy.selections(
            currentFeedIDs: ["r1", "r2", "r2", "r3", "r4", "r5"],
            popularIDs: ["r1", "p1", "p2"],
            includesPopular: true
        )

        XCTAssertEqual(selections.map(\.id), ["r1", "r2", "p1", "r3", "r4"])
        XCTAssertEqual(
            selections.map(\.source),
            [.currentFeed, .currentFeed, .popular, .currentFeed, .currentFeed]
        )
    }

    func testFeaturedMixFallsBackToFiveCurrentItemsWhenPopularIsUnavailable() {
        let selections = HomeFeaturedMixPolicy.selections(
            currentFeedIDs: ["r1", "r2", "r3", "r4", "r5", "r6"],
            popularIDs: [],
            includesPopular: true
        )

        XCTAssertEqual(selections.map(\.id), ["r1", "r2", "r3", "r4", "r5"])
        XCTAssertTrue(selections.allSatisfy { $0.source == .currentFeed })
    }

    func testFeaturedMixAddsOnePopularAndOneOfficialActivityWithoutDuplicatingFeed() {
        let selections = HomeFeaturedMixPolicy.selections(
            currentFeedIDs: ["r1", "r2", "r3", "r4"],
            popularIDs: ["r1", "p1"],
            activityIDs: ["activity-11", "activity-12"],
            includesPopular: true,
            includesActivity: true
        )

        XCTAssertEqual(
            selections,
            [
                HomeFeaturedSelection(id: "r1", source: .currentFeed),
                HomeFeaturedSelection(id: "r2", source: .currentFeed),
                HomeFeaturedSelection(id: "p1", source: .popular),
                HomeFeaturedSelection(id: "activity-11", source: .activity),
                HomeFeaturedSelection(id: "r3", source: .currentFeed)
            ]
        )
    }

    func testHomeActivityBannerOnlyAcceptsNonAdvertisingOfficialBilibiliActivities() throws {
        let response = try JSONDecoder().decode(
            BiliResponse<[String: [HomeActivityBanner]]>.self,
            from: Data(
                """
                {
                  "code": 0,
                  "data": {
                    "4694": [
                      {
                        "id": 11,
                        "pos_num": 2,
                        "name": "官方创作活动",
                        "pic": "http://i0.hdslb.com/bfs/banner/activity.jpg",
                        "url": "https://www.bilibili.com/blackboard/era/activity.html",
                        "label": "征稿",
                        "is_ad_loc": false
                      },
                      {
                        "id": 12,
                        "pos_num": 1,
                        "name": "广告活动",
                        "pic": "http://i0.hdslb.com/bfs/banner/ad.jpg",
                        "url": "https://www.bilibili.com/blackboard/era/ad.html",
                        "is_ad_loc": true
                      },
                      {
                        "id": 13,
                        "pos_num": 3,
                        "name": "站外活动",
                        "pic": "https://example.com/banner.jpg",
                        "url": "https://example.com/activity",
                        "is_ad_loc": false
                      }
                    ]
                  }
                }
                """.utf8
            )
        )

        let banners = try XCTUnwrap(response.payload?["4694"])
        XCTAssertTrue(banners[0].isEligibleEditorialActivity)
        XCTAssertFalse(banners[1].isEligibleEditorialActivity)
        XCTAssertFalse(banners[2].isEligibleEditorialActivity)
        XCTAssertEqual(banners[0].destinationURL?.host, "www.bilibili.com")
    }

    func testFeaturedCarouselNavigationWrapsInBothDirections() {
        let ids = ["one", "two", "three"]

        XCTAssertEqual(HomeFeaturedMixPolicy.nextID(in: ids, after: "three"), "one")
        XCTAssertEqual(HomeFeaturedMixPolicy.previousID(in: ids, before: "one"), "three")
        XCTAssertEqual(HomeFeaturedMixPolicy.nextID(in: ids, after: "missing"), "one")
    }

    func testFeaturedAutoplayPausesForAccessibilityBackgroundAndInteraction() {
        XCTAssertTrue(
            HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: 5,
                isSceneActive: true,
                isUserInteracting: false,
                reduceMotion: false,
                voiceOverEnabled: false
            )
        )
        XCTAssertFalse(
            HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: 5,
                isSceneActive: true,
                isUserInteracting: false,
                isPausedByUser: true,
                reduceMotion: false,
                voiceOverEnabled: false
            )
        )
        XCTAssertFalse(
            HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: 5,
                isSceneActive: true,
                isUserInteracting: false,
                reduceMotion: true,
                voiceOverEnabled: false
            )
        )
        XCTAssertFalse(
            HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: 5,
                isSceneActive: true,
                isUserInteracting: false,
                reduceMotion: false,
                voiceOverEnabled: true
            )
        )
        XCTAssertFalse(
            HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: 5,
                isSceneActive: false,
                isUserInteracting: false,
                reduceMotion: false,
                voiceOverEnabled: false
            )
        )
        XCTAssertFalse(
            HomeFeaturedMixPolicy.shouldAutoAdvance(
                itemCount: 5,
                isSceneActive: true,
                isUserInteracting: true,
                reduceMotion: false,
                voiceOverEnabled: false
            )
        )
    }

    func testFeaturedPopularCacheRefreshPolicyUsesFifteenMinuteLifetime() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertTrue(
            HomeFeaturedMixPolicy.shouldRefreshSupplement(
                hasCachedItems: false,
                lastRefreshDate: now,
                now: now
            )
        )
        XCTAssertFalse(
            HomeFeaturedMixPolicy.shouldRefreshSupplement(
                hasCachedItems: true,
                lastRefreshDate: now.addingTimeInterval(-899),
                now: now
            )
        )
        XCTAssertTrue(
            HomeFeaturedMixPolicy.shouldRefreshSupplement(
                hasCachedItems: true,
                lastRefreshDate: now.addingTimeInterval(-900),
                now: now
            )
        )
    }
}

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

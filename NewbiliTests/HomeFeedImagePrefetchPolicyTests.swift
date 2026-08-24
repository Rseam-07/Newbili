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
}

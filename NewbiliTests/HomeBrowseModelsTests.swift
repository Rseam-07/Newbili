import Foundation
import XCTest
@testable import bili

final class HomeBrowseModelsTests: XCTestCase {
    func testPgcBrowsePageDecodesMixedScalarRepresentations() throws {
        let page = try decode(
            PgcBrowsePage.self,
            from: """
            {
              "has_next": 1,
              "total": "42",
              "list": [
                {
                  "season_id": "12345",
                  "media_id": 67890,
                  "title": "<em>Newbili</em> 番剧",
                  "subTitle": "全 12 话",
                  "cover": "//i0.hdslb.com/bfs/bangumi/demo.jpg",
                  "badge": "独家",
                  "index_show": "更新至第 8 话",
                  "score": 9.6,
                  "first_ep": {"ep_id": 24680, "cover": "episode.jpg"}
                }
              ]
            }
            """
        )

        XCTAssertTrue(page.hasNext)
        XCTAssertEqual(page.total, 42)
        XCTAssertEqual(page.list.count, 1)
        XCTAssertEqual(page.list[0].seasonID, 12_345)
        XCTAssertEqual(page.list[0].title, "Newbili 番剧")
        XCTAssertEqual(page.list[0].score, "9.6")
        XCTAssertEqual(page.list[0].firstEpisode?.episodeID, 24_680)
        XCTAssertEqual(page.list[0].route?.seasonID, 12_345)
    }

    func testTimelineDecodesNumericFlagsAndBuildsSeasonRoute() throws {
        let day = try decode(
            PgcTimelineDay.self,
            from: """
            {
              "date": "8-23",
              "date_ts": 1787414400,
              "day_of_week": 7,
              "is_today": 1,
              "episodes": [
                {
                  "episode_id": 111,
                  "season_id": 222,
                  "title": "测试动画",
                  "cover": "season.jpg",
                  "ep_cover": "episode.jpg",
                  "pub_index": "第 4 话",
                  "pub_time": "20:00",
                  "published": 0
                }
              ]
            }
            """
        )

        XCTAssertTrue(day.isToday)
        XCTAssertEqual(day.displayDate, "今天")
        XCTAssertEqual(day.episodes.first?.episodeID, 111)
        XCTAssertFalse(try XCTUnwrap(day.episodes.first).published)
        XCTAssertEqual(day.episodes.first?.route?.seasonID, 222)
    }

    func testPgcRankRouteExtractsSeasonIDFromAbsoluteURL() throws {
        let item = try decode(
            PgcRankItem.self,
            from: """
            {
              "cover": "cover.jpg",
              "title": "排行榜番剧",
              "url": "https://www.bilibili.com/bangumi/play/ss98765",
              "new_ep": {"index_show": "更新至 10 话"},
              "stat": {"follow": 123456, "view": 987654}
            }
            """
        )

        XCTAssertEqual(item.route?.seasonID, 98_765)
        XCTAssertEqual(item.newEpisode?.indexShow, "更新至 10 话")
        XCTAssertEqual(item.stat?.follow, 123_456)
    }

    func testHomePrimarySectionsExposeDirectTopLevelDestinations() {
        XCTAssertEqual(
            HomePrimarySection.allCases.map(\.title),
            ["推荐", "热门", "分区", "番剧", "影视"]
        )
        XCTAssertEqual(HomePrimarySection.recommend.feedMode, .recommend)
        XCTAssertEqual(HomePrimarySection.popular.feedMode, .popular)
        XCTAssertNil(HomePrimarySection.regions.feedMode)
        XCTAssertNil(HomePrimarySection.bangumi.feedMode)
        XCTAssertNil(HomePrimarySection.cinema.feedMode)
    }

    func testHomeGreetingAdaptsToTimeWithoutInventingAGuestName() {
        XCTAssertEqual(
            HomeGreetingContent.make(hour: 7, displayName: nil),
            HomeGreetingContent(
                title: "早上好",
                subtitle: "新一天，从喜欢的内容开始"
            )
        )
        XCTAssertEqual(
            HomeGreetingContent.make(hour: 20, displayName: "  Conrad  "),
            HomeGreetingContent(
                title: "晚上好，Conrad",
                subtitle: "今晚想看点什么？"
            )
        )
    }

    func testHomeGreetingCoversNoonAfternoonAndLateNightBoundaries() {
        XCTAssertEqual(HomeGreetingContent.make(hour: 10, displayName: nil).title, "中午好")
        XCTAssertEqual(HomeGreetingContent.make(hour: 13, displayName: nil).title, "下午好")
        XCTAssertEqual(HomeGreetingContent.make(hour: 23, displayName: nil).title, "夜深了")
        XCTAssertEqual(HomeGreetingContent.make(hour: -3, displayName: "  ").title, "夜深了")
    }

    func testHomeNavigationHeaderUsesAStableGeometricCenter() {
        XCTAssertTrue(
            HomeNavigationHeaderLayoutPolicy.usesStackedLayout(
                containerWidth: 819,
                usesAccessibilitySize: false
            )
        )
        XCTAssertFalse(
            HomeNavigationHeaderLayoutPolicy.usesStackedLayout(
                containerWidth: 820,
                usesAccessibilitySize: false
            )
        )
        XCTAssertTrue(
            HomeNavigationHeaderLayoutPolicy.usesStackedLayout(
                containerWidth: 1_366,
                usesAccessibilitySize: true
            )
        )
        XCTAssertEqual(
            HomeNavigationHeaderLayoutPolicy.sideSlotWidth(containerWidth: 820),
            211,
            accuracy: 0.01
        )
    }

    func testTopNavigationCollapsesOnlyAfterScrollThreshold() {
        XCTAssertFalse(
            TopNavigationCollapsePolicy.isCollapsed(
                contentOffsetY: 23.9,
                contentInsetTop: 0
            )
        )
        XCTAssertFalse(
            TopNavigationCollapsePolicy.isCollapsed(
                contentOffsetY: -42,
                contentInsetTop: 66
            )
        )
        XCTAssertTrue(
            TopNavigationCollapsePolicy.isCollapsed(
                contentOffsetY: -41.9,
                contentInsetTop: 66
            )
        )
    }

    func testTopNavigationCollapsePolicyUsesHysteresis() {
        XCTAssertTrue(
            TopNavigationCollapsePolicy.resolvedState(
                currentlyCollapsed: false,
                contentOffsetY: 25,
                contentInsetTop: 0
            )
        )
        XCTAssertTrue(
            TopNavigationCollapsePolicy.resolvedState(
                currentlyCollapsed: true,
                contentOffsetY: 12,
                contentInsetTop: 0
            )
        )
        XCTAssertFalse(
            TopNavigationCollapsePolicy.resolvedState(
                currentlyCollapsed: true,
                contentOffsetY: 7.9,
                contentInsetTop: 0
            )
        )
    }

    @MainActor
    func testHomePresentationStyleDefaultsToImmersiveAndPersistsSimpleMode() {
        let suiteName = "HomeBrowseModelsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        XCTAssertEqual(HomePresentationStyle.allCases, [.immersive, .simple])
        XCTAssertEqual(store.homePresentationStyle, .immersive)

        store.setHomePresentationStyle(.simple)
        XCTAssertEqual(LibraryStore(userDefaults: defaults).homePresentationStyle, .simple)
    }

    @MainActor
    func testRetiredEditorialHomeStyleMigratesBackToImmersive() {
        let suiteName = "HomeBrowseModelsTests.RetiredEditorial.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("editorial", forKey: "cc.bili.home.presentationStyle.v1")

        let store = LibraryStore(userDefaults: defaults)

        XCTAssertEqual(store.homePresentationStyle, .immersive)
        XCTAssertEqual(
            defaults.string(forKey: "cc.bili.home.presentationStyle.v1"),
            HomePresentationStyle.immersive.rawValue
        )
    }

    @MainActor
    func testBackgroundPlaybackDefaultsToListenOnlyAndPersistsAlways() {
        let suiteName = "HomeBrowseModelsTests.BackgroundPlayback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        XCTAssertEqual(store.backgroundPlaybackMode, .listenOnly)

        store.setBackgroundPlaybackMode(.always)
        XCTAssertEqual(LibraryStore(userDefaults: defaults).backgroundPlaybackMode, .always)
    }

    @MainActor
    func testDynamicFeedLayoutDefaultsToAutomaticAndPersistsTwoColumns() {
        let suiteName = "HomeBrowseModelsTests.DynamicLayout.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        XCTAssertEqual(store.dynamicFeedLayoutPreference, .automatic)

        store.setDynamicFeedLayoutPreference(.doubleColumn)
        XCTAssertEqual(
            LibraryStore(userDefaults: defaults).dynamicFeedLayoutPreference,
            .doubleColumn
        )
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from json: String
    ) throws -> Value {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(type, from: data)
    }
}

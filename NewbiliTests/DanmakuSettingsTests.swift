import XCTest
@testable import bili

final class DanmakuSettingsTests: XCTestCase {
    func testLegacySettingsDefaultToHidingDanmakuInPortrait() throws {
        let data = Data(
            """
            {
              "fontScale": 1,
              "opacity": 0.92,
              "displayArea": "topHalf",
              "fontWeight": "semibold",
              "loadFactor": 1
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(DanmakuSettings.self, from: data)

        XCTAssertFalse(settings.hidesInPortrait)
        XCTAssertEqual(settings.scrollingDuration, 7.0, accuracy: 0.001)
        XCTAssertEqual(settings.staticDuration, 4.0, accuracy: 0.001)
        XCTAssertEqual(settings.lineHeight, 1.6, accuracy: 0.001)
        XCTAssertEqual(settings.strokeWidth, 1.5, accuracy: 0.001)
        XCTAssertTrue(settings.showsScrollingDanmaku)
        XCTAssertTrue(settings.showsTopDanmaku)
        XCTAssertTrue(settings.showsBottomDanmaku)
        XCTAssertTrue(settings.blockedKeywords.isEmpty)
        XCTAssertTrue(settings.blockedRegularExpressions.isEmpty)
        XCTAssertTrue(settings.blockedUserIDs.isEmpty)
    }

    func testPiliPlusStyleRenderingValuesAreNormalizedForSafePlayback() {
        var settings = DanmakuSettings.default
        settings.scrollingDuration = 80
        settings.staticDuration = 0
        settings.lineHeight = 5
        settings.strokeWidth = -2
        settings.loadFactor = 0.1

        let normalized = settings.normalized

        XCTAssertEqual(normalized.scrollingDuration, 50, accuracy: 0.001)
        XCTAssertEqual(normalized.staticDuration, 1, accuracy: 0.001)
        XCTAssertEqual(normalized.lineHeight, 3, accuracy: 0.001)
        XCTAssertEqual(normalized.strokeWidth, 0, accuracy: 0.001)
        XCTAssertEqual(normalized.loadFactor, 0.35, accuracy: 0.001)
    }

    func testScrollingDurationIsIndependentOfTextWidth() {
        let duration = 7.0
        let shortDelay = DanmakuMotionTiming.laneEntranceDelay(
            surfaceWidth: 390,
            labelWidth: 80,
            duration: duration,
            gap: 30
        )
        let longDelay = DanmakuMotionTiming.laneEntranceDelay(
            surfaceWidth: 390,
            labelWidth: 300,
            duration: duration,
            gap: 30
        )

        XCTAssertEqual(
            DanmakuMotionTiming.remainingDuration(totalDuration: duration, elapsed: 0),
            duration,
            accuracy: 0.001
        )
        XCTAssertEqual(
            DanmakuMotionTiming.remainingDuration(totalDuration: duration, elapsed: 3),
            4,
            accuracy: 0.001
        )
        XCTAssertLessThan(shortDelay, longDelay)
        XCTAssertLessThan(longDelay, duration)
    }

    func testFilterRulesNormalizeDuplicatesAndInvalidUIDCharacters() {
        var settings = DanmakuSettings.default
        settings.blockedKeywords = ["  广告  ", "广告", ""]
        settings.blockedRegularExpressions = ["  a.+b  ", "a.+b"]
        settings.blockedUserIDs = [" UID 123 ", "123", "no-user"]

        let normalized = settings.normalized

        XCTAssertEqual(normalized.blockedKeywords, ["广告"])
        XCTAssertEqual(normalized.blockedRegularExpressions, ["a.+b"])
        XCTAssertEqual(normalized.blockedUserIDs, ["123"])
    }

    func testSharedFilterHandlesTypesKeywordsRegexAndVideoOrLiveUserIdentifiers() {
        var settings = DanmakuSettings.default
        settings.showsScrollingDanmaku = false
        settings.blockedKeywords = ["剧透"]
        settings.blockedRegularExpressions = [#"领.{0,3}红包"#]
        settings.blockedUserIDs = ["123"]
        let filter = DanmakuItemFilter(rules: settings.normalized.filterRules)

        let items = [
            makeItem(id: "scroll", mode: 1, text: "普通滚动"),
            makeItem(id: "top", mode: 5, text: "普通顶部"),
            makeItem(id: "keyword", mode: 4, text: "这里有剧透"),
            makeItem(id: "regex", mode: 4, text: "点击领取红包"),
            makeItem(id: "video-user", mode: 4, text: "视频用户", senderIdentifier: "884863d2"),
            makeItem(id: "live-user", mode: 4, text: "直播用户", senderIdentifier: "123")
        ]

        XCTAssertEqual(filter.filtered(items).map(\.id), ["top"])
        XCTAssertEqual(DanmakuItemFilter.crc32MIDHash(for: "123"), "884863d2")
    }

    @MainActor
    func testBlockingTappedVideoSenderReusesPersistentFilterRules() throws {
        let selectedItem = makeItem(
            id: "selected",
            mode: 1,
            text: "点到的弹幕",
            senderIdentifier: "ABCDEF12"
        )

        let updated = try DanmakuInteractionActions.settingsByBlockingSender(
            of: selectedItem,
            in: .default
        )
        let duplicateUpdate = try DanmakuInteractionActions.settingsByBlockingSender(
            of: selectedItem,
            in: updated
        )
        let filter = DanmakuItemFilter(rules: duplicateUpdate.filterRules)

        XCTAssertEqual(duplicateUpdate.blockedUserIDs, ["abcdef12"])
        XCTAssertFalse(
            filter.allows(
                makeItem(
                    id: "same-sender",
                    mode: 5,
                    text: "同一用户的另一条弹幕",
                    senderIdentifier: "abcdef12"
                )
            )
        )
        XCTAssertTrue(
            filter.allows(
                makeItem(
                    id: "other-sender",
                    mode: 5,
                    text: "其他用户弹幕",
                    senderIdentifier: "1234abcd"
                )
            )
        )
    }

    func testInvalidRegularExpressionIsIgnoredWithoutBreakingValidRules() {
        var settings = DanmakuSettings.default
        settings.blockedRegularExpressions = ["(", "valid"]
        let filter = DanmakuItemFilter(rules: settings.filterRules)

        XCTAssertTrue(filter.allows(makeItem(id: "safe", mode: 1, text: "hello")))
        XCTAssertFalse(filter.allows(makeItem(id: "match", mode: 1, text: "VALID")))
        XCTAssertFalse(DanmakuItemFilter.isValidRegularExpression("("))
    }

    @MainActor
    func testOverlayWindowRetainsLongDurationDanmakuForRebuild() {
        let state = VideoDetailDanmakuOverlayState()
        var settings = DanmakuSettings.default
        settings.scrollingDuration = 50
        state.updateSnapshot { $0.settings = settings }

        XCTAssertGreaterThanOrEqual(state.effectiveWindowLookBehind, 51)
    }

    @MainActor
    func testExplicitFlushPersistsLatestDebouncedDanmakuSettings() throws {
        let suiteName = "DanmakuSettingsTests.Flush.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        var supersededSettings = DanmakuSettings.default
        supersededSettings.opacity = 0.4
        store.setDanmakuSettings(supersededSettings)

        var latestSettings = DanmakuSettings.default
        latestSettings.fontScale = 1.75
        latestSettings.opacity = 0.7
        latestSettings.scrollingDuration = 12
        latestSettings.showsBottomDanmaku = false
        latestSettings.blockedKeywords = ["广告"]
        latestSettings.blockedRegularExpressions = ["抽.{0,2}奖"]
        latestSettings.blockedUserIDs = ["123"]
        store.setDanmakuSettings(latestSettings)

        XCTAssertEqual(store.danmakuSettings, latestSettings.normalized)
        XCTAssertEqual(LibraryStore(userDefaults: defaults).danmakuSettings, .default)

        store.flushDanmakuSettingsPersistence()

        XCTAssertEqual(
            LibraryStore(userDefaults: defaults).danmakuSettings,
            latestSettings.normalized
        )
    }

    @MainActor
    func testDebouncedDanmakuSettingsPersistAfterDelay() async throws {
        let suiteName = "DanmakuSettingsTests.Debounce.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        var settings = DanmakuSettings.default
        settings.displayArea = .full
        settings.staticDuration = 9
        store.setDanmakuSettings(settings)

        try await Task.sleep(for: .milliseconds(350))

        XCTAssertEqual(
            LibraryStore(userDefaults: defaults).danmakuSettings,
            settings.normalized
        )
    }

    @MainActor
    func testTapInteractionDefaultsOnAndPersistsImmediately() throws {
        let suiteName = "DanmakuSettingsTests.TapInteraction.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        XCTAssertTrue(store.danmakuTapInteractionEnabled)

        store.setDanmakuTapInteractionEnabled(false)

        XCTAssertFalse(store.danmakuTapInteractionEnabled)
        XCTAssertFalse(LibraryStore(userDefaults: defaults).danmakuTapInteractionEnabled)
    }

    @MainActor
    func testSettingsSearchFindsTapInteractionInPlaybackAndDanmakuRoutes() {
        let matchedRoutes = MineSettingsSearchView.searchableItems
            .filter { $0.matches("启用点击弹幕") }
            .map(\.route)

        XCTAssertTrue(matchedRoutes.contains(.playbackSettings))
        XCTAssertTrue(matchedRoutes.contains(.danmakuSettings))
    }

    @MainActor
    func testSettingsSearchDoesNotAdvertiseUnavailableControls() {
        let unavailableQueries = ["搜索建议", "搜索发现", "缓冲", "黑名单", "已关注UP"]

        for query in unavailableQueries {
            XCTAssertFalse(
                MineSettingsSearchView.searchableItems.contains { $0.matches(query) },
                "不应把尚未提供的“\(query)”导向只有分类入口的设置页"
            )
        }
    }

    private func makeItem(
        id: String,
        mode: Int,
        text: String,
        senderIdentifier: String? = nil
    ) -> DanmakuItem {
        DanmakuItem(
            id: id,
            time: 0,
            mode: mode,
            fontSize: 25,
            color: 0xFFFFFF,
            text: text,
            senderIdentifier: senderIdentifier
        )
    }
}

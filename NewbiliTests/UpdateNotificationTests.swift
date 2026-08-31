import XCTest
@testable import bili

final class UpdateNotificationTests: XCTestCase {
    @MainActor
    func testNotificationPreferenceAndFullMarkedSnapshotPersist() throws {
        let suiteName = "UpdateNotificationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        XCTAssertEqual(store.followedUploaderNotificationLevel, .off)
        store.setFollowedUploaderNotificationLevel(.specialOnly)
        store.setVideoMarkedAsAnime(Self.video(pages: [Self.page(cid: 10, page: 1, title: "开篇")]), isMarked: true)

        let restored = LibraryStore(userDefaults: defaults)
        XCTAssertEqual(restored.followedUploaderNotificationLevel, .specialOnly)
        let snapshot = try XCTUnwrap(restored.markedAnimeSnapshots.first)
        XCTAssertEqual(snapshot.bvid, "BV1TESTUPDATE")
        XCTAssertEqual(snapshot.title, "测试番剧")
        XCTAssertEqual(snapshot.coverURL, "https://i0.hdslb.com/test.jpg")
        XCTAssertEqual(snapshot.ownerMID, 42)
        XCTAssertEqual(snapshot.pages.map(\.cid), [10])
        XCTAssertEqual(snapshot.pages.first?.title, "开篇")
        XCTAssertEqual(snapshot.videoItem.bvid, "BV1TESTUPDATE")
    }

    @MainActor
    func testLegacyBVIDSetMigratesWithoutLosingMark() throws {
        let suiteName = "UpdateNotificationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["bv1legacyitem"], forKey: "cc.bili.videoDetail.markedAnimeBVIDs.v1")

        let store = LibraryStore(userDefaults: defaults)

        XCTAssertTrue(store.isVideoMarkedAsAnime("BV1LEGACYITEM"))
        XCTAssertEqual(store.markedAnimeSnapshots.first?.bvid, "BV1LEGACYITEM")
        XCTAssertTrue(store.markedAnimeSnapshots.first?.pages.isEmpty == true)
    }

    func testPageDiffTreatsEmptyLegacySnapshotAsBaseline() {
        let pageOne = MarkedAnimePageSnapshot(page: Self.page(cid: 10, page: 1, title: "第一话"))
        let pageTwo = MarkedAnimePageSnapshot(page: Self.page(cid: 20, page: 2, title: "第二话"))

        XCTAssertTrue(UpdateNotificationDiff.addedPages(previous: [], current: [pageOne]).isEmpty)
        XCTAssertEqual(
            UpdateNotificationDiff.addedPages(previous: [pageOne], current: [pageOne, pageTwo]),
            [pageTwo]
        )
        XCTAssertTrue(
            UpdateNotificationDiff.addedPages(previous: [pageOne, pageTwo], current: [pageTwo, pageOne]).isEmpty
        )
    }

    func testFollowedUploaderDiffUsesBaselineSeenIDsAndSpecialFilter() {
        let records = [
            FollowedUploaderUpdateRecord(
                dynamicID: "new-special",
                uploaderMID: 1,
                uploaderName: "特别关注",
                bvid: "BV1SPECIAL",
                videoTitle: "新投稿"
            ),
            FollowedUploaderUpdateRecord(
                dynamicID: "new-normal",
                uploaderMID: 2,
                uploaderName: "普通关注",
                bvid: "BV1NORMAL",
                videoTitle: "普通投稿"
            ),
            FollowedUploaderUpdateRecord(
                dynamicID: "seen",
                uploaderMID: 1,
                uploaderName: "特别关注",
                bvid: "BV1SEEN",
                videoTitle: "看过了"
            )
        ]

        XCTAssertTrue(UpdateNotificationDiff.newFollowedUploaderVideos(
            current: records,
            previouslySeenDynamicIDs: [],
            hasEstablishedBaseline: false
        ).isEmpty)
        XCTAssertEqual(UpdateNotificationDiff.newFollowedUploaderVideos(
            current: records,
            previouslySeenDynamicIDs: ["seen"],
            hasEstablishedBaseline: true,
            allowedUploaderMIDs: [1]
        ).map(\.dynamicID), ["new-special"])
        XCTAssertTrue(UpdateNotificationDiff.newFollowedUploaderVideos(
            current: records,
            previouslySeenDynamicIDs: ["seen"],
            hasEstablishedBaseline: true,
            requiresRebaseline: true
        ).isEmpty)
    }

    @MainActor
    func testMarkedAnimeRemovalCanRestoreOriginalSnapshot() throws {
        let suiteName = "UpdateNotificationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LibraryStore(userDefaults: defaults)
        store.setVideoMarkedAsAnime(Self.video(pages: [Self.page(cid: 10, page: 1, title: "开篇")]), isMarked: true)
        let original = try XCTUnwrap(store.markedAnimeSnapshots.first)

        store.setVideoMarkedAsAnime(original.bvid, isMarked: false)
        XCTAssertTrue(store.markedAnimeSnapshots.isEmpty)
        store.restoreMarkedAnimeSnapshot(original)

        XCTAssertEqual(store.markedAnimeSnapshots, [original])
        XCTAssertTrue(store.isVideoMarkedAsAnime(original.bvid))
    }

    func testLoggedOutStatusDoesNotClaimUploaderCheckCompleted() {
        let status = UpdateNotificationStatusText.refreshResult(
            notificationCount: 0,
            completedChecks: 0,
            failures: 0,
            skippedFollowedUploadersBecauseLoggedOut: true
        )

        XCTAssertTrue(status.contains("未登录"))
        XCTAssertTrue(status.contains("未检查"))
        XCTAssertFalse(status.contains("没有新内容"))
    }

    func testBackgroundSchedulingRequiresTrackingAndPermission() {
        XCTAssertTrue(UpdateNotificationBackgroundRefreshPolicy.shouldSchedule(
            hasTrackingTarget: true,
            permissionState: .enabled
        ))
        XCTAssertFalse(UpdateNotificationBackgroundRefreshPolicy.shouldSchedule(
            hasTrackingTarget: true,
            permissionState: .notDetermined
        ))
        XCTAssertFalse(UpdateNotificationBackgroundRefreshPolicy.shouldSchedule(
            hasTrackingTarget: true,
            permissionState: .denied
        ))
        XCTAssertFalse(UpdateNotificationBackgroundRefreshPolicy.shouldSchedule(
            hasTrackingTarget: false,
            permissionState: .enabled
        ))
    }

    func testNotificationDynamicFetchPolicyIsNetworkOnly() {
        XCTAssertFalse(DynamicFeedFetchPolicy.networkOnly.readsFreshDiskSnapshot)
        XCTAssertTrue(DynamicFeedFetchPolicy.preferFreshDiskSnapshot.readsFreshDiskSnapshot)
    }

    func testMarkedAnimeBadgeAccessibilityCopyIsContextual() {
        XCTAssertEqual(UpdateNotificationAccessibilityText.markedAnimeCount(3), "3 个追更项目")
        XCTAssertFalse(UpdateNotificationAccessibilityText.markedAnimeCount(3).contains("未读"))
    }

    func testBackgroundCopyDoesNotPromiseRealtimeDelivery() {
        XCTAssertTrue(UpdateNotificationCopy.backgroundDeliveryNotice.contains("系统允许的后台刷新"))
        XCTAssertTrue(UpdateNotificationCopy.backgroundDeliveryNotice.contains("无法保证实时送达"))
    }

    private static func page(cid: Int, page: Int, title: String) -> VideoPage {
        VideoPage(cid: cid, page: page, part: title, duration: 120, dimension: nil)
    }

    private static func video(pages: [VideoPage]) -> VideoItem {
        VideoItem(
            bvid: "BV1TESTUPDATE",
            aid: 123,
            title: "测试番剧",
            pic: "https://i0.hdslb.com/test.jpg",
            desc: "完整快照",
            duration: 120,
            pubdate: 1_700_000_000,
            owner: VideoOwner(mid: 42, name: "测试 UP", face: "https://i0.hdslb.com/avatar.jpg"),
            stat: nil,
            cid: pages.first?.cid,
            pages: pages,
            dimension: nil
        )
    }
}

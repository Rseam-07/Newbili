import XCTest
@testable import bili

final class WatchLaterModelsTests: XCTestCase {
    func testWatchLaterQueryOptionsMatchPiliPlusContract() {
        XCTAssertEqual(WatchLaterFilter.all.rawValue, 0)
        XCTAssertEqual(WatchLaterFilter.unfinished.rawValue, 2)
        XCTAssertEqual(WatchLaterSortOrder.newest.ascendingQueryValue, "false")
        XCTAssertEqual(WatchLaterSortOrder.oldest.ascendingQueryValue, "true")
        XCTAssertNil(WatchLaterClearScope.all.cleanType)
        XCTAssertEqual(WatchLaterClearScope.invalid.cleanType, 1)
        XCTAssertEqual(WatchLaterClearScope.viewed.cleanType, 2)
    }

    func testRegularWatchLaterEntryKeepsPlaybackProgressAndPublishedDate() throws {
        let payload = try decodePayload(
            """
            {
              "count": 1,
              "list": [{
                "aid": 170001,
                "bvid": "BV17x411w7KC",
                "title": "测试视频",
                "pic": "//i0.hdslb.com/test.jpg",
                "pubdate": 1720000000,
                "duration": 600,
                "progress": 120,
                "cid": 279786,
                "owner": {"mid": 2, "name": "UP主", "face": "//i0.hdslb.com/face.jpg"},
                "stat": {"view": 1234, "reply": 12, "like": 88}
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)
        XCTAssertEqual(entry.aid, 170001)
        XCTAssertEqual(entry.bvid, "BV17x411w7KC")
        XCTAssertEqual(entry.playbackTime, 120)
        XCTAssertEqual(entry.playbackDuration, 600)
        XCTAssertEqual(try XCTUnwrap(entry.playbackProgress), 0.2, accuracy: 0.0001)
        XCTAssertEqual(entry.savedAt.timeIntervalSince1970, 1720000000, accuracy: 0.1)
        XCTAssertEqual(entry.owner?.name, "UP主")
        XCTAssertEqual(entry.stat?.view, 1234)
        XCTAssertEqual(entry.videoItem.historyResumeTime, 120)
    }

    func testPGCWatchLaterEntryUsesNestedBangumiRoute() throws {
        let payload = try decodePayload(
            """
            {
              "count": 1,
              "list": [{
                "aid": 987,
                "bvid": "BV1PGCWatch01",
                "title": "测试番剧 第一集",
                "redirect_url": "https://www.bilibili.com/bangumi/play/ep246810",
                "is_pgc": true,
                "duration": 1440,
                "progress": 45,
                "cid": 13579,
                "bangumi": {
                  "ep_id": 246810,
                  "season": {"season_id": 97531, "title": "测试番剧"}
                }
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)
        XCTAssertEqual(entry.pgcEpisodeID, 246810)
        XCTAssertEqual(entry.pgcSeasonID, 97531)
        XCTAssertTrue(entry.videoItem.isPGCEpisode)
        XCTAssertEqual(entry.videoItem.historyCID, 13579)
        XCTAssertEqual(entry.videoItem.historyResumeTime, 45)
    }

    func testPGCWatchLaterEntryWithoutBVIDFallsBackToEpisodeIdentity() throws {
        let payload = try decodePayload(
            """
            {
              "list": [{
                "title": "仅番剧标识",
                "is_pgc": 1,
                "bangumi": {"ep_id": 112233, "season": {"id": 445566}}
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)
        XCTAssertEqual(entry.bvid, "ep112233")
        XCTAssertEqual(entry.pgcEpisodeID, 112233)
        XCTAssertEqual(entry.pgcSeasonID, 445566)
        XCTAssertTrue(entry.videoItem.isPGCEpisode)
    }

    private func decodePayload(_ json: String) throws -> DynamicJSONValue {
        try JSONDecoder().decode(DynamicJSONValue.self, from: Data(json.utf8))
    }
}

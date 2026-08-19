import XCTest
@testable import bili

final class AccountHistoryRouteTests: XCTestCase {
    func testPGCHistoryEntryKeepsEpisodeIdentityForUnifiedPlaybackPage() throws {
        let payload = try decodePayload(
            """
            {
              "list": [{
                "title": "测试番剧",
                "long_title": "第一集",
                "cover": "https://example.com/cover.jpg",
                "uri": "https://www.bilibili.com/bangumi/play/ep987654",
                "duration": 1440,
                "progress": 120,
                "view_at": 1720000000,
                "history": {
                  "business": "pgc",
                  "bvid": "BV1PGCTest01",
                  "oid": 123456,
                  "cid": 654321,
                  "epid": 987654
                }
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)

        XCTAssertEqual(entry.pgcEpisodeID, 987654)
        XCTAssertTrue(entry.videoItem.isPGCEpisode)
        XCTAssertEqual(entry.videoItem.pgcEpisodeID, 987654)
        XCTAssertEqual(entry.videoItem.historyCID, 654321)
        XCTAssertEqual(entry.videoItem.historyResumeTime, 120)
    }

    func testRegularHistoryEntryRemainsRegularVideo() throws {
        let payload = try decodePayload(
            """
            {
              "list": [{
                "title": "普通视频",
                "bvid": "BV1VideoTest1",
                "duration": 300,
                "progress": 30,
                "view_at": 1720000000,
                "history": {
                  "business": "archive",
                  "bvid": "BV1VideoTest1",
                  "oid": 123,
                  "cid": 456
                }
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)

        XCTAssertNil(entry.pgcSeasonID)
        XCTAssertNil(entry.pgcEpisodeID)
        XCTAssertFalse(entry.videoItem.isPGCEpisode)
    }

    func testPGCHistoryIgnoresZeroEpisodeIDAndUsesRouteEpisode() throws {
        let payload = try decodePayload(
            """
            {
              "list": [{
                "title": "测试番剧",
                "bvid": "BV1PGCTest02",
                "uri": "bilibili://pgc/season/ep/246810",
                "duration": 1200,
                "history": {
                  "business": "pgc",
                  "bvid": "BV1PGCTest02",
                  "cid": 13579,
                  "epid": 0
                }
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)

        XCTAssertEqual(entry.pgcEpisodeID, 246810)
        XCTAssertTrue(entry.videoItem.isPGCEpisode)
    }

    func testPGCHistoryUsesOIDAsEpisodeIDWhenTheAPIOmitsEPIDAndBVID() throws {
        let payload = try decodePayload(
            """
            {
              "list": [{
                "title": "测试番剧",
                "uri": "https://www.bilibili.com/bangumi/play/ss13579",
                "duration": 1200,
                "progress": 180,
                "history": {
                  "business": "pgc",
                  "oid": 246810,
                  "cid": 135790,
                  "epid": 0
                }
              }]
            }
            """
        )

        let entry = try XCTUnwrap(payload.accountVideoEntries.first)

        XCTAssertEqual(entry.pgcSeasonID, 13579)
        XCTAssertEqual(entry.pgcEpisodeID, 246810)
        XCTAssertEqual(entry.videoItem.bvid, "ep246810")
        XCTAssertTrue(entry.videoItem.isPGCEpisode)
        XCTAssertNil(entry.videoItem.aid)
    }

    private func decodePayload(_ json: String) throws -> DynamicJSONValue {
        try JSONDecoder().decode(DynamicJSONValue.self, from: Data(json.utf8))
    }
}

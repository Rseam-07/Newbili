import XCTest
@testable import bili

final class PgcSeasonPlaybackRouteTests: XCTestCase {
    func testPreferredPlaybackEpisodeUsesCloudResumeEpisode() throws {
        let season = try decodeSeason(
            """
            {
              "season_id": 100,
              "episodes": [
                { "id": 1, "ep_id": 101, "cid": 1001, "title": "1" },
                { "id": 2, "ep_id": 102, "cid": 1002, "title": "2" }
              ],
              "user_status": { "progress": { "last_ep_id": 102 } }
            }
            """
        )

        XCTAssertEqual(season.preferredPlaybackEpisode?.epID, 102)
    }

    func testPreferredPlaybackEpisodeFallsBackToFirstPlayableEpisode() throws {
        let season = try decodeSeason(
            """
            {
              "season_id": 100,
              "episodes": [
                { "id": 1, "ep_id": 101, "title": "不可播放" },
                { "id": 2, "ep_id": 102, "cid": 1002, "title": "可播放" }
              ]
            }
            """
        )

        XCTAssertEqual(season.preferredPlaybackEpisode?.epID, 102)
    }

    private func decodeSeason(_ json: String) throws -> PgcSeasonInfo {
        try JSONDecoder().decode(PgcSeasonInfo.self, from: Data(json.utf8))
    }
}

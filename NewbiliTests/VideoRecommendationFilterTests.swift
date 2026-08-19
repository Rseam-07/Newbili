import XCTest
@testable import bili

final class VideoRecommendationFilterTests: XCTestCase {
    func testInactiveConfigurationKeepsVideosInFeedAndRelated() {
        let videos = [
            video("BV1", title: "短视频", duration: 20, view: 10, like: 0),
            video("BV2", title: "正常视频", duration: 120, view: 1_000, like: 40)
        ]
        let configuration = VideoRecommendationFilterConfiguration(
            minimumDurationSeconds: 0,
            minimumViewCount: 0,
            minimumLikeRatioPercent: 0,
            blockedKeywords: [],
            appliesToRelatedVideos: false
        )

        XCTAssertEqual(
            VideoRecommendationFilter.filtered(videos, configuration: configuration, context: .feed),
            videos
        )
        XCTAssertEqual(
            VideoRecommendationFilter.filtered(videos, configuration: configuration, context: .related),
            videos
        )
    }

    func testFeedFiltersByDurationViewsLikeRatioAndTitleKeyword() {
        let videos = [
            video("BV1", title: "太短", duration: 30, view: 1_000, like: 50),
            video("BV2", title: "播放太低", duration: 120, view: 100, like: 50),
            video("BV3", title: "点赞太低", duration: 120, view: 1_000, like: 10),
            video("BV4", title: "广告合集", duration: 120, view: 1_000, like: 50),
            video("BV5", title: "保留", duration: 120, view: 1_000, like: 50)
        ]
        let configuration = VideoRecommendationFilterConfiguration(
            minimumDurationSeconds: 60,
            minimumViewCount: 500,
            minimumLikeRatioPercent: 2,
            blockedKeywords: ["广告"],
            appliesToRelatedVideos: false
        )

        XCTAssertEqual(
            VideoRecommendationFilter.filtered(videos, configuration: configuration, context: .feed).map(\.bvid),
            ["BV5"]
        )
    }

    func testRelatedFilteringRequiresRelatedToggle() {
        let videos = [
            video("BV1", title: "播放太低", duration: 120, view: 100, like: 50),
            video("BV2", title: "保留", duration: 120, view: 1_000, like: 50)
        ]
        let disabledConfiguration = VideoRecommendationFilterConfiguration(
            minimumDurationSeconds: 0,
            minimumViewCount: 500,
            minimumLikeRatioPercent: 0,
            blockedKeywords: [],
            appliesToRelatedVideos: false
        )
        let enabledConfiguration = VideoRecommendationFilterConfiguration(
            minimumDurationSeconds: 0,
            minimumViewCount: 500,
            minimumLikeRatioPercent: 0,
            blockedKeywords: [],
            appliesToRelatedVideos: true
        )

        XCTAssertEqual(
            VideoRecommendationFilter.filtered(videos, configuration: disabledConfiguration, context: .related).map(\.bvid),
            ["BV1", "BV2"]
        )
        XCTAssertEqual(
            VideoRecommendationFilter.filtered(videos, configuration: enabledConfiguration, context: .related).map(\.bvid),
            ["BV2"]
        )
    }

    private func video(
        _ bvid: String,
        title: String,
        duration: Int,
        view: Int,
        like: Int
    ) -> VideoItem {
        VideoItem(
            bvid: bvid,
            aid: nil,
            title: title,
            pic: nil,
            desc: nil,
            duration: duration,
            pubdate: nil,
            owner: nil,
            stat: VideoStat(view: view, reply: nil, like: like, coin: nil, favorite: nil),
            cid: nil,
            pages: nil,
            dimension: nil
        )
    }
}

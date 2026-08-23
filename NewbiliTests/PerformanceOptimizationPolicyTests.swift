import XCTest
@testable import bili

final class PerformanceOptimizationPolicyTests: XCTestCase {
    func testRealtimeAmbientBlurRemainsEnabledByDefault() {
        XCTAssertTrue(HomeRealtimeBlurSettings.defaultIsEnabled)
    }

    func testAudioMiniPlayerDoesNotPublishAnIdenticalVisibleSnapshot() {
        let snapshot = makeSnapshot(isPlaying: true)

        XCTAssertFalse(
            AudioMiniPlayerSnapshotPublicationPolicy.shouldPublish(
                snapshot,
                replacing: snapshot
            )
        )
    }

    func testAudioMiniPlayerPublishesAPlaybackStateChange() {
        XCTAssertTrue(
            AudioMiniPlayerSnapshotPublicationPolicy.shouldPublish(
                makeSnapshot(isPlaying: false),
                replacing: makeSnapshot(isPlaying: true)
            )
        )
    }

    private func makeSnapshot(isPlaying: Bool) -> AudioMiniPlayerSnapshot {
        AudioMiniPlayerSnapshot(
            video: VideoItem(
                bvid: "BV-performance",
                aid: nil,
                title: "性能回归样本",
                pic: "https://example.com/cover.jpg",
                desc: nil,
                duration: 180,
                pubdate: nil,
                owner: nil,
                stat: nil,
                cid: 1,
                pages: nil,
                dimension: nil
            ),
            isPlaying: isPlaying,
            canPlayNext: true,
            artworkURLString: "https://example.com/cover.jpg",
            ownerName: "Newbili"
        )
    }
}

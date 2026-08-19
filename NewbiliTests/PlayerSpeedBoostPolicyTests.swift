import XCTest
@testable import bili

final class PlayerSpeedBoostPolicyTests: XCTestCase {
    func testRejectsTerminatedPlayback() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: true,
                isLiveStream: false,
                isPlaying: true,
                currentRate: .x10
            ),
            .terminated
        )
    }

    func testRejectsLivePlayback() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: true,
                isPlaying: true,
                currentRate: .x10
            ),
            .live
        )
    }

    func testRejectsPausedPlayback() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: false,
                isPlaying: false,
                currentRate: .x10
            ),
            .paused
        )
    }

    func testRejectsWhenAlreadyAtTwoTimesSpeed() {
        XCTAssertEqual(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: false,
                isPlaying: true,
                currentRate: .x20
            ),
            .alreadyAtMaximumRate
        )
    }

    func testAllowsPlayingVideoOnARegularRate() {
        XCTAssertNil(
            PlayerSpeedBoostPolicy.rejectionReason(
                isTerminated: false,
                isLiveStream: false,
                isPlaying: true,
                currentRate: .x15
            )
        )
    }

    @MainActor
    func testPlayerReplacementRestoresThePlayerThatStartedSpeedBoost() {
        let playerA = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "Player A",
            referer: "https://www.bilibili.com"
        )
        let playerB = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "Player B",
            referer: "https://www.bilibili.com"
        )
        defer {
            playerA.stop()
            playerB.stop()
        }

        playerA.setPlaybackRate(.x15)
        playerB.setPlaybackRate(.x075)
        let model = PlayerSpeedBoostModel()
        XCTAssertTrue(
            model.beginIfNeeded(
                playerViewModel: playerA,
                isSurfacePlaying: true,
                hidePlaybackControls: {}
            )
        )
        XCTAssertEqual(playerA.playbackRate, .x20)

        var didShowControls = false
        model.end(
            reason: .playerChanged,
            playerViewModel: playerB,
            showPlaybackControls: { didShowControls = true }
        )

        XCTAssertEqual(playerA.playbackRate, .x15)
        XCTAssertEqual(playerB.playbackRate, .x075)
        XCTAssertFalse(didShowControls)
    }
}

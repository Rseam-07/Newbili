import AVFoundation
import XCTest
@testable import bili

final class BackgroundPlaybackLifecycleTests: XCTestCase {
    @MainActor
    func testAVPlayerExplicitlyAllowsPermittedBackgroundPlayback() {
        let engine = AVPlayerHLSBridgeEngine()

        XCTAssertEqual(
            engine.audiovisualBackgroundPlaybackPolicyForTesting,
            .continuesIfPossible
        )
    }

    func testPlayerDisappearKeepsListenAndPictureInPictureSessionsAlive() {
        XCTAssertFalse(
            BiliPlayerDisappearancePolicy.shouldSuspend(
                pausesOnDisappear: true,
                isFullscreenActive: false,
                isAudioOnlyPlayback: true,
                isPictureInPictureActive: false
            )
        )
        XCTAssertFalse(
            BiliPlayerDisappearancePolicy.shouldSuspend(
                pausesOnDisappear: true,
                isFullscreenActive: false,
                isAudioOnlyPlayback: false,
                isPictureInPictureActive: true
            )
        )
        XCTAssertTrue(
            BiliPlayerDisappearancePolicy.shouldSuspend(
                pausesOnDisappear: true,
                isFullscreenActive: false,
                isAudioOnlyPlayback: false,
                isPictureInPictureActive: false
            )
        )
    }
}

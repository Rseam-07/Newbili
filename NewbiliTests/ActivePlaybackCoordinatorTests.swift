import XCTest
import UIKit
@testable import bili

@MainActor
final class ActivePlaybackCoordinatorTests: XCTestCase {
    func testCancelledNavigationRestoresActivePlayerIntent() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        defer { coordinator.stopActivePlayback() }

        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "导航恢复测试",
            referer: "https://www.bilibili.com"
        )
        let surface = VideoSurfaceContainerView()
        player.attachSurface(surface, prefersNativePlaybackControls: false)
        player.play()

        XCTAssertTrue(coordinator.isActive(player))
        XCTAssertTrue(player.wantsAutoplay)

        coordinator.pauseActivePlaybackForNavigation()

        XCTAssertFalse(player.wantsAutoplay)
        let pendingResumeState = player.pendingNavigationResumeState()
        XCTAssertNotNil(pendingResumeState)
        XCTAssertTrue(pendingResumeState?.shouldResumePlayback == true)
        XCTAssertTrue(coordinator.resumeActivePlaybackAfterCancelledNavigation())
        XCTAssertTrue(coordinator.isActive(player))
        XCTAssertTrue(player.wantsAutoplay)
    }

    func testCancelledNavigationWithoutActivePlayerDoesNothing() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()

        XCTAssertFalse(coordinator.resumeActivePlaybackAfterCancelledNavigation())
    }

    func testNavigationPauseLeavesActivePictureInPicturePlaybackRunning() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        defer { coordinator.stopActivePlayback() }

        let engine = PlayerLifecycleEngineSpy(isPlaying: true)
        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "画中画导航测试",
            referer: "https://www.bilibili.com",
            engine: engine
        )
        let surface = VideoSurfaceContainerView()
        player.attachSurface(surface, prefersNativePlaybackControls: false)
        coordinator.activate(player)
        player.setPlaybackIntent(true)
        player.isPictureInPictureActive = true

        coordinator.pauseActivePlaybackForNavigation()

        XCTAssertEqual(engine.pauseCallCount, 0)
        XCTAssertTrue(player.isPictureInPictureActive)
        XCTAssertTrue(player.wantsAutoplay)
        XCTAssertNil(player.pendingNavigationResumeState())
    }

    func testGlobalAppBackgroundPauseStopsRecordedVideoWithoutResumeIntent() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        defer { coordinator.stopActivePlayback() }

        let engine = PlayerLifecycleEngineSpy(isPlaying: true)
        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "全局后台暂停测试",
            referer: "https://www.bilibili.com",
            engine: engine
        )
        let surface = VideoSurfaceContainerView()
        player.attachSurface(surface, prefersNativePlaybackControls: false)
        coordinator.activate(player)
        player.setPlaybackIntent(true)
        engine.onFirstFrame?(12)

        XCTAssertTrue(coordinator.pauseActivePlaybackForAppBackground())
        XCTAssertFalse(player.wantsAutoplay)
        XCTAssertEqual(engine.backgroundPauseCallCount, 1)
        XCTAssertFalse(player.resumePlaybackAfterAppBackgroundIfNeeded())
        XCTAssertTrue(player.prepareStoppedPlaybackAfterAppBackgroundIfNeeded())
        XCTAssertEqual(engine.videoOutputRefreshCallCount, 1)
        XCTAssertEqual(engine.pausedPlaybackWarmCallCount, 1)
        XCTAssertEqual(engine.playerItemRecoveryCallCount, 0)
        XCTAssertFalse(player.wantsAutoplay)
    }

    func testAppDelegateBackgroundCallbacksUseIdempotentGlobalPause() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        defer { coordinator.stopActivePlayback() }

        let engine = PlayerLifecycleEngineSpy(isPlaying: true)
        let player = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "应用代理后台暂停测试",
            referer: "https://www.bilibili.com",
            engine: engine
        )
        let surface = VideoSurfaceContainerView()
        player.attachSurface(surface, prefersNativePlaybackControls: false)
        coordinator.activate(player)
        player.setPlaybackIntent(true)

        let appDelegate = AppDelegate()
        appDelegate.applicationDidEnterBackground(UIApplication.shared)
        appDelegate.applicationProtectedDataWillBecomeUnavailable(UIApplication.shared)

        XCTAssertEqual(engine.backgroundPauseCallCount, 1)
        XCTAssertFalse(player.wantsAutoplay)
    }

    func testVisualPlaybackRetentionBudgetKeepsOnlyCurrentAndPreviousPlayer() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        let players = (0..<4).map { index in
            PlayerStateViewModel(
                videoURL: nil,
                audioURL: nil,
                title: "深链播放器 \(index)",
                referer: "https://www.bilibili.com/video/BV-retention-\(index)"
            )
        }
        defer {
            players.forEach { $0.stop() }
            coordinator.stopActivePlayback()
        }

        players.forEach { coordinator.activate($0) }

        XCTAssertEqual(players.filter { !$0.isTerminated }.count, 2)
        XCTAssertTrue(players[0].isTerminated)
        XCTAssertTrue(players[1].isTerminated)
        XCTAssertFalse(players[2].isTerminated)
        XCTAssertFalse(players[3].isTerminated)
        XCTAssertTrue(coordinator.isActive(players[3]))
    }

    func testVisualPlaybackRetentionBudgetDoesNotTerminateListenOrPictureInPicturePlayers() {
        let coordinator = ActivePlaybackCoordinator.shared
        coordinator.stopActivePlayback()
        let listenPlayer = PlayerStateViewModel(
            videoURL: nil,
            audioURL: URL(string: "https://example.com/audio.m4s"),
            title: "听视频保留测试",
            referer: "https://www.bilibili.com",
            playbackContentMode: .audioOnly
        )
        let pictureInPicturePlayer = PlayerStateViewModel(
            videoURL: nil,
            audioURL: nil,
            title: "画中画保留测试",
            referer: "https://www.bilibili.com"
        )
        pictureInPicturePlayer.isPictureInPictureActive = true
        let visualPlayers = (0..<3).map { index in
            PlayerStateViewModel(
                videoURL: nil,
                audioURL: nil,
                title: "普通播放器 \(index)",
                referer: "https://www.bilibili.com/video/BV-visual-\(index)"
            )
        }
        let players = [listenPlayer, pictureInPicturePlayer] + visualPlayers
        defer {
            players.forEach { $0.stop() }
            coordinator.stopActivePlayback()
        }

        coordinator.activate(listenPlayer)
        coordinator.activate(pictureInPicturePlayer)
        visualPlayers.forEach { coordinator.activate($0) }

        XCTAssertFalse(listenPlayer.isTerminated)
        XCTAssertFalse(pictureInPicturePlayer.isTerminated)
        XCTAssertEqual(visualPlayers.filter { !$0.isTerminated }.count, 2)
    }
}

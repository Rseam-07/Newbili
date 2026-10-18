import XCTest
import UIKit
@testable import bili

final class DanmakuLaneSchedulingTests: XCTestCase {
    func testFasterLongMessageCannotCatchShortPredecessor() {
        XCTAssertFalse(DanmakuMotionTiming.canFollow(surfaceWidth: 390, previousWidth: 80, previousStart: 0, previousDuration: 8, nextWidth: 500, nextDuration: 8, at: 2, gap: 30))
        XCTAssertTrue(DanmakuMotionTiming.canFollow(surfaceWidth: 390, previousWidth: 80, previousStart: 0, previousDuration: 8, nextWidth: 500, nextDuration: 8, at: 5, gap: 30))
    }

    func testSlowerFollowerStillNeedsEntranceClearance() {
        XCTAssertFalse(DanmakuMotionTiming.canFollow(surfaceWidth: 390, previousWidth: 240, previousStart: 0, previousDuration: 8, nextWidth: 80, nextDuration: 8, at: 1, gap: 30))
        XCTAssertTrue(DanmakuMotionTiming.canFollow(surfaceWidth: 390, previousWidth: 240, previousStart: 0, previousDuration: 8, nextWidth: 80, nextDuration: 8, at: 4, gap: 30))
    }

    @MainActor
    func testMixedFontSizesUseOneNonOverlappingScrollingGrid() {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        defer { view.stop() }
        view.layoutIfNeeded()
        var settings = DanmakuSettings.default
        settings.fontScale = 0.7
        settings.displayArea = .full
        let items = [12.0, 25.0, 36.0, 64.0].enumerated().map {
            DanmakuItem(id: "font-\($0.offset)", time: 1, mode: 1, fontSize: $0.element, color: 0xFFFFFF, text: "不同字号不会重叠")
        }
        view.apply(items: items, itemsRevision: 1, currentTime: 2, isPlaying: false, playbackRate: 1, isEnabled: true, hasPresentedPlayback: true, isLoadShedding: false, settings: settings, topInset: 8, bottomInset: 54)
        let frames = view.subviews.compactMap { ($0 as? DanmakuTextLabel)?.frame }
        XCTAssertEqual(frames.count, items.count)
        for i in frames.indices {
            for j in frames.indices where j > i { XCTAssertFalse(frames[i].intersects(frames[j])) }
        }
    }

    @MainActor
    func testSpeedChangesAndPauseResumePreserveLayerClockContinuity() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UIViewController()
        window.rootViewController = controller
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        controller.view.addSubview(view)
        window.isHidden = false
        defer { view.stop(); window.isHidden = true }
        view.layoutIfNeeded()
        let items = [DanmakuItem(id: "clock", time: 1, mode: 1, fontSize: 25, color: 0xFFFFFF, text: "倍速保持连续")]
        func apply(_ rate: Double, playing: Bool = true) {
            view.apply(items: items, itemsRevision: 1, currentTime: 2, isPlaying: playing, playbackRate: rate, isEnabled: true, hasPresentedPlayback: true, isLoadShedding: false, settings: .default, topInset: 8, bottomInset: 54)
        }
        apply(1)
        for rate in [1.5, 2, 0.5, 1] {
            let before = view.layer.convertTime(CACurrentMediaTime(), from: nil)
            apply(rate)
            let after = view.layer.convertTime(CACurrentMediaTime(), from: nil)
            XCTAssertEqual(after, before, accuracy: 0.05, "Rate \(rate) must not jump the animation clock")
            XCTAssertEqual(view.layer.speed, Float(rate))
        }
        apply(2, playing: false)
        let paused = view.layer.convertTime(CACurrentMediaTime(), from: nil)
        apply(2)
        XCTAssertEqual(view.layer.convertTime(CACurrentMediaTime(), from: nil), paused, accuracy: 0.05)
    }

    @MainActor
    func testFixedDanmakuHaveSeparateRowsEvenWhenHashesCollide() {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        defer { view.stop() }
        view.layoutIfNeeded()
        view.apply(items: (0..<9).map { DanmakuItem(id: "fixed-\($0)", time: 1, mode: 5, fontSize: 25, color: 0xFFFFFF, text: "固定弹幕\($0)") }, itemsRevision: 1, currentTime: 2, isPlaying: false, playbackRate: 1, isEnabled: true, hasPresentedPlayback: true, isLoadShedding: false, settings: .default, topInset: 8, bottomInset: 54)
        let frames = view.subviews.compactMap { ($0 as? DanmakuTextLabel)?.frame }
        XCTAssertGreaterThan(frames.count, 1)
        for i in frames.indices {
            for j in frames.indices where j > i { XCTAssertFalse(frames[i].intersects(frames[j])) }
        }
    }

    @MainActor
    func testPauseResumeKeepsTheExistingScrollingLabel() throws {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        defer { view.stop() }
        view.layoutIfNeeded()
        let items = [DanmakuItem(id: "continuous", time: 1, mode: 1, fontSize: 25, color: 0xFFFFFF, text: "连续播放")]
        func apply(_ playing: Bool) {
            view.apply(items: items, itemsRevision: 1, currentTime: 2, isPlaying: playing, playbackRate: 1, isEnabled: true, hasPresentedPlayback: true, isLoadShedding: false, settings: .default, topInset: 8, bottomInset: 54)
        }
        apply(true)
        let label = try XCTUnwrap(view.subviews.compactMap { $0 as? DanmakuTextLabel }.first)
        apply(false)
        apply(true)
        XCTAssertTrue(view.subviews.contains { $0 === label })
        XCTAssertNotNil(label.layer.animation(forKey: "danmaku.scroll"))
    }
}

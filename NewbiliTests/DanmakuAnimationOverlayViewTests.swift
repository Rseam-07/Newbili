import XCTest
import UIKit
@testable import bili

final class DanmakuAnimationOverlayViewTests: XCTestCase {
    func testXMLParserPreservesServerDanmakuIdentifierForInteractions() throws {
        let data = try XCTUnwrap(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <i><d p="12.5,1,25,16777215,1700000000,0,abcdef,987654321">可以点赞的弹幕</d></i>
            """.data(using: .utf8)
        )

        let item = try XCTUnwrap(DanmakuXMLParser(cid: 123).parse(data: data).first)

        XCTAssertEqual(item.dmid, 987_654_321)
        XCTAssertEqual(item.time, 12.5, accuracy: 0.001)
        XCTAssertEqual(item.text, "可以点赞的弹幕")
        XCTAssertTrue(item.id.contains("987654321"))
    }

    @MainActor
    func testLayoutTransitionPreservesActiveLabelAndAnimation() throws {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.layoutIfNeeded()
        view.apply(
            items: [DanmakuItem(id: "rotation", time: 1, mode: 5, fontSize: 25, color: 0x00FF_FFFF, text: "rotation")],
            itemsRevision: 1,
            currentTime: 2,
            isPlaying: true,
            playbackRate: 1,
            isEnabled: true,
            hasPresentedPlayback: true,
            isLoadShedding: false,
            settings: .default,
            topInset: 8,
            bottomInset: 54
        )

        let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first)
        let portraitCenter = label.center
        XCTAssertNotNil(label.layer.animation(forKey: "danmaku.opacity"))

        view.setLayoutTransitioning(true)
        view.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        view.layoutIfNeeded()

        XCTAssertEqual(label.center, portraitCenter)

        view.setLayoutTransitioning(false)

        XCTAssertTrue(view.subviews.contains { $0 === label })
        XCTAssertEqual(label.center, portraitCenter)
        XCTAssertNotNil(label.layer.animation(forKey: "danmaku.opacity"))
    }

    @MainActor
    func testRenderedDanmakuParticipatesInHitTesting() throws {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.onSelectItem = { _ in }
        view.layoutIfNeeded()
        view.apply(
            items: [DanmakuItem(id: "interactive", time: 1, mode: 5, fontSize: 25, color: 0x00FF_FFFF, text: "可交互弹幕")],
            itemsRevision: 1,
            currentTime: 2,
            isPlaying: false,
            playbackRate: 1,
            isEnabled: true,
            hasPresentedPlayback: true,
            isLoadShedding: false,
            settings: .default,
            topInset: 8,
            bottomInset: 54
        )

        let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first)

        XCTAssertTrue(view.point(inside: label.center, with: nil))
        XCTAssertFalse(view.point(inside: CGPoint(x: 2, y: 178), with: nil))
    }
}

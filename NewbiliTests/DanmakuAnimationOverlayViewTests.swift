import XCTest
import UIKit
@testable import bili

final class DanmakuAnimationOverlayViewTests: XCTestCase {
    func testTextPalettePreservesServerRGBAndChoosesAContrastingOutline() {
        XCTAssertEqual(
            DanmakuTextColorPalette.resolved(from: 0xAB_FF_00_00),
            DanmakuTextColorPalette(foregroundRGB: 0xFF_00_00, outlineRGB: 0x00_00_00)
        )
        XCTAssertEqual(
            DanmakuTextColorPalette.resolved(from: 0x00_00_00),
            DanmakuTextColorPalette(foregroundRGB: 0x00_00_00, outlineRGB: 0xFF_FF_FF)
        )
        XCTAssertEqual(
            DanmakuTextColorPalette.resolved(from: 0xFF_FF_FF),
            DanmakuTextColorPalette(foregroundRGB: 0xFF_FF_FF, outlineRGB: 0x00_00_00)
        )
    }

    @MainActor
    func testAttributedDanmakuRetainsItsServerColorInsteadOfRenderingAllBlack() throws {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        view.layoutIfNeeded()
        view.apply(
            items: [
                DanmakuItem(id: "red", time: 1, mode: 5, fontSize: 25, color: 0xFF_00_00, text: "红色弹幕"),
                DanmakuItem(id: "blue", time: 1, mode: 4, fontSize: 25, color: 0x00_00_FF, text: "蓝色弹幕")
            ],
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

        let labels = Dictionary(
            uniqueKeysWithValues: view.subviews.compactMap { subview -> (String, UILabel)? in
                guard let label = subview as? UILabel, let text = label.attributedText?.string else {
                    return nil
                }
                return (text, label)
            }
        )
        let redLabel = try XCTUnwrap(labels["红色弹幕"])
        let blueLabel = try XCTUnwrap(labels["蓝色弹幕"])
        let redAttributes = try XCTUnwrap(redLabel.attributedText?.attributes(at: 0, effectiveRange: nil))
        let blueAttributes = try XCTUnwrap(blueLabel.attributedText?.attributes(at: 0, effectiveRange: nil))
        let redForeground = try XCTUnwrap(redAttributes[.foregroundColor] as? UIColor)
        let redOutline = try XCTUnwrap(redAttributes[.strokeColor] as? UIColor)
        let blueForeground = try XCTUnwrap(blueAttributes[.foregroundColor] as? UIColor)
        let blueOutline = try XCTUnwrap(blueAttributes[.strokeColor] as? UIColor)

        XCTAssertTrue(redForeground.isApproximatelyRGB(red: 1, green: 0, blue: 0))
        XCTAssertTrue(redOutline.isApproximatelyRGB(red: 0, green: 0, blue: 0))
        XCTAssertTrue(blueForeground.isApproximatelyRGB(red: 0, green: 0, blue: 1))
        XCTAssertTrue(blueOutline.isApproximatelyRGB(red: 1, green: 1, blue: 1))
    }

    func testQuickActionLayoutStaysInsideLandscapeAndIPadBounds() {
        let container = CGRect(x: 0, y: 0, width: 1_024, height: 420)
        let result = DanmakuQuickActionLayout.frame(
            anchoredTo: CGRect(x: 990, y: 180, width: 80, height: 30),
            menuSize: CGSize(width: 152, height: 48),
            in: container
        )

        XCTAssertGreaterThanOrEqual(result.minX, 8)
        XCTAssertLessThanOrEqual(result.maxX, container.maxX - 8)
        XCTAssertEqual(result.maxY, 174, accuracy: 0.001)
    }

    func testQuickActionLayoutMovesBelowDanmakuNearTopEdge() {
        let anchor = CGRect(x: 80, y: 7, width: 120, height: 28)
        let result = DanmakuQuickActionLayout.frame(
            anchoredTo: anchor,
            menuSize: CGSize(width: 152, height: 48),
            in: CGRect(x: 0, y: 0, width: 320, height: 180)
        )

        XCTAssertEqual(result.minY, anchor.maxY + 6, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(result.minX, 8)
        XCTAssertLessThanOrEqual(result.maxX, 312)
    }

    func testQuickActionPolicyOnlyExposesLikeForActionableDanmaku() {
        XCTAssertGreaterThanOrEqual(DanmakuQuickActionLayout.minimumHitDimension, 44)
        XCTAssertTrue(
            DanmakuQuickActionPolicy.showsLike(
                allowsRemoteInteraction: true,
                dmid: 42,
                hasLikeAction: true
            )
        )
        XCTAssertFalse(
            DanmakuQuickActionPolicy.showsLike(
                allowsRemoteInteraction: true,
                dmid: nil,
                hasLikeAction: true
            )
        )
        XCTAssertFalse(
            DanmakuQuickActionPolicy.showsLike(
                allowsRemoteInteraction: false,
                dmid: 42,
                hasLikeAction: true
            )
        )
    }

    func testGuestOrMissingDMIDCanOpenMoreButCannotLike() {
        let guestCanLike = DanmakuQuickActionPolicy.showsLike(
            allowsRemoteInteraction: false,
            dmid: 42,
            hasLikeAction: true
        )
        let missingDMIDCanLike = DanmakuQuickActionPolicy.showsLike(
            allowsRemoteInteraction: true,
            dmid: nil,
            hasLikeAction: true
        )
        let canOpenMore = DanmakuQuickActionPolicy.showsMore(hasMoreAction: true)

        XCTAssertFalse(guestCanLike)
        XCTAssertFalse(missingDMIDCanLike)
        XCTAssertTrue(canOpenMore)
        XCTAssertFalse(DanmakuQuickActionPolicy.showsMore(hasMoreAction: false))
    }

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
        XCTAssertEqual(item.senderIdentifier, "abcdef")
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
        XCTAssertTrue(
            view.point(
                inside: CGPoint(x: label.center.x, y: label.frame.maxY + 4),
                with: nil
            )
        )
        XCTAssertFalse(view.point(inside: CGPoint(x: 2, y: 178), with: nil))
    }

    @MainActor
    func testRenderedDanmakuDoesNotCaptureTouchesWhenTapInteractionIsDisabled() throws {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.onSelectItem = nil
        view.quickActions = nil
        view.layoutIfNeeded()
        view.apply(
            items: [DanmakuItem(id: "disabled", time: 1, mode: 5, fontSize: 25, color: 0x00FF_FFFF, text: "不拦截手势")],
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
        XCTAssertFalse(view.point(inside: label.center, with: nil))
    }

    @MainActor
    func testFilterSettingsRebuildVisibleItemsWithoutADataRevision() {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        let items = [
            DanmakuItem(id: "top", time: 1, mode: 5, fontSize: 25, color: 0xFFFFFF, text: "顶部内容"),
            DanmakuItem(id: "bottom", time: 1, mode: 4, fontSize: 25, color: 0xFFFFFF, text: "底部广告")
        ]
        view.layoutIfNeeded()

        view.apply(
            items: items,
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
        XCTAssertEqual(Set(renderedTexts(in: view)), ["顶部内容", "底部广告"])

        var settings = DanmakuSettings.default
        settings.showsTopDanmaku = false
        view.apply(
            items: items,
            itemsRevision: 1,
            currentTime: 2,
            isPlaying: false,
            playbackRate: 1,
            isEnabled: true,
            hasPresentedPlayback: true,
            isLoadShedding: false,
            settings: settings,
            topInset: 8,
            bottomInset: 54
        )
        XCTAssertEqual(renderedTexts(in: view), ["底部广告"])

        settings.blockedKeywords = ["广告"]
        view.apply(
            items: items,
            itemsRevision: 1,
            currentTime: 2,
            isPlaying: false,
            playbackRate: 1,
            isEnabled: true,
            hasPresentedPlayback: true,
            isLoadShedding: false,
            settings: settings,
            topInset: 8,
            bottomInset: 54
        )
        XCTAssertTrue(renderedTexts(in: view).isEmpty)
    }

    @MainActor
    private func renderedTexts(in view: DanmakuAnimationOverlayView) -> [String] {
        view.subviews.compactMap { ($0 as? UILabel)?.text }
    }
}

private extension UIColor {
    func isApproximatelyRGB(red: CGFloat, green: CGFloat, blue: CGFloat) -> Bool {
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &alpha) else {
            return false
        }
        return abs(actualRed - red) < 0.01
            && abs(actualGreen - green) < 0.01
            && abs(actualBlue - blue) < 0.01
            && alpha > 0
    }
}

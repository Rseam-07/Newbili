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

    func testReportedVideoProtobufSampleParsesAsWhiteDanmaku() throws {
        let payload = try XCTUnwrap(
            Data(
                base64Encoded: "Cm4IgL6X0JLg8K8eEJyyAxgBIBko////BzIHMWI0MjhiMjoV6YKj5bCx5LiN5piv5pys5Lq65LqGQKSBy9QGSApiEzIxODg2ODIzNTM2OTI3NjE4NTZogIBAogEBMKoBATDIAQHQAZ+GsISaAdgBAQ=="
            )
        )
        let item = try XCTUnwrap(
            DanmakuSegmentProtobufParser(cid: 41_348_236_063, segmentIndex: 1)
                .parse(data: payload)
                .first
        )

        XCTAssertEqual(item.text, "那就不是本人了")
        XCTAssertEqual(item.time, 55.58, accuracy: 0.001)
        XCTAssertEqual(item.color, 0xFF_FF_FF)
        XCTAssertEqual(item.fontSize, 25)
    }

    @MainActor
    func testDanmakuLabelRetainsItsServerColorInsteadOfRenderingAllBlack() throws {
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
            uniqueKeysWithValues: view.subviews.compactMap { subview -> (String, DanmakuTextLabel)? in
                guard let label = subview as? DanmakuTextLabel, let text = label.text else {
                    return nil
                }
                return (text, label)
            }
        )
        let redLabel = try XCTUnwrap(labels["红色弹幕"])
        let blueLabel = try XCTUnwrap(labels["蓝色弹幕"])

        XCTAssertTrue(redLabel.renderedForegroundColor.isApproximatelyRGB(red: 1, green: 0, blue: 0))
        XCTAssertTrue(redLabel.renderedOutlineColor.isApproximatelyRGB(red: 0, green: 0, blue: 0))
        XCTAssertTrue(blueLabel.renderedForegroundColor.isApproximatelyRGB(red: 0, green: 0, blue: 1))
        XCTAssertTrue(blueLabel.renderedOutlineColor.isApproximatelyRGB(red: 1, green: 1, blue: 1))
    }

    @MainActor
    func testRealWhiteDanmakuStillContainsWhitePixelsWithMaximumOutline() throws {
        let view = DanmakuAnimationOverlayView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        var settings = DanmakuSettings.default
        settings.opacity = 1
        settings.strokeWidth = 5
        view.layoutIfNeeded()
        view.apply(
            items: [
                DanmakuItem(
                    id: "real-sample",
                    time: 1,
                    mode: 5,
                    fontSize: 25,
                    color: 0xFF_FF_FF,
                    text: "那就不是本人了"
                )
            ],
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

        let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first)
        let colorCounts = try rasterColorCounts(in: label)

        XCTAssertGreaterThan(colorCounts.nearWhite, 20, "白色填充不能被黑色描边吞掉")
        XCTAssertGreaterThan(colorCounts.nearBlack, 20, "白色弹幕仍需保留深色轮廓")
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

    @MainActor
    private func rasterColorCounts(in label: UILabel) throws -> (nearWhite: Int, nearBlack: Int) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: label.bounds.size, format: format).image { context in
            label.layer.render(in: context.cgContext)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        return try pixels.withUnsafeMutableBytes { buffer in
            let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
            let context = try XCTUnwrap(
                CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: bitmapInfo
                )
            )
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            var nearWhite = 0
            var nearBlack = 0
            let bytes = buffer.bindMemory(to: UInt8.self)
            for index in stride(from: 0, to: bytes.count, by: 4) {
                let red = bytes[index]
                let green = bytes[index + 1]
                let blue = bytes[index + 2]
                let alpha = bytes[index + 3]
                guard alpha > 128 else { continue }
                if red > 220, green > 220, blue > 220 {
                    nearWhite += 1
                } else if red < 40, green < 40, blue < 40 {
                    nearBlack += 1
                }
            }
            return (nearWhite, nearBlack)
        }
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

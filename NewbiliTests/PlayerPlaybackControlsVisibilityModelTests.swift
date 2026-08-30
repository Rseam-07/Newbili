import XCTest
@testable import bili

final class PlayerPlaybackControlsVisibilityModelTests: XCTestCase {
    func testPictureInPictureControlIsHiddenWhenUnsupported() {
        let presentation = PlayerNativePictureInPictureControlPresentation(
            isSupported: false,
            isActive: false
        )

        XCTAssertFalse(presentation.isVisible)
    }

    func testPictureInPictureControlAnnouncesActiveState() {
        let inactivePresentation = PlayerNativePictureInPictureControlPresentation(
            isSupported: true,
            isActive: false
        )
        let activePresentation = PlayerNativePictureInPictureControlPresentation(
            isSupported: true,
            isActive: true
        )

        XCTAssertTrue(inactivePresentation.isVisible)
        XCTAssertEqual(inactivePresentation.systemName, "pip.enter")
        XCTAssertEqual(inactivePresentation.accessibilityLabel, "开启画中画")
        XCTAssertEqual(inactivePresentation.accessibilityValue, "已关闭")
        XCTAssertEqual(activePresentation.systemName, "pip.exit")
        XCTAssertEqual(activePresentation.accessibilityLabel, "关闭画中画")
        XCTAssertEqual(activePresentation.accessibilityValue, "已开启")
    }

    @MainActor
    func testAnimatedHideKeepsControlsTouchableDuringFade() async throws {
        let model = PlayerPlaybackControlsVisibilityModel()

        model.hide(animated: true)

        XCTAssertTrue(model.isVisible)
        XCTAssertEqual(model.opacity, 0)
        XCTAssertTrue(model.acceptsHitTesting)

        for _ in 0..<12 where model.isVisible {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertFalse(model.isVisible)
        XCTAssertFalse(model.acceptsHitTesting)
    }

    @MainActor
    func testShowCancelsPendingAnimatedHideRemoval() async throws {
        let model = PlayerPlaybackControlsVisibilityModel()

        model.hide(animated: true)
        model.show(
            scheduleAutoHide: false,
            animated: false,
            showsPlaybackControls: true
        )

        try await Task.sleep(nanoseconds: 420_000_000)

        XCTAssertTrue(model.isVisible)
        XCTAssertEqual(model.opacity, 1)
        XCTAssertTrue(model.acceptsHitTesting)
    }
}

import CoreGraphics
import XCTest
@testable import bili

final class PlayerDoubleTapGesturePolicyTests: XCTestCase {
    func testAcceptsEntireVideoSurfaceForPlaybackToggle() {
        XCTAssertTrue(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 0, width: 400))
        XCTAssertTrue(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 100, width: 400))
        XCTAssertTrue(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 399, width: 400))
        XCTAssertTrue(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 400, width: 400))
    }

    func testIgnoresTapOutsideVideoSurface() {
        XCTAssertFalse(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: -1, width: 400))
        XCTAssertFalse(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 401, width: 400))
    }

    func testIgnoresTapWithoutUsableWidth() {
        XCTAssertFalse(PlayerDoubleTapGesturePolicy.shouldTogglePlayback(locationX: 10, width: 0))
    }
}

import XCTest
@testable import bili

final class RootTabStartupSupportTests: XCTestCase {
    func testMineStartupRouteAliases() {
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "watchlater"), .watchLater)
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "watch-later"), .watchLater)
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "HISTORY"), .history)
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "favorites"), .favorites)
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "messages"), .accountMessages)
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "playback-settings"), .playbackSettings)
        XCTAssertNil(RootTabView.mineOverlayRoute(argumentValue: "unknown"))
    }
}

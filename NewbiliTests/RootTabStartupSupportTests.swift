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
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "settings-search"), .settingsSearch)
        XCTAssertEqual(RootTabView.mineOverlayRoute(argumentValue: "danmaku-settings"), .danmakuSettings)
        XCTAssertEqual(
            RootTabView.mineOverlayRoute(argumentValue: "apple-intelligence-settings"),
            .appleIntelligenceSettings
        )
        XCTAssertNil(RootTabView.mineOverlayRoute(argumentValue: "unknown"))
    }
}

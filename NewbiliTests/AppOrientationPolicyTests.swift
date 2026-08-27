import XCTest
@testable import bili

final class AppOrientationPolicyTests: XCTestCase {
    func testPhoneRootSupportsLandscapeWithoutUpsideDown() {
        XCTAssertEqual(
            AppOrientationPolicy.rootOrientations(for: .phone),
            .allButUpsideDown
        )
    }

    func testPadRootSupportsEveryOrientation() {
        XCTAssertEqual(
            AppOrientationPolicy.rootOrientations(for: .pad),
            .all
        )
    }
}

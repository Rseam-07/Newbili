import XCTest
@testable import bili

final class NavUserInfoTests: XCTestCase {
    func testNavUserDecodesLevelInformation() throws {
        let user = try decode(
            """
            {
              "isLogin": true,
              "face": "https://example.com/avatar.jpg",
              "uname": "测试用户",
              "mid": 123456789,
              "level_info": {
                "current_level": 6,
                "current_min": 28800,
                "current_exp": 40000,
                "next_exp": "--"
              }
            }
            """
        )

        XCTAssertEqual(user.isLogin, true)
        XCTAssertEqual(user.mid, 123456789)
        XCTAssertEqual(user.currentLevel, 6)
        XCTAssertEqual(user.levelInfo?.currentExperience, 40000)
        XCTAssertNil(user.levelInfo?.nextLevelExperience)
        XCTAssertNil(user.levelInfo?.progress)
    }

    func testNavUserAcceptsStringEncodedLoginUIDAndLevelFields() throws {
        let user = try decode(
            """
            {
              "isLogin": "1",
              "uname": "兼容账号",
              "mid": "10086",
              "level_info": {
                "current_level": "5",
                "current_min": "10800",
                "current_exp": "19800",
                "next_exp": "28800"
              }
            }
            """
        )

        XCTAssertEqual(user.isLogin, true)
        XCTAssertEqual(user.mid, 10086)
        XCTAssertEqual(user.currentLevel, 5)
        XCTAssertEqual(user.levelInfo?.progress ?? -1, 0.5, accuracy: 0.0001)
    }

    func testOutOfRangeLevelIsNotDisplayed() throws {
        let user = try decode(
            """
            {
              "isLogin": 1,
              "mid": 1,
              "level_info": {"current_level": 99}
            }
            """
        )

        XCTAssertNil(user.currentLevel)
    }

    private func decode(_ json: String) throws -> NavUserInfo {
        try JSONDecoder().decode(NavUserInfo.self, from: Data(json.utf8))
    }
}

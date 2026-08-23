import Foundation
import XCTest
@testable import bili

final class SponsorBlockServiceTests: XCTestCase {
    func testDecodesAndSortsOnlySkippableSegments() throws {
        let data = try XCTUnwrap(
            """
            [
              {"cid":"168885122","category":"sponsor","actionType":"skip","segment":[30.5,40.0],"UUID":"second","videoDuration":1801,"votes":2},
              {"cid":"168885122","category":"intro","actionType":"skip","segment":[0,12.25],"UUID":"first","videoDuration":1801,"votes":1},
              {"cid":"168885122","category":"poi_highlight","actionType":"poi","segment":[20,20],"UUID":"point","videoDuration":1801,"votes":1},
              {"cid":"168885122","category":"outro","actionType":"mute","segment":[50,60],"UUID":"mute","videoDuration":1801,"votes":1}
            ]
            """.data(using: .utf8)
        )

        let segments = try SponsorBlockService.decodeSegments(from: data)

        XCTAssertEqual(segments.map(\.id), ["first", "second"])
        XCTAssertEqual(segments.map(\.title), ["开场", "赞助"])
        XCTAssertEqual(segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(segments[0].endTime, 12.25, accuracy: 0.001)
    }

    func testMissingActionTypeDefaultsToSkip() throws {
        let data = try XCTUnwrap(
            """
            [{"cid":"1","category":"selfpromo","segment":[2,8],"UUID":"legacy","videoDuration":10,"votes":0}]
            """.data(using: .utf8)
        )

        let segment = try XCTUnwrap(SponsorBlockService.decodeSegments(from: data).first)

        XCTAssertTrue(segment.isSkippable)
        XCTAssertEqual(segment.title, "推广")
    }
}

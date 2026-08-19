import XCTest
@testable import bili

final class PlayerSeekPreviewTests: XCTestCase {
    func testVideoShotTileMatchesReferenceIndexOffset() throws {
        let metadata = VideoShotMetadata(
            imageColumnCount: 2,
            imageRowCount: 2,
            imageColumnSize: 160,
            imageRowSize: 90,
            imageURLs: ["//i0.hdslb.com/bfs/archive/preview.jpg"],
            index: [0, 10, 20, 30, 40]
        )

        let atTenSeconds = try XCTUnwrap(metadata.tile(for: 10))
        let atTwentySeconds = try XCTUnwrap(metadata.tile(for: 20))

        XCTAssertEqual(atTenSeconds.frameIndex, 0)
        XCTAssertEqual(atTenSeconds.column, 0)
        XCTAssertEqual(atTenSeconds.row, 0)
        XCTAssertEqual(atTwentySeconds.frameIndex, 1)
        XCTAssertEqual(atTwentySeconds.column, 1)
        XCTAssertEqual(atTwentySeconds.row, 0)
        XCTAssertEqual(atTwentySeconds.sourceURL.absoluteString, "https://i0.hdslb.com/bfs/archive/preview.jpg")
    }

    func testVideoShotTileMovesToNextSpriteAfterGridCapacity() throws {
        let metadata = VideoShotMetadata(
            imageColumnCount: 2,
            imageRowCount: 2,
            imageColumnSize: 160,
            imageRowSize: 90,
            imageURLs: [
                "https://i0.hdslb.com/bfs/archive/first.jpg",
                "https://i0.hdslb.com/bfs/archive/second.jpg"
            ],
            index: Array(stride(from: 0, through: 90, by: 10))
        )

        let tile = try XCTUnwrap(metadata.tile(for: 60))

        XCTAssertEqual(tile.frameIndex, 5)
        XCTAssertEqual(tile.column, 1)
        XCTAssertEqual(tile.row, 0)
        XCTAssertEqual(tile.sourceURL.lastPathComponent, "second.jpg")
    }

    func testVideoShotTileClampsToLastAvailableFrame() throws {
        let metadata = VideoShotMetadata(
            imageColumnCount: 2,
            imageRowCount: 1,
            imageColumnSize: 160,
            imageRowSize: 90,
            imageURLs: ["https://i0.hdslb.com/bfs/archive/preview.jpg"],
            index: [0, 10, 20, 30, 40]
        )

        let tile = try XCTUnwrap(metadata.tile(for: 10_000))

        XCTAssertEqual(tile.frameIndex, 1)
        XCTAssertEqual(tile.column, 1)
        XCTAssertEqual(tile.row, 0)
    }

    func testPreviewContextRequiresVideoIdentityAndCID() {
        XCTAssertNil(PlayerSeekPreviewContext(bvid: "", cid: 1))
        XCTAssertNil(PlayerSeekPreviewContext(bvid: "BV1test", cid: 0))
        XCTAssertEqual(PlayerSeekPreviewContext(bvid: " BV1test ", cid: 42)?.bvid, "BV1test")
    }
}

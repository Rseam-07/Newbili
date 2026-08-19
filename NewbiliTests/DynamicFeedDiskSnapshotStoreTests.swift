import XCTest
@testable import bili

final class DynamicFeedDiskSnapshotStoreTests: XCTestCase {
    func testSnapshotIsAccountScopedAndExpires() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dynamic-feed-snapshot-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = DynamicFeedDiskSnapshotStore(
            directory: directory,
            freshnessInterval: 0.04,
            maximumSnapshotCount: 2
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let data = Data("{\"code\":0,\"data\":{}}".utf8)
        await store.store(data, for: "account-1")
        let storedData = await store.freshData(for: "account-1")
        let otherAccountData = await store.freshData(for: "account-2")

        XCTAssertEqual(storedData, data)
        XCTAssertNil(otherAccountData)

        try await Task.sleep(nanoseconds: 70_000_000)
        let expiredData = await store.freshData(for: "account-1")
        XCTAssertNil(expiredData)
    }
}

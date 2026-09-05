import Foundation
import Testing
import XCTest
@testable import bili

private nonisolated func replayItem(_ index: Int, time: Double = 1, mode: Int = 1) -> DanmakuItem {
    DanmakuItem(id: "\(index)", time: time, mode: mode, fontSize: 25, color: 0xFFFFFF, text: "弹幕 \(index)")
}

struct PlaybackHotPathTests {
    @Test func denseReplayStopsAfterFillingVisibleBudget() {
        let items = (0..<50_000).map { replayItem($0) }
        var examined = 0
        let result = DanmakuReplayWindow.latestItems(in: items[...], at: 2, limit: 72) { _ in
            examined += 1
            return 8
        }
        #expect(examined == 72)
        #expect(result.map(\.id) == items.suffix(72).map(\.id))
    }

    @Test func replaySkipsExpiredFutureAndUnsupportedItemsWithoutLosingOrder() {
        let items = [
            replayItem(0, time: 0),
            replayItem(1, time: 2),
            replayItem(2, time: 3, mode: 4),
            replayItem(3, time: 4, mode: 7),
            replayItem(4, time: 4.5, mode: 5),
            replayItem(5, time: 6)
        ]
        let result = DanmakuReplayWindow.latestItems(in: items[...], at: 5, limit: 3) {
            $0.isScrolling ? 4 : 1
        }
        #expect(result.map(\.id) == ["1", "4"])
    }

    @Test(arguments: [0, 1, 2, 72])
    func replayMatchesPreviousSelectionForSupportedItems(limit: Int) {
        let items = (0..<1_000).map { replayItem($0, time: Double($0) / 100, mode: $0.isMultiple(of: 3) ? 5 : 1) }
        let duration: (DanmakuItem) -> TimeInterval = { $0.isScrolling ? 8 : 4 }
        let expected = items.filter { 10 - $0.time < duration($0) }.suffix(limit)
        let actual = DanmakuReplayWindow.latestItems(in: items[...], at: 10, limit: limit, displayDuration: duration)
        #expect(actual.map(\.id) == expected.map(\.id))
    }

    @Test func cancelledReadDoesNotReturnAStaleResponseOrPoisonTheNextRead() async throws {
        let coalescer = BiliReadRequestCoalescer()
        let gate = ReadGate()
        let (started, signal) = AsyncStream<Void>.makeStream()
        let request = Task {
            try await coalescer.data(for: "video") {
                signal.yield(())
                signal.finish()
                await gate.wait()
                return Data("old".utf8)
            }
        }
        for await _ in started { break }
        request.cancel()
        await gate.release()
        await #expect(throws: CancellationError.self) { try await request.value }
        let fresh = try await coalescer.data(for: "video") { Data("fresh".utf8) }
        #expect(fresh == Data("fresh".utf8))
    }

    @Test func failedReadIsRemovedAndCanBeRetried() async throws {
        let coalescer = BiliReadRequestCoalescer()
        await #expect(throws: URLError.self) {
            try await coalescer.data(for: "retry") { throw URLError(.notConnectedToInternet) }
        }
        let result = try await coalescer.data(for: "retry") { Data([42]) }
        #expect(result == Data([42]))
    }
}

private actor ReadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

final class DanmakuReplayPerformanceTests: XCTestCase {
    func testBoundedDenseReplay() {
        let items = (0..<50_000).map { replayItem($0) }
        measure {
            let result = DanmakuReplayWindow.latestItems(in: items[...], at: 2, limit: 72) { _ in 8 }
            XCTAssertEqual(result.count, 72)
        }
    }

    func testPreviousDenseReplayBaseline() {
        let items = (0..<50_000).map { replayItem($0) }
        measure {
            var result: [DanmakuItem] = []
            result.reserveCapacity(72)
            for item in items where 2 - item.time < 8 {
                result.append(item)
                if result.count > 72 { result.removeFirst(result.count - 72) }
            }
            XCTAssertEqual(result.count, 72)
        }
    }
}

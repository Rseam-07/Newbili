import XCTest
@testable import bili

@MainActor
final class LiveDanmakuRenderStoreTests: XCTestCase {
    func testConnectionStatePublishesWaitingWithoutRenderedItems() {
        let store = makeStore()

        store.updateConnectionState(phase: .waitingForPackets, error: nil)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.connectionPhase, .waitingForPackets)
        XCTAssertNil(store.connectionError)
    }

    func testConnectionStatePublishesReconnectError() {
        let store = makeStore()

        store.updateConnectionState(phase: .reconnecting, error: "network unavailable")

        XCTAssertEqual(store.connectionPhase, .reconnecting)
        XCTAssertEqual(store.connectionError, "network unavailable")
    }

    func testHistoryItemsPopulateChatWithoutEnteringVideoOverlay() {
        let store = makeStore()
        let item = makeItem(id: "history")

        store.prependHistoryItems([item], retainingLimit: 20)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.chatItems, [item])
        XCTAssertEqual(store.chatItemsRevision, 1)
    }

    func testLiveItemsPopulateChatAndVideoOverlayAfterBatchFlush() {
        let store = makeStore()
        let item = makeItem(id: "live")

        store.appendItems([item], retainingLimit: 20)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.chatItems.isEmpty)

        store.flushPendingLiveItems()

        XCTAssertEqual(store.items, [item])
        XCTAssertEqual(store.chatItems, [item])
        XCTAssertEqual(store.itemsRevision, 1)
        XCTAssertEqual(store.chatItemsRevision, 1)
    }

    func testRenderBatchingCoalescesLiveItemsUntilFlushed() {
        let store = LiveDanmakuRenderStore(
            isEnabled: true,
            settings: .default,
            diagnostics: LiveDanmakuDiagnosticSnapshot(roomID: 1)
        )

        store.appendItems([makeItem(id: "first")], retainingLimit: 20)
        store.appendItems([makeItem(id: "second")], retainingLimit: 20)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.chatItems.isEmpty)

        store.flushPendingLiveItems()

        XCTAssertEqual(store.items.map(\.id), ["first", "second"])
        XCTAssertEqual(store.chatItems.map(\.id), ["first", "second"])
        XCTAssertEqual(store.itemsRevision, 1)
        XCTAssertEqual(store.chatItemsRevision, 1)
    }

    func testRenderedUpdatesStayQueuedUntilRotationFinishes() {
        let store = makeStore()
        let liveItem = makeItem(id: "live-during-rotation")
        let historyItem = makeItem(id: "history-during-rotation")

        store.setRenderedUpdatesDeferred(true)
        store.appendItems([liveItem], retainingLimit: 20)
        store.flushPendingLiveItems()
        store.prependHistoryItems([historyItem], retainingLimit: 20)
        store.updatePlaybackTime(4.2)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.chatItems.isEmpty)
        XCTAssertEqual(store.playbackTime, 0)

        store.setRenderedUpdatesDeferred(false)

        XCTAssertEqual(store.items, [liveItem])
        XCTAssertEqual(store.chatItems, [historyItem, liveItem])
        XCTAssertEqual(store.playbackTime, 4.2, accuracy: 0.001)
    }

    func testLiveItemsFlushAutomaticallyAfterTheBatchWindow() async {
        let store = makeStore()

        store.appendItems([makeItem(id: "automatic")], retainingLimit: 20)
        XCTAssertTrue(store.items.isEmpty)

        try? await Task.sleep(
            nanoseconds: LivePlaybackPolicy.danmakuRenderBatchWindowNanoseconds + 200_000_000
        )

        XCTAssertEqual(store.items.map(\.id), ["automatic"])
        XCTAssertEqual(store.chatItems.map(\.id), ["automatic"])
    }

    func testHistoryFailureIsExposedWithoutChangingTheLiveConnectionState() {
        let store = makeStore()
        store.updateConnectionState(phase: .receiving, error: nil)

        store.recordHistoryFailure("Empty response")

        XCTAssertFalse(store.isLoadingHistory)
        XCTAssertEqual(store.historyError, "Empty response")
        XCTAssertEqual(store.connectionPhase, .receiving)
    }

    func testOverlayStateDefersRenderedItemsUntilRotationFinishes() async {
        let store = makeStore()
        let rotationState = LiveRotationSurfaceAlignmentState()
        let overlayState = LiveDanmakuOverlayState(
            store: store,
            rotationState: rotationState
        )

        overlayState.setUpdatesDeferred(true)
        store.appendItems([makeItem(id: "deferred-overlay")], retainingLimit: 20)
        store.flushPendingLiveItems()
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(overlayState.snapshot.items.isEmpty)
        XCTAssertEqual(rotationState.snapshot.overlayDeferredCount, 1)

        overlayState.setUpdatesDeferred(false)

        XCTAssertEqual(overlayState.snapshot.items.map(\.id), ["deferred-overlay"])
        XCTAssertEqual(rotationState.snapshot.overlayFlushCount, 1)
    }

    func testChatStateDefersListMutationUntilRotationFinishes() async {
        let store = makeStore()
        let rotationState = LiveRotationSurfaceAlignmentState()
        let chatState = LiveRoomChatTimelineState(
            store: store,
            rotationState: rotationState
        )

        chatState.setUpdatesDeferred(true)
        store.appendItems([makeItem(id: "deferred-chat")], retainingLimit: 20)
        store.flushPendingLiveItems()
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(chatState.snapshot.items.isEmpty)
        XCTAssertEqual(rotationState.snapshot.chatDeferredCount, 1)

        chatState.setUpdatesDeferred(false)

        XCTAssertEqual(chatState.snapshot.items.map(\.id), ["deferred-chat"])
        XCTAssertEqual(rotationState.snapshot.chatFlushCount, 1)
    }

    private func makeStore() -> LiveDanmakuRenderStore {
        LiveDanmakuRenderStore(
            isEnabled: true,
            settings: .default,
            diagnostics: LiveDanmakuDiagnosticSnapshot(roomID: 1)
        )
    }

    private func makeItem(id: String) -> DanmakuItem {
        DanmakuItem(
            id: id,
            time: 0,
            mode: 1,
            fontSize: 25,
            color: 0xFFFFFF,
            text: "test"
        )
    }
}

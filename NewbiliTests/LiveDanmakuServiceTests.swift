import XCTest
@testable import bili

final class LiveDanmakuServiceTests: XCTestCase {
    func testAuthenticationBodyMatchesTheLiveSocketProtocol() throws {
        let data = try LiveDanmakuService.authenticationBody(
            roomID: 123,
            uid: 456,
            token: "socket-token"
        )
        let body = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(body.keys),
            ["roomid", "uid", "protover", "platform", "type", "key"]
        )
        XCTAssertEqual((body["roomid"] as? NSNumber)?.intValue, 123)
        XCTAssertEqual((body["uid"] as? NSNumber)?.intValue, 456)
        XCTAssertEqual((body["protover"] as? NSNumber)?.intValue, 3)
        XCTAssertEqual(body["platform"] as? String, "web")
        XCTAssertEqual((body["type"] as? NSNumber)?.intValue, 2)
        XCTAssertEqual(body["key"] as? String, "socket-token")
    }

    func testEndpointDiagnosticsKeepTheLastFailureReason() {
        var snapshot = LiveDanmakuDiagnosticSnapshot(roomID: 1)
        snapshot.apply(
            .endpointAttempt(
                index: 1,
                total: 3,
                endpoint: "wss://chat.example.com:443/sub"
            )
        )
        snapshot.apply(
            .endpointFailed(
                endpoint: "wss://chat.example.com:443/sub",
                error: "鉴权超时"
            )
        )

        XCTAssertEqual(snapshot.endpointAttemptCount, 1)
        XCTAssertEqual(snapshot.endpointFailureCount, 1)
        XCTAssertEqual(snapshot.endpointSummary, "1 尝试 · 1 失败")
        XCTAssertEqual(snapshot.lastEndpointError, "chat.example.com：鉴权超时")
    }

    func testHistoryDiagnosticsDistinguishSuccessfulBackfillFromRealtimeDanmaku() {
        var snapshot = LiveDanmakuDiagnosticSnapshot(roomID: 1)

        snapshot.apply(.historyLoaded(count: 12))

        XCTAssertEqual(snapshot.historyMessageCount, 12)
        XCTAssertNil(snapshot.historyError)
        XCTAssertEqual(snapshot.historySummary, "12 条")
        XCTAssertEqual(snapshot.danmakuCommandCount, 0)
        XCTAssertEqual(snapshot.deliveredItemCount, 0)
    }

    func testRealtimeDanmakuPreservesSenderName() throws {
        let command: [String: Any] = [
            "cmd": "DANMU_MSG:4:0:2:2:2:0",
            "info": [
                [0, 0, 1, 0xFFFFFF] as [Any],
                "你好",
                [123, "弹幕用户"] as [Any]
            ] as [Any]
        ]

        let item = try XCTUnwrap(
            LiveDanmakuService.parsedItems(
                for: command,
                roomID: 1,
                startDate: .distantPast
            ).first
        )

        XCTAssertEqual(item.senderName, "弹幕用户")
        XCTAssertEqual(item.text, "你好")
    }

    func testLiveInteractionEventsKeepSenderSeparateFromBodyText() throws {
        let command: [String: Any] = [
            "cmd": "SEND_GIFT",
            "data": [
                "uname": "送礼用户",
                "giftName": "小花",
                "action": "送出",
                "num": 2
            ]
        ]

        let item = try XCTUnwrap(
            LiveDanmakuService.parsedItems(
                for: command,
                roomID: 1,
                startDate: .distantPast
            ).first
        )

        XCTAssertEqual(item.senderName, "送礼用户")
        XCTAssertEqual(item.text, "送出 2 个 小花")
    }

    func testHistoryMessageAcceptsAlternateNicknameFields() throws {
        let data = Data(#"{"text":"历史消息","uname":"历史用户","timeline":"12:00:00"}"#.utf8)

        let message = try JSONDecoder().decode(LiveDanmakuHistoryMessage.self, from: data)

        XCTAssertEqual(message.nickname, "历史用户")
    }

    func testBrowserCompatibleWebSocketRequestKeepsLiveClientHeaders() throws {
        let endpoint = try XCTUnwrap(URL(string: "wss://chat.example.com:443/sub"))
        let request = LiveDanmakuService.browserCompatibleWebSocketRequest(
            endpoint: endpoint,
            headers: [
                "User-Agent": "Bili Browser",
                "Referer": "https://live.bilibili.com/1",
                "Origin": "https://live.bilibili.com",
                "Cookie": "SESSDATA=test"
            ]
        )

        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Bili Browser")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://live.bilibili.com/1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://live.bilibili.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "SESSDATA=test")
    }

    func testRawWebSocketUpgradeRequestKeepsLiveClientHeaders() throws {
        let endpoint = try XCTUnwrap(URL(string: "wss://chat.example.com:443/sub?room=1"))
        let request = LiveDanmakuRawWebSocket.rawUpgradeRequest(
            endpoint: endpoint,
            headers: [
                "User-Agent": "Bili Browser",
                "Origin": "https://live.bilibili.com",
                "Cookie": "SESSDATA=test"
            ],
            key: "dGhlIHNhbXBsZSBub25jZQ=="
        )
        let requestText = try XCTUnwrap(String(data: request, encoding: .utf8))

        XCTAssertTrue(requestText.hasPrefix("GET /sub?room=1 HTTP/1.1\r\n"))
        XCTAssertTrue(requestText.contains("Host: chat.example.com\r\n"))
        XCTAssertTrue(requestText.contains("Upgrade: websocket\r\n"))
        XCTAssertTrue(requestText.contains("Connection: Upgrade\r\n"))
        XCTAssertTrue(requestText.contains("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"))
        XCTAssertTrue(requestText.contains("Sec-WebSocket-Version: 13\r\n"))
        XCTAssertTrue(requestText.contains("User-Agent: Bili Browser\r\n"))
        XCTAssertTrue(requestText.contains("Origin: https://live.bilibili.com\r\n"))
        XCTAssertTrue(requestText.contains("Cookie: SESSDATA=test\r\n"))
        XCTAssertTrue(requestText.hasSuffix("\r\n\r\n"))
    }

    func testRawWebSocketHandshakeValidatesRFCExample() throws {
        let responseText =
            "HTTP/1.1 101 Switching Protocols\r\n"
                + "Upgrade: websocket\r\n"
                + "Connection: Upgrade\r\n"
                + "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n"
        let response = Data(responseText.utf8)

        XCTAssertNoThrow(
            try LiveDanmakuRawWebSocket.validateHandshakeResponse(
                response,
                expectedKey: "dGhlIHNhbXBsZSBub25jZQ=="
            )
        )
    }
}

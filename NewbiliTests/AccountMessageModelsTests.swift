import XCTest

@testable import bili

final class AccountMessageModelsTests: XCTestCase {
    func testAccountMessageTimesUseNumericMinuteFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 9, hour: 17))!
        let expected = "2026-07-09 17:00"

        XCTAssertEqual(BiliFormatters.accountMessageDateTime(date), expected)

        let session = AccountPrivateMessageSession(
            talkerID: 1,
            actor: AccountMessageActor(mid: 1, name: "用户", avatarURLString: nil),
            preview: "消息",
            timestamp: date,
            unreadCount: 0,
            lastMessageSequence: nil,
            isPinned: false,
            isMuted: false
        )
        let follower = AccountMessageFollower(
            actor: AccountMessageActor(mid: 2, name: "粉丝", avatarURLString: nil),
            sign: nil,
            followedAt: date
        )

        XCTAssertEqual(session.displayTime, expected)
        XCTAssertEqual(follower.displayTime, expected)
    }

    func testUnreadSummaryDecodesAllNotificationKinds() throws {
        let summary = try AccountMessagePayloadDecoder.unreadSummary(
            from: data(
                """
                {
                  "code": 0,
                  "data": { "reply": 7, "at": "3", "like": 12, "sys_msg": 2 }
                }
                """
            ))

        XCTAssertEqual(summary.reply, 7)
        XCTAssertEqual(summary.mention, 3)
        XCTAssertEqual(summary.like, 12)
        XCTAssertEqual(summary.system, 2)
        XCTAssertEqual(summary.total, 24)
        XCTAssertEqual(summary.badgeText(), "24")
    }

    func testPrivateMessageUnreadUsesVisibleSessionCounts() throws {
        let count = try AccountMessagePayloadDecoder.privateMessageUnreadCount(
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "session_list": [
                      { "talker_id": 1, "unread_count": 2 },
                      { "talker_id": 2, "unread_count": "3" },
                      { "talker_id": 3, "unread_count": -1 }
                    ],
                    "follow_unread": 80,
                    "unfollow_unread": 90
                  }
                }
                """
            ))

        XCTAssertEqual(count, 5)
    }

    func testAccountMessageEmotePanelDecodesInlineEmotes() throws {
        let emotes = try AccountMessagePayloadDecoder.accountMessageInlineEmotes(
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "packages": [{
                      "emote": [
                        { "text": "[doge]", "url": "//i0.hdslb.com/emote/doge.png" },
                        { "text": "[赞]", "url": "https://i0.hdslb.com/emote/like.png" }
                      ]
                    }]
                  }
                }
                """
            ))

        XCTAssertEqual(emotes.keys.sorted(), ["[doge]", "[赞]"])
        XCTAssertEqual(emotes["[doge]"]?.displayURL, "https://i0.hdslb.com/emote/doge.png")
    }

    func testReplyPageDecodesCursorAndNativeVideoLink() throws {
        let page = try AccountMessagePayloadDecoder.page(
            category: .reply,
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "cursor": { "is_end": false, "id": 81, "time": 1720000000 },
                    "last_view_at": 1720000050,
                    "items": [{
                      "id": 99,
                      "user": { "mid": 123, "nickname": "测试用户", "avatar": "//i0.hdslb.com/avatar.jpg" },
                      "counts": 1,
                      "reply_time": 1720000100,
                      "item": {
                        "business": "archive",
                        "source_content": "这条回复内容",
                        "target_reply_content": "我的评论",
                        "root_reply_content": "评论根楼",
                        "native_uri": "bilibili://video/BV1TestReply"
                      }
                    }]
                  }
                }
                """
            ),
            pageSize: 20
        )

        let item = try XCTUnwrap(page.items.first)
        XCTAssertEqual(item.title, "测试用户 回复了你")
        XCTAssertEqual(item.body, "这条回复内容")
        XCTAssertEqual(item.contextLines, ["我的评论", "评论根楼"])
        XCTAssertEqual(item.serverID, 99)
        XCTAssertEqual(item.primaryOwner?.mid, 123)
        XCTAssertEqual(item.count, 1)
        XCTAssertEqual(item.routeURL?.absoluteString, "https://www.bilibili.com/video/BV1TestReply")
        XCTAssertEqual(
            page.nextCursor, AccountMessageCursor(id: 81, timestamp: 1_720_000_000, isEnd: false))
        XCTAssertEqual(page.lastViewAt, Date(timeIntervalSince1970: 1_720_000_050))
        XCTAssertTrue(page.hasMore)
    }

    func testReplyPageFallsBackAndDeduplicatesReplyContexts() throws {
        let page = try AccountMessagePayloadDecoder.page(
            category: .reply,
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "cursor": { "is_end": true, "id": 80, "time": 1720000000 },
                    "items": [{
                      "id": 98,
                      "user": { "nickname": "测试用户" },
                      "reply_time": 1720000000,
                      "item": {
                        "target_reply_content": "我的原评论",
                        "root_reply_content": "我的原评论"
                      }
                    }]
                  }
                }
                """
            ),
            pageSize: 20
        )

        let item = try XCTUnwrap(page.items.first)
        XCTAssertEqual(item.body, "我的原评论")
        XCTAssertEqual(item.contextLines, [])
    }

    func testLikePagePreservesLatestItemsAndRemovesDuplicates() throws {
        let page = try AccountMessagePayloadDecoder.page(
            category: .like,
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "latest": {
                      "items": [{
                        "id": 1,
                        "users": [{ "mid": 101, "nickname": "小明", "avatar": "https://example.com/a.jpg" }],
                        "counts": 1,
                        "notice_state": 1,
                        "like_time": 1720000001,
                        "item": { "business": "archive", "title": "最新视频", "native_uri": "bilibili://video/BV1Latest" }
                      }]
                    },
                    "total": {
                      "cursor": { "is_end": false, "id": 2, "time": 1720000000 },
                      "items": [
                        {
                          "id": 1,
                          "users": [{ "nickname": "小明" }],
                          "counts": 1,
                          "like_time": 1720000001,
                          "item": { "business": "archive", "title": "最新视频" }
                        },
                        {
                          "id": 2,
                          "users": [{ "nickname": "小红" }],
                          "counts": 3,
                          "like_time": 1720000000,
                          "item": { "business": "dynamic", "title": "一条动态" }
                        }
                      ]
                    }
                  }
                }
                """
            ),
            pageSize: 1
        )

        XCTAssertEqual(page.items.count, 2)
        XCTAssertTrue(page.items[0].isLatest)
        XCTAssertTrue(page.items[0].isLikeNotificationMuted)
        XCTAssertEqual(page.items[0].primaryOwner?.mid, 101)
        XCTAssertFalse(page.items[1].isLatest)
        XCTAssertEqual(page.items[1].title, "小红 等 3 人赞了你")
        XCTAssertEqual(page.items[1].body, "赞了你的动态")
        XCTAssertTrue(page.hasMore)
    }

    func testLikeDetailDecodesUsersAndPagination() throws {
        let page = try AccountMessagePayloadDecoder.likeDetail(
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "page": { "is_end": false },
                    "card": { "business": "视频", "title": "被点赞的内容" },
                    "items": [{
                      "user": { "mid": 456, "nickname": "点赞用户", "avatar": "//i0.hdslb.com/user.jpg" },
                      "like_time": 1720000200
                    }]
                  }
                }
                """
            ))

        XCTAssertEqual(page.title, "被点赞的内容")
        XCTAssertEqual(page.items.first?.actor.mid, 456)
        XCTAssertEqual(page.items.first?.actor.avatarURLString, "https://i0.hdslb.com/user.jpg")
        XCTAssertEqual(page.nextLastMID, 456)
        XCTAssertTrue(page.hasMore)
    }

    func testSystemPageExtractsWebLinkAndStopsAtShortPage() throws {
        let page = try AccountMessagePayloadDecoder.page(
            category: .system,
            from: data(
                """
                {
                  "code": 0,
                  "data": [{
                    "id": 11,
                    "cursor": 230,
                    "title": "系统消息",
                    "content": "{\\"content\\":\\"通知正文\\",\\"web\\":\\"https://www.bilibili.com/video/BV1System\\"}",
                    "time_at": "2026-07-23 12:00:00"
                  }]
                }
                """
            ),
            pageSize: 20
        )

        let item = try XCTUnwrap(page.items.first)
        XCTAssertEqual(item.body, "通知正文")
        XCTAssertEqual(item.routeURL?.absoluteString, "https://www.bilibili.com/video/BV1System")
        XCTAssertEqual(page.nextCursor?.id, 230)
        XCTAssertFalse(page.hasMore)
    }

    func testFollowersDecodeRecentAccountFollowers() throws {
        let payload = data(
            """
            {
              "code": 0,
              "data": {
                "total": 2,
                "list": [{
                  "mid": 24680,
                  "uname": "新粉丝",
                  "face": "//i0.hdslb.com/follower.jpg",
                  "sign": "个人签名",
                  "mtime": 1720000300
                }]
              }
            }
            """
        )

        let firstPage = try AccountMessagePayloadDecoder.followers(from: payload, page: 1, pageSize: 1)
        let follower = try XCTUnwrap(firstPage.items.first)
        XCTAssertEqual(follower.actor.mid, 24_680)
        XCTAssertEqual(follower.actor.avatarURLString, "https://i0.hdslb.com/follower.jpg")
        XCTAssertEqual(follower.sign, "个人签名")
        XCTAssertEqual(follower.followedAt, Date(timeIntervalSince1970: 1_720_000_300))
        XCTAssertEqual(firstPage.total, 2)
        XCTAssertTrue(firstPage.hasMore)

        let secondPage = try AccountMessagePayloadDecoder.followers(from: payload, page: 2, pageSize: 1)
        XCTAssertFalse(secondPage.hasMore)
    }

    func testSystemRichTextBuildsNativeWebVideoAndDynamicLinks() {
        let segments = AccountMessageRichTextParser.segments(
            from: "查看 #{视频}{bilibili://video/BV1RichText}、https://www.bilibili.com、【av12345】和（67890）"
        )

        XCTAssertEqual(
            segments.map(\.text).joined(),
            "查看 视频、网页链接、【av12345】和查看动态"
        )
        XCTAssertEqual(
            segments.compactMap(\.url).map(\.absoluteString),
            [
                "https://www.bilibili.com/video/BV1RichText",
                "https://www.bilibili.com",
                "https://www.bilibili.com/video/av12345",
                "https://t.bilibili.com/67890",
            ]
        )
    }

    func testPrivateMessageSessionsDecodeUsersPreviewAndUnreadState() throws {
        let sessionData = data(
            """
            {
              "code": 0,
              "data": {
                "session_list": [{
                  "talker_id": 123,
                  "top_ts": 1720000001,
                  "is_dnd": 1,
                  "session_ts": 1720000400,
                  "unread_count": 4,
                  "last_msg": {
                    "sender_uid": 999,
                    "receiver_id": 123,
                    "msg_type": 1,
                    "content": "{\\"content\\":\\"最近一条私信\\"}",
                    "msg_seqno": 88,
                    "timestamp": 1720000400
                  }
                }]
              }
            }
            """
        )
        let userData = data(
            """
            {
              "code": 0,
              "data": {
                "123": {
                  "name": "私信用户",
                  "face": "//i0.hdslb.com/private.jpg"
                }
              }
            }
            """
        )

        XCTAssertEqual(
            try AccountMessagePayloadDecoder.privateMessageTalkerIDs(from: sessionData), [123])
        let actors = try AccountMessagePayloadDecoder.privateMessageActors(from: userData)
        let sessions = try AccountMessagePayloadDecoder.privateMessageSessions(
            from: sessionData,
            actors: actors,
            currentUserMID: 999
        )
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.actor.name, "私信用户")
        XCTAssertEqual(session.actor.avatarURLString, "https://i0.hdslb.com/private.jpg")
        XCTAssertEqual(session.preview, "我：最近一条私信")
        XCTAssertEqual(session.unreadCount, 4)
        XCTAssertEqual(session.lastMessageSequence, 88)
        XCTAssertTrue(session.isPinned)
        XCTAssertTrue(session.isMuted)
    }

    func testPrivateMessagesDecodeBubblesLinksAndHistoryCursor() throws {
        let page = try AccountMessagePayloadDecoder.privateMessages(
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "has_more": true,
                    "messages": [
                      {
                        "sender_uid": 999,
                        "receiver_id": 123,
                        "msg_type": 11,
                        "msg_status": 0,
                        "msg_key": 12001,
                        "content": "{\\"title\\":\\"分享的视频\\",\\"cover\\":\\"//i0.hdslb.com/video.jpg\\",\\"jump_url\\":\\"bilibili://video/BV1Private\\"}",
                        "msg_seqno": 12,
                        "timestamp": 1720000500
                      },
                      {
                        "sender_uid": 123,
                        "receiver_id": 999,
                        "msg_type": 2,
                        "msg_status": 0,
                        "msg_key": "11001",
                        "content": "{\\"url\\":\\"//i0.hdslb.com/image.jpg\\"}",
                        "msg_seqno": 11,
                        "timestamp": 1720000400
                      }
                    ]
                  }
                }
                """
            ),
            currentUserMID: 999
        )

        XCTAssertEqual(page.items.map(\.sequence), [11, 12])
        XCTAssertEqual(page.items[0].text, "[图片]")
        XCTAssertEqual(page.items[0].messageKey, 11_001)
        XCTAssertEqual(page.items[0].imageURLString, "https://i0.hdslb.com/image.jpg")
        XCTAssertFalse(page.items[0].isOutgoing)
        XCTAssertTrue(page.items[0].canReport)
        XCTAssertEqual(page.items[1].text, "分享的视频")
        XCTAssertEqual(page.items[1].messageKey, 12_001)
        XCTAssertEqual(
            page.items[1].routeURL?.absoluteString, "https://www.bilibili.com/video/BV1Private")
        XCTAssertTrue(page.items[1].isOutgoing)
        XCTAssertTrue(page.items[1].canWithdraw)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextEndSequence, 11)
    }

    func testPrivateMessagesFilterWithdrawalEventsAndHideWithdrawnContent() throws {
        let page = try AccountMessagePayloadDecoder.privateMessages(
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "has_more": false,
                    "messages": [
                      {
                        "sender_uid": 999,
                        "receiver_id": 123,
                        "msg_type": 1,
                        "msg_status": 1,
                        "msg_key": 88001,
                        "content": "{\\"content\\":\\"不应继续显示的内容\\"}",
                        "msg_seqno": 88,
                        "timestamp": 1720000500
                      },
                      {
                        "sender_uid": 999,
                        "receiver_id": 123,
                        "msg_type": 5,
                        "msg_status": 0,
                        "msg_key": 99001,
                        "content": "88001",
                        "msg_seqno": 89,
                        "timestamp": 1720000501
                      }
                    ]
                  }
                }
                """
            ),
            currentUserMID: 999
        )

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].messageKey, 88_001)
        XCTAssertEqual(page.items[0].text, "[消息已撤回]")
        XCTAssertNil(page.items[0].imageURLString)
        XCTAssertNil(page.items[0].routeURL)
        XCTAssertTrue(page.items[0].isWithdrawn)
        XCTAssertFalse(page.items[0].canWithdraw)
        XCTAssertFalse(page.items[0].canReport)
    }

    func testPrivateImageUploadDecodesDimensionsAndSize() throws {
        let upload = try AccountMessagePayloadDecoder.privateMessageImageUpload(
            from: data(
                """
                {
                  "code": 0,
                  "data": {
                    "image_url": "//i0.hdslb.com/bfs/im/test.jpg",
                    "image_width": "1920",
                    "image_height": 1080,
                    "img_size": "512.5"
                  }
                }
                """
            ))

        XCTAssertEqual(upload.url, "https://i0.hdslb.com/bfs/im/test.jpg")
        XCTAssertEqual(upload.width, 1_920)
        XCTAssertEqual(upload.height, 1_080)
        XCTAssertEqual(upload.size, 512.5)
    }

    func testPrivateMessagesInferCommonCardLinksAndContent() throws {
        let page = try AccountMessagePayloadDecoder.privateMessages(
            from: data(
                #"""
                {
                  "code": 0,
                  "data": {
                    "has_more": false,
                    "messages": [
                      {
                        "sender_uid": 123,
                        "msg_type": 10,
                        "content": "{\"title\":\"活动通知\",\"text\":\"通知正文\",\"jump_uri\":\"bilibili://space/123\"}",
                        "msg_seqno": 1
                      },
                      {
                        "sender_uid": 123,
                        "msg_type": 11,
                        "content": "{\"title\":\"视频卡片\",\"cover\":\"//i0.hdslb.com/video-card.jpg\",\"bvid\":\"BV1CardTest\"}",
                        "msg_seqno": 2
                      },
                      {
                        "sender_uid": 123,
                        "msg_type": 12,
                        "content": "{\"title\":\"专栏标题\",\"summary\":\"专栏摘要\",\"rid\":987,\"image_urls\":[\"//i0.hdslb.com/article.jpg\"]}",
                        "msg_seqno": 3
                      },
                      {
                        "sender_uid": 123,
                        "msg_type": 14,
                        "content": "{\"source\":\"直播\",\"sourceID\":2468,\"title\":\"正在直播\",\"author\":\"主播\",\"cover\":\"//i0.hdslb.com/live.jpg\"}",
                        "msg_seqno": 4
                      },
                      {
                        "sender_uid": 123,
                        "msg_type": 16,
                        "content": "{\"main_title\":\"视频合集\",\"sub_cards\":[{\"field1\":\"第一条视频\",\"cover_url\":\"//i0.hdslb.com/group.jpg\",\"jump_url\":\"bilibili://video/BV1GroupTest\"}]}",
                        "msg_seqno": 5
                      },
                      {
                        "sender_uid": 123,
                        "msg_type": 18,
                        "content": "{\"content\":\"[{\\\"text\\\":\\\"提示一\\\"},{\\\"text\\\":\\\"提示二\\\"}]\"}",
                        "msg_seqno": 6
                      }
                    ]
                  }
                }
                """#
            ),
            currentUserMID: 999
        )

        XCTAssertEqual(page.items[0].text, "活动通知\n通知正文")
        XCTAssertEqual(page.items[0].routeURL?.absoluteString, "https://space.bilibili.com/123")
        XCTAssertEqual(
            page.items[1].routeURL?.absoluteString, "https://www.bilibili.com/video/BV1CardTest")
        XCTAssertEqual(page.items[2].text, "专栏标题\n专栏摘要")
        XCTAssertEqual(page.items[2].imageURLString, "https://i0.hdslb.com/article.jpg")
        XCTAssertEqual(page.items[2].routeURL?.absoluteString, "https://www.bilibili.com/read/cv987")
        XCTAssertEqual(page.items[3].text, "正在直播\n主播 · 直播")
        XCTAssertEqual(page.items[3].routeURL?.absoluteString, "https://live.bilibili.com/2468")
        XCTAssertEqual(page.items[4].text, "视频合集\n第一条视频")
        XCTAssertEqual(
            page.items[4].routeURL?.absoluteString, "https://www.bilibili.com/video/BV1GroupTest")
        XCTAssertEqual(page.items[5].text, "提示一\n提示二")
    }

    func testNativeLinksResolveToExistingAppRoutes() {
        XCTAssertEqual(
            AccountMessageLinkResolver.resolve(nativeURI: "bilibili://video/av12345", webURLString: nil)?
                .absoluteString,
            "https://www.bilibili.com/video/av12345"
        )
        XCTAssertEqual(
            AccountMessageLinkResolver.resolve(nativeURI: "bilibili://live/12345", webURLString: nil)?
                .absoluteString,
            "https://live.bilibili.com/12345"
        )
        XCTAssertEqual(
            AccountMessageLinkResolver.resolve(nativeURI: "bilibili://space/67890", webURLString: nil)?
                .absoluteString,
            "https://space.bilibili.com/67890"
        )
        XCTAssertEqual(
            AccountMessageLinkResolver.resolve(nativeURI: "bilibili://dynamic/9988", webURLString: nil)?
                .absoluteString,
            "https://t.bilibili.com/9988"
        )
        XCTAssertEqual(
            AccountMessageLinkResolver.resolve(
                nativeURI: "bilibili://pgc/season/ep/246810", webURLString: nil)?.absoluteString,
            "https://www.bilibili.com/bangumi/play/ep246810"
        )
        XCTAssertEqual(
            AccountMessageLinkResolver.resolve(
                nativeURI: "bilibili://article/40679479", webURLString: nil)?.absoluteString,
            "https://www.bilibili.com/read/cv40679479"
        )
        XCTAssertNil(
            AccountMessageLinkResolver.resolve(nativeURI: "bilibili://unsupported/1", webURLString: nil))
    }

    func testNativeCommentDetailLinkResolvesVideoReply() {
        let url = AccountMessageLinkResolver.resolve(
            nativeURI: "bilibili://comment/detail/1/12345/67890?anchor=13579",
            webURLString: nil
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://www.bilibili.com/video/av12345?comment_root_id=67890&comment_secondary_id=13579"
        )
    }

    func testH5CommentLinkResolvesVideoReply() {
        let url = AccountMessageLinkResolver.resolve(
            nativeURI: nil,
            webURLString:
                "https://www.bilibili.com/h5/comment/sub?oid=12345&pageType=1&root=67890&comment_secondary_id=13579"
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://www.bilibili.com/video/av12345?comment_root_id=67890&comment_secondary_id=13579"
        )
    }

    func testNativeCommentTargetsCoverDynamicArticleAndOpus() throws {
        let dynamic = try XCTUnwrap(
            AccountMessageLink(
                nativeURI: "bilibili://comment/detail/11/9988/67890?anchor=13579"
            ).commentTarget)
        XCTAssertEqual(dynamic.type, 11)
        XCTAssertEqual(dynamic.oid, "9988")
        XCTAssertEqual(dynamic.rootID, 67_890)
        XCTAssertEqual(dynamic.secondaryID, 13_579)
        XCTAssertEqual(dynamic.originalURL?.absoluteString, "https://t.bilibili.com/9988")

        let article = try XCTUnwrap(
            AccountMessageLink(
                nativeURI: "bilibili://comment/detail/12/40679479/24680"
            ).commentTarget)
        XCTAssertEqual(article.type, 12)
        XCTAssertEqual(article.originalURL?.absoluteString, "https://www.bilibili.com/read/cv40679479")

        let opus = try XCTUnwrap(
            AccountMessageLink(
                nativeURI: "bilibili://comment/detail/22/112233/445566"
            ).commentTarget)
        XCTAssertEqual(opus.type, 22)
        XCTAssertEqual(opus.originalURL?.absoluteString, "https://www.bilibili.com/opus/112233")
    }

    func testH5CommentTargetKeepsNonVideoCommentType() throws {
        let target = try XCTUnwrap(
            AccountMessageLink(
                webURLString:
                    "https://www.bilibili.com/h5/comment/sub?oid=9988&type=17&root=67890&comment_secondary_id=13579"
            ).commentTarget)

        XCTAssertEqual(target.type, 17)
        XCTAssertEqual(target.oid, "9988")
        XCTAssertEqual(target.rootID, 67_890)
        XCTAssertEqual(target.secondaryID, 13_579)
        XCTAssertEqual(target.originalURL?.absoluteString, "https://t.bilibili.com/9988")
    }

    func testNativeVideoCommentLinkPreservesCommentAnchor() throws {
        let url = AccountMessageLinkResolver.resolve(
            nativeURI: "bilibili://video/12345/?comment_root_id=67890&comment_secondary_id=13579",
            webURLString: nil
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://www.bilibili.com/video/av12345?comment_root_id=67890&comment_secondary_id=13579"
        )
        XCTAssertEqual(
            AppLinkRouter.commentAnchor(for: try XCTUnwrap(url)),
            VideoCommentAnchor(rootID: 67_890, secondaryID: 13_579)
        )
    }

    func testWebVideoLinkKeepsCommentAnchorFromNativeURI() {
        let url = AccountMessageLinkResolver.resolve(
            nativeURI: "bilibili://video/12345/?comment_root_id=67890&comment_secondary_id=13579",
            webURLString: "https://www.bilibili.com/video/av12345"
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://www.bilibili.com/video/av12345?comment_root_id=67890&comment_secondary_id=13579"
        )
    }

    func testCommentPageDecodesRootComment() throws {
        let page = try JSONDecoder().decode(
            CommentPage.self,
            from: data(
                """
                {
                  "root": {
                    "rpid": 67890,
                    "member": { "uname": "楼主" },
                    "content": { "message": "原评论" },
                    "rcount": 1
                  },
                  "replies": [{
                    "rpid": 13579,
                    "root": 67890,
                    "member": { "uname": "回复者" },
                    "content": { "message": "回复内容" }
                  }]
                }
                """
            )
        )

        XCTAssertEqual(page.root?.id, 67_890)
        XCTAssertEqual(page.replies?.first?.id, 13_579)
    }

    func testAppendingPagesDoesNotDuplicateRows() {
        let first = sampleItem(id: "one")
        let second = sampleItem(id: "two")
        XCTAssertEqual(
            AccountMessageCenterViewModel.appendingUnique([first, second], to: [first]).map(\.id),
            ["one", "two"]
        )
    }

    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    private func sampleItem(id: String) -> AccountMessageItem {
        AccountMessageItem(
            id: id,
            serverID: 1,
            category: .reply,
            actors: [],
            count: 1,
            title: "测试",
            body: "测试",
            contextLines: [],
            timestamp: nil,
            timestampText: nil,
            coverURLString: nil,
            link: AccountMessageLink(),
            isLatest: false,
            noticeState: nil
        )
    }
}

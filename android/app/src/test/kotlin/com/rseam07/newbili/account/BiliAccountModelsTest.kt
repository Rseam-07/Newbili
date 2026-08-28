package com.rseam07.newbili.account

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BiliAccountModelsTest {
    @Test
    fun `nav response parses profile level and progress from mixed numeric values`() {
        val profile = BiliAccountJsonParser.parseNavProfile(
            """
            {
              "code": 0,
              "data": {
                "isLogin": 1,
                "face": "https://i0.hdslb.com/avatar.jpg",
                "uname": "测试用户",
                "mid": "123456",
                "level_info": {
                  "current_level": "5",
                  "current_min": 10800,
                  "current_exp": "18000",
                  "next_exp": 28800
                }
              }
            }
            """.trimIndent()
        )

        assertEquals("测试用户", profile.username)
        assertEquals(123456L, profile.mid)
        assertEquals(5, profile.level?.displayLevel)
        assertEquals(0.4f, profile.level?.progress ?: -1f, 0.0001f)
    }

    @Test
    fun `invalid level is not displayed`() {
        val profile = BiliAccountJsonParser.parseNavProfile(
            """{"code":0,"data":{"isLogin":true,"mid":1,"level_info":{"current_level":99}}}"""
        )

        assertNull(profile.level?.displayLevel)
    }

    @Test
    fun `tv poll response resolves cookie and nested access token`() {
        val result = BiliAccountJsonParser.parseQRCodePollResult(
            """
            {
              "code": 0,
              "message": "0",
              "data": {
                "token_info": {"access_token": "access-123"},
                "cookie_info": {
                  "cookies": [
                    {"name": "SESSDATA", "value": "session-value"},
                    {"name": "bili_jct", "value": "csrf-value"},
                    {"name": "DedeUserID", "value": "42"}
                  ]
                }
              }
            }
            """.trimIndent()
        )

        assertEquals(QRCodePollStatus.Confirmed, result.status)
        assertEquals("access-123", result.accessKey)
        assertEquals("session-value", result.cookies["SESSDATA"])
        val session = AccountSession.fromLogin(result.cookies, result.accessKey)
        assertTrue(session.cookieHeader.startsWith("SESSDATA=session-value"))
        assertTrue(session.cookieHeader.contains("bili_jct=csrf-value"))
    }

    @Test
    fun `waiting and expired qr states remain non fatal`() {
        val waiting = BiliAccountJsonParser.parseQRCodePollResult(
            """{"code":86090,"message":"二维码已扫码未确认"}"""
        )
        val expired = BiliAccountJsonParser.parseQRCodePollResult(
            """{"code":86038,"message":"二维码已失效"}"""
        )

        assertEquals(QRCodePollStatus.WaitingForConfirm, waiting.status)
        assertEquals(QRCodePollStatus.Expired, expired.status)
    }
}

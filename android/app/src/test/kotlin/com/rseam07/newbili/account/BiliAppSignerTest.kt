package com.rseam07.newbili.account

import org.junit.Assert.assertEquals
import org.junit.Test

class BiliAppSignerTest {
    @Test
    fun `android tv signature matches deterministic fixture`() {
        val signed = BiliAppSigner.sign(
            parameters = mapOf("local_id" to "0"),
            timestamp = 1_700_000_000L
        )

        assertEquals("4409e2ce8ffd12b8", signed["appkey"])
        assertEquals("1700000000", signed["ts"])
        assertEquals("ebb086c9f52ae7393619a89bdc320e45", signed["sign"])
    }
}

package com.rseam07.newbili.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class GlassCapabilityPolicyTest {
    @Test
    fun `android 12 uses backdrop on capable device`() {
        assertEquals(
            GlassRenderMode.Backdrop,
            GlassCapabilityPolicy.resolve(
                userEnabled = true,
                sdkInt = 31,
                isLowRamDevice = false,
                isPowerSaveMode = false
            )
        )
    }

    @Test
    fun `older low ram power save and opt out use translucent fallback`() {
        val cases = listOf(
            GlassCapabilityPolicy.resolve(true, 30, false, false),
            GlassCapabilityPolicy.resolve(true, 31, true, false),
            GlassCapabilityPolicy.resolve(true, 31, false, true),
            GlassCapabilityPolicy.resolve(false, 37, false, false)
        )

        cases.forEach { assertEquals(GlassRenderMode.Translucent, it) }
    }
}

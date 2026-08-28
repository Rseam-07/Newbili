package com.rseam07.newbili.ui

enum class GlassRenderMode {
    Backdrop,
    Translucent
}

internal object GlassCapabilityPolicy {
    fun resolve(
        userEnabled: Boolean,
        sdkInt: Int,
        isLowRamDevice: Boolean,
        isPowerSaveMode: Boolean
    ): GlassRenderMode = if (
        userEnabled &&
        sdkInt >= MIN_BACKDROP_SDK &&
        !isLowRamDevice &&
        !isPowerSaveMode
    ) {
        GlassRenderMode.Backdrop
    } else {
        GlassRenderMode.Translucent
    }

    private const val MIN_BACKDROP_SDK = 31
}

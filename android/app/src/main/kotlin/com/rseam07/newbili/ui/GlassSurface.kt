package com.rseam07.newbili.ui

import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.kyant.backdrop.Backdrop
import com.kyant.backdrop.backdrops.LayerBackdrop
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.lens
import com.kyant.backdrop.effects.vibrancy

internal fun Modifier.captureForGlass(
    backdrop: LayerBackdrop,
    renderMode: GlassRenderMode
): Modifier = if (renderMode == GlassRenderMode.Backdrop) {
    layerBackdrop(backdrop)
} else {
    this
}

@Composable
internal fun GlassSurface(
    backdrop: Backdrop,
    renderMode: GlassRenderMode,
    isDarkTheme: Boolean,
    shape: Shape,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(0.dp),
    blurRadius: Dp = 8.dp,
    lensRadius: Dp = 20.dp,
    content: @Composable BoxScope.() -> Unit
) {
    val supportsLens = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    val surface = if (renderMode == GlassRenderMode.Backdrop) {
        Modifier.drawBackdrop(
            backdrop = backdrop,
            shape = { shape },
            effects = {
                vibrancy()
                blur(blurRadius.toPx())
                if (supportsLens) {
                    lens(lensRadius.toPx(), (lensRadius + 4.dp).toPx())
                }
            },
            onDrawSurface = {
                drawRect(
                    if (isDarkTheme) Color.White.copy(alpha = 0.10f)
                    else Color.White.copy(alpha = 0.30f)
                )
            }
        )
    } else {
        val fill = if (isDarkTheme) Color(0xEB1A1821) else Color(0xF2FFFFFF)
        val outline = if (isDarkTheme) Color.White.copy(alpha = 0.16f) else Color.Black.copy(alpha = 0.10f)
        Modifier
            .background(fill, shape)
            .border(1.dp, outline, shape)
    }

    Box(
        modifier = modifier.then(surface).padding(contentPadding),
        content = content
    )
}

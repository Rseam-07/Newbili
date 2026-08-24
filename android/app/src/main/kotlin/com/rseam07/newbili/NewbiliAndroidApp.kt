package com.rseam07.newbili

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kyant.backdrop.Backdrop
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.backdrops.rememberLayerBackdrop
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.lens
import com.kyant.backdrop.effects.vibrancy
import com.kyant.shapes.Capsule

private val Accent = Color(0xFFFF4B8B)
private val DarkBackground = Color(0xFF0C0B12)
private val LightBackground = Color(0xFFF8F6FA)

private data class RootDestination(val title: String, val shortTitle: String)

private val RootDestinations = listOf(
    RootDestination("首页", "首页"),
    RootDestination("动态", "动态"),
    RootDestination("我的", "我的"),
    RootDestination("搜索", "搜索")
)

@Composable
fun NewbiliAndroidApp() {
    val isDark = isSystemInDarkTheme()
    val background = if (isDark) DarkBackground else LightBackground
    val foreground = if (isDark) Color.White else Color(0xFF201A2A)
    val backdrop = rememberLayerBackdrop()
    var selectedIndex by rememberSaveable { mutableIntStateOf(0) }
    var dynamicTwoColumns by rememberSaveable { mutableStateOf(false) }

    BoxWithConstraints(Modifier.fillMaxSize().background(background)) {
        val expanded = maxWidth >= 720.dp

        Box(
            Modifier
                .fillMaxSize()
                .layerBackdrop(backdrop)
                .background(
                    Brush.radialGradient(
                        colors = listOf(Accent.copy(alpha = 0.22f), Color.Transparent),
                        center = Offset(120f, 180f),
                        radius = 900f
                    )
                )
        ) {
            RootContent(
                selectedIndex = selectedIndex,
                expanded = expanded,
                dynamicTwoColumns = dynamicTwoColumns,
                onDynamicLayoutChange = { dynamicTwoColumns = it },
                foreground = foreground,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(start = if (expanded) 116.dp else 0.dp)
                    .padding(bottom = if (expanded) 0.dp else 92.dp)
                    .safeDrawingPadding()
            )
        }

        if (expanded) {
            GlassSideRail(
                backdrop = backdrop,
                selectedIndex = selectedIndex,
                onSelected = { selectedIndex = it },
                foreground = foreground,
                modifier = Modifier
                    .padding(18.dp)
                    .safeDrawingPadding()
                    .width(86.dp)
                    .fillMaxHeight()
            )
        } else {
            GlassBottomBar(
                backdrop = backdrop,
                selectedIndex = selectedIndex,
                onSelected = { selectedIndex = it },
                foreground = foreground,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 18.dp, vertical = 10.dp)
                    .navigationBarsPadding()
                    .fillMaxWidth()
                    .height(66.dp)
            )
        }
    }
}

@Composable
private fun RootContent(
    selectedIndex: Int,
    expanded: Boolean,
    dynamicTwoColumns: Boolean,
    onDynamicLayoutChange: (Boolean) -> Unit,
    foreground: Color,
    modifier: Modifier
) {
    when (selectedIndex) {
        0 -> HomeScreen(expanded, foreground, modifier)
        1 -> DynamicScreen(expanded || dynamicTwoColumns, foreground, modifier)
        2 -> SettingsScreen(dynamicTwoColumns, onDynamicLayoutChange, foreground, modifier)
        else -> SearchScreen(foreground, modifier)
    }
}

@Composable
private fun HomeScreen(expanded: Boolean, foreground: Color, modifier: Modifier) {
    val cards = remember {
        listOf(
            "今日精选 · 推荐视频", "番剧新作 · 本周更新", "影视热播 · 高分片单",
            "音乐现场 · 沉浸播放", "知识分区 · 深度内容", "稍后再看 · 继续播放"
        )
    }
    Column(modifier.padding(horizontal = 22.dp, vertical = 18.dp)) {
        Header("首页", "Newbili for Android", foreground)
        Spacer(Modifier.height(18.dp))
        LazyVerticalGrid(
            columns = if (expanded) GridCells.Adaptive(280.dp) else GridCells.Fixed(2),
            contentPadding = PaddingValues(bottom = 28.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(cards) { title ->
                VideoCard(title = title, foreground = foreground)
            }
        }
    }
}

@Composable
private fun DynamicScreen(twoColumns: Boolean, foreground: Color, modifier: Modifier) {
    val updates = remember {
        listOf("关注 UP 更新", "直播中的 UP", "一小时前发布", "今日图文动态", "视频投稿动态", "转发与评论")
    }
    Column(modifier.padding(horizontal = 22.dp, vertical = 18.dp)) {
        Header("动态", if (twoColumns) "双栏" else "单栏", foreground)
        Spacer(Modifier.height(18.dp))
        LazyVerticalGrid(
            columns = if (twoColumns) GridCells.Fixed(2) else GridCells.Fixed(1),
            contentPadding = PaddingValues(bottom = 28.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            items(updates) { title ->
                DynamicCard(title, foreground)
            }
        }
    }
}

@Composable
private fun SettingsScreen(
    dynamicTwoColumns: Boolean,
    onDynamicLayoutChange: (Boolean) -> Unit,
    foreground: Color,
    modifier: Modifier
) {
    Column(modifier.padding(horizontal = 22.dp, vertical = 18.dp)) {
        Header("我的", "Android 适配设置", foreground)
        Spacer(Modifier.height(24.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .background(Color.White.copy(alpha = 0.10f), RoundedCornerShape(24.dp))
                .clickable { onDynamicLayoutChange(!dynamicTwoColumns) }
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                LabelText("动态强制双栏", foreground, 16.sp, FontWeight.SemiBold)
                LabelText("宽屏默认双栏；这里可让窄屏也使用双栏。", foreground.copy(alpha = 0.62f), 13.sp)
            }
            Box(
                Modifier
                    .size(width = 50.dp, height = 30.dp)
                    .background(if (dynamicTwoColumns) Accent else foreground.copy(alpha = 0.18f), CircleShape)
                    .padding(4.dp),
                contentAlignment = if (dynamicTwoColumns) Alignment.CenterEnd else Alignment.CenterStart
            ) {
                Box(Modifier.size(22.dp).background(Color.White, CircleShape))
            }
        }
    }
}

@Composable
private fun SearchScreen(foreground: Color, modifier: Modifier) {
    Column(modifier.padding(horizontal = 22.dp, vertical = 18.dp)) {
        Header("搜索", "视频、番剧、影视与 UP 主", foreground)
        Spacer(Modifier.height(24.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height(58.dp)
                .background(Color.White.copy(alpha = 0.10f), RoundedCornerShape(22.dp))
                .padding(horizontal = 18.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            LabelText("搜索 Newbili", foreground.copy(alpha = 0.55f), 16.sp)
        }
    }
}

@Composable
private fun Header(title: String, subtitle: String, foreground: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        NewbiliMark(Modifier.size(48.dp))
        Spacer(Modifier.width(12.dp))
        Column {
            LabelText(title, foreground, 30.sp, FontWeight.Bold)
            LabelText(subtitle, foreground.copy(alpha = 0.60f), 13.sp)
        }
    }
}

@Composable
private fun VideoCard(title: String, foreground: Color) {
    Column {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(
                    Brush.linearGradient(listOf(Accent.copy(alpha = 0.82f), Color(0xFF5651D8))),
                    RoundedCornerShape(22.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            NewbiliMark(Modifier.size(58.dp))
        }
        Spacer(Modifier.height(8.dp))
        LabelText(title, foreground, 14.sp, FontWeight.SemiBold, maxLines = 2)
        LabelText("Newbili · 12.8 万播放", foreground.copy(alpha = 0.55f), 12.sp)
    }
}

@Composable
private fun DynamicCard(title: String, foreground: Color) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.10f), RoundedCornerShape(24.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(36.dp).background(Accent, CircleShape))
            Spacer(Modifier.width(10.dp))
            LabelText(title, foreground, 15.sp, FontWeight.SemiBold)
        }
        Spacer(Modifier.height(14.dp))
        LabelText("这里承载关注 UP 的视频、图文、转发和互动内容。", foreground.copy(alpha = 0.72f), 14.sp, maxLines = 3)
        Spacer(Modifier.height(12.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .background(foreground.copy(alpha = 0.08f), RoundedCornerShape(18.dp))
        )
    }
}

@Composable
private fun GlassBottomBar(
    backdrop: Backdrop,
    selectedIndex: Int,
    onSelected: (Int) -> Unit,
    foreground: Color,
    modifier: Modifier
) {
    Row(
        modifier.drawBackdrop(
            backdrop = backdrop,
            shape = { Capsule() },
            effects = { vibrancy(); blur(8.dp.toPx()); lens(20.dp.toPx(), 24.dp.toPx()) },
            onDrawSurface = { drawRect(Color(0x6614131A)) }
        ).padding(5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RootDestinations.forEachIndexed { index, destination ->
            NavigationButton(destination.shortTitle, index == selectedIndex, foreground) { onSelected(index) }
        }
    }
}

@Composable
private fun GlassSideRail(
    backdrop: Backdrop,
    selectedIndex: Int,
    onSelected: (Int) -> Unit,
    foreground: Color,
    modifier: Modifier
) {
    Column(
        modifier.drawBackdrop(
            backdrop = backdrop,
            shape = { Capsule() },
            effects = { vibrancy(); blur(10.dp.toPx()); lens(24.dp.toPx(), 30.dp.toPx()) },
            onDrawSurface = { drawRect(Color(0x6614131A)) }
        ).padding(vertical = 12.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        NewbiliMark(Modifier.size(42.dp))
        Spacer(Modifier.height(20.dp))
        RootDestinations.forEachIndexed { index, destination ->
            RailButton(destination.shortTitle, index == selectedIndex, foreground) { onSelected(index) }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun RowScope.NavigationButton(
    title: String,
    selected: Boolean,
    foreground: Color,
    onClick: () -> Unit
) {
    Box(
        Modifier
            .weight(1f)
            .fillMaxHeight()
            .background(if (selected) Color.Black.copy(alpha = 0.34f) else Color.Transparent, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        LabelText(title, if (selected) Accent else foreground.copy(alpha = 0.78f), 13.sp, FontWeight.SemiBold)
    }
}

@Composable
private fun ColumnScope.RailButton(
    title: String,
    selected: Boolean,
    foreground: Color,
    onClick: () -> Unit
) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(54.dp)
            .background(if (selected) Color.Black.copy(alpha = 0.34f) else Color.Transparent, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        LabelText(title, if (selected) Accent else foreground.copy(alpha = 0.78f), 13.sp, FontWeight.SemiBold)
    }
}

@Composable
private fun NewbiliMark(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val stroke = w * 0.055f
        drawLine(Accent, Offset(w * 0.43f, h * 0.28f), Offset(w * 0.32f, h * 0.12f), stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
        drawLine(Accent, Offset(w * 0.57f, h * 0.28f), Offset(w * 0.68f, h * 0.12f), stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
        drawRoundRect(Accent, Offset(w * 0.12f, h * 0.25f), Size(w * 0.76f, h * 0.62f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.18f))
        drawRoundRect(Color(0xFF201A2A), Offset(w * 0.22f, h * 0.36f), Size(w * 0.56f, h * 0.36f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.12f))
        drawCircle(Color(0xFFFF77AB), w * 0.045f, Offset(w * 0.38f, h * 0.53f))
        drawCircle(Color(0xFF87EDFF), w * 0.045f, Offset(w * 0.62f, h * 0.53f))
        drawArc(Color.White, 20f, 140f, false, Offset(w * 0.39f, h * 0.53f), Size(w * 0.22f, h * 0.15f), style = Stroke(stroke * 0.55f))
    }
}

@Composable
private fun LabelText(
    text: String,
    color: Color,
    size: androidx.compose.ui.unit.TextUnit,
    weight: FontWeight = FontWeight.Normal,
    maxLines: Int = 1
) {
    BasicText(
        text = text,
        style = TextStyle(color = color, fontSize = size, fontWeight = weight),
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis
    )
}

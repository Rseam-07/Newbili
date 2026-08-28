package com.rseam07.newbili.account

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.kyant.backdrop.Backdrop
import com.rseam07.newbili.LabelText
import com.rseam07.newbili.ui.GlassRenderMode
import com.rseam07.newbili.ui.GlassSurface
import com.rseam07.newbili.ui.rememberRemoteImageBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
internal fun AccountPanel(
    controller: AccountController,
    backdrop: Backdrop,
    glassRenderMode: GlassRenderMode,
    isDarkTheme: Boolean,
    foreground: Color,
    accent: Color,
    modifier: Modifier = Modifier
) {
    val state = controller.uiState
    GlassSurface(
        backdrop = backdrop,
        renderMode = glassRenderMode,
        isDarkTheme = isDarkTheme,
        shape = RoundedCornerShape(28.dp),
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(18.dp),
        blurRadius = 6.dp,
        lensRadius = 12.dp
    ) {
        if (state.hasSession) {
            LoggedInAccountContent(
                state = state,
                foreground = foreground,
                accent = accent,
                onRefresh = controller::refreshProfile,
                onLogout = controller::logout
            )
        } else {
            LoggedOutAccountContent(
                state = state,
                foreground = foreground,
                accent = accent,
                onStartLogin = controller::startQRCodeLogin,
                onCancelLogin = controller::cancelQRCodeLogin
            )
        }
    }
}

@Composable
private fun LoggedInAccountContent(
    state: AccountUiState,
    foreground: Color,
    accent: Color,
    onRefresh: () -> Unit,
    onLogout: () -> Unit
) {
    var confirmingLogout by remember { mutableStateOf(false) }
    val profile = state.profile
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            RemoteAvatar(
                url = profile?.avatarURL,
                fallbackText = profile?.username?.firstOrNull()?.toString() ?: "B",
                accent = accent,
                modifier = Modifier.size(58.dp)
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LabelText(
                        text = profile?.username ?: if (state.isRefreshing) "正在读取账号" else "已登录",
                        color = foreground,
                        size = 18.sp,
                        weight = FontWeight.Bold,
                        maxLines = 1
                    )
                    profile?.level?.displayLevel?.let { level ->
                        Spacer(Modifier.width(8.dp))
                        LevelBadge(level)
                    }
                }
                LabelText(
                    text = profile?.let { "UID ${it.mid}" } ?: "账号凭证已安全保存",
                    color = foreground.copy(alpha = 0.60f),
                    size = 12.sp
                )
            }
        }

        profile?.level?.let { level ->
            LevelProgress(level = level, foreground = foreground, accent = accent)
        }

        if (state.message.isNotBlank()) {
            LabelText(
                text = state.message,
                color = foreground.copy(alpha = 0.72f),
                size = 13.sp,
                maxLines = 3
            )
        }

        if (confirmingLogout) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                AccountButton(
                    title = "确认退出",
                    foreground = Color.White,
                    background = Color(0xFFD63850),
                    modifier = Modifier.weight(1f),
                    onClick = onLogout
                )
                AccountButton(
                    title = "取消",
                    foreground = foreground,
                    background = foreground.copy(alpha = 0.10f),
                    modifier = Modifier.weight(1f),
                    onClick = { confirmingLogout = false }
                )
            }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                AccountButton(
                    title = if (state.isRefreshing) "刷新中…" else "刷新资料",
                    foreground = foreground,
                    background = accent.copy(alpha = 0.16f),
                    enabled = !state.isRefreshing,
                    modifier = Modifier.weight(1f),
                    onClick = onRefresh
                )
                AccountButton(
                    title = "退出登录",
                    foreground = foreground,
                    background = foreground.copy(alpha = 0.08f),
                    modifier = Modifier.weight(1f),
                    onClick = { confirmingLogout = true }
                )
            }
        }
    }
}

@Composable
private fun LoggedOutAccountContent(
    state: AccountUiState,
    foreground: Color,
    accent: Color,
    onStartLogin: () -> Unit,
    onCancelLogin: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val info = state.qrCodeInfo
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        LabelText(
            text = "登录 Newbili",
            color = foreground,
            size = 20.sp,
            weight = FontWeight.Bold
        )
        LabelText(
            text = if (state.message.isBlank()) {
                "使用 B 站客户端扫码，登录后同步昵称、头像、UID 与账号等级。"
            } else {
                state.message
            },
            color = foreground.copy(alpha = 0.68f),
            size = 13.sp,
            maxLines = 4,
            textAlign = TextAlign.Center
        )

        if (info != null && state.qrCodePhase != QRCodeLoginPhase.Failed) {
            QRCodeImage(
                qrValue = info.url,
                modifier = Modifier
                    .fillMaxWidth(0.72f)
                    .aspectRatio(1f)
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                AccountButton(
                    title = "用 B 站打开",
                    foreground = Color.White,
                    background = accent,
                    modifier = Modifier.weight(1f),
                    onClick = { openBilibiliLogin(context, info.url) }
                )
                AccountButton(
                    title = "复制链接",
                    foreground = foreground,
                    background = foreground.copy(alpha = 0.10f),
                    modifier = Modifier.weight(1f),
                    onClick = { copyLoginURL(context, info.url) }
                )
            }
        }

        when (state.qrCodePhase) {
            QRCodeLoginPhase.Generating -> AccountButton(
                title = "正在生成…",
                foreground = foreground.copy(alpha = 0.62f),
                background = foreground.copy(alpha = 0.08f),
                enabled = false,
                modifier = Modifier.fillMaxWidth(),
                onClick = {}
            )

            QRCodeLoginPhase.WaitingForScan,
            QRCodeLoginPhase.WaitingForConfirm -> AccountButton(
                title = "取消扫码",
                foreground = foreground,
                background = foreground.copy(alpha = 0.08f),
                modifier = Modifier.fillMaxWidth(),
                onClick = onCancelLogin
            )

            QRCodeLoginPhase.Expired,
            QRCodeLoginPhase.Failed -> AccountButton(
                title = "重新生成二维码",
                foreground = Color.White,
                background = accent,
                modifier = Modifier.fillMaxWidth(),
                onClick = onStartLogin
            )

            QRCodeLoginPhase.Idle,
            QRCodeLoginPhase.Succeeded -> AccountButton(
                title = "App 扫码登录",
                foreground = Color.White,
                background = accent,
                modifier = Modifier.fillMaxWidth(),
                onClick = onStartLogin
            )
        }
    }
}

@Composable
private fun LevelBadge(level: Int) {
    val color = when (level) {
        6 -> Color(0xFFFF4B8B)
        5 -> Color(0xFFFF8A3D)
        4 -> Color(0xFFE4B52F)
        3 -> Color(0xFF35A865)
        2 -> Color(0xFF4388E8)
        else -> Color(0xFF8A8392)
    }
    Box(
        Modifier
            .background(color.copy(alpha = 0.15f), RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        LabelText("LV$level", color, 11.sp, FontWeight.Bold)
    }
}

@Composable
private fun LevelProgress(level: AccountLevel, foreground: Color, accent: Color) {
    val progress = level.progress
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row {
            LabelText("账号经验", foreground.copy(alpha = 0.72f), 12.sp, FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            val experience = level.currentExperience
            val next = level.nextLevelExperience
            LabelText(
                text = when {
                    level.displayLevel == 6 -> "已达最高等级"
                    experience != null && next != null -> "$experience / $next"
                    else -> "经验数据暂不可用"
                },
                color = foreground.copy(alpha = 0.58f),
                size = 11.sp
            )
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(8.dp)
                .background(foreground.copy(alpha = 0.10f), RoundedCornerShape(999.dp))
        ) {
            if (progress != null) {
                Box(
                    Modifier
                        .fillMaxWidth(progress)
                        .height(8.dp)
                        .background(accent, RoundedCornerShape(999.dp))
                )
            }
        }
    }
}

@Composable
private fun AccountButton(
    title: String,
    foreground: Color,
    background: Color,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Box(
        modifier
            .height(46.dp)
            .background(background, RoundedCornerShape(16.dp))
            .semantics { role = Role.Button }
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        LabelText(title, foreground, 13.sp, FontWeight.SemiBold)
    }
}

@Composable
private fun QRCodeImage(qrValue: String, modifier: Modifier = Modifier) {
    val bitmap by produceState<ImageBitmap?>(initialValue = null, key1 = qrValue) {
        value = withContext(Dispatchers.Default) { renderQRCode(qrValue) }
    }
    Box(
        modifier.background(Color.White, RoundedCornerShape(18.dp)).padding(12.dp),
        contentAlignment = Alignment.Center
    ) {
        bitmap?.let {
            Image(
                bitmap = it,
                contentDescription = "B站扫码登录二维码",
                modifier = Modifier.fillMaxWidth().aspectRatio(1f)
            )
        } ?: LabelText("正在绘制二维码", Color(0xFF4A4550), 12.sp)
    }
}

private fun renderQRCode(value: String): ImageBitmap {
    val matrix = QRCodeWriter().encode(
        value,
        BarcodeFormat.QR_CODE,
        QR_CODE_SIZE,
        QR_CODE_SIZE,
        mapOf(
            EncodeHintType.MARGIN to 1,
            EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M
        )
    )
    val pixels = IntArray(QR_CODE_SIZE * QR_CODE_SIZE)
    for (y in 0 until QR_CODE_SIZE) {
        for (x in 0 until QR_CODE_SIZE) {
            pixels[y * QR_CODE_SIZE + x] = if (matrix[x, y]) 0xFF111111.toInt() else 0xFFFFFFFF.toInt()
        }
    }
    return Bitmap.createBitmap(pixels, QR_CODE_SIZE, QR_CODE_SIZE, Bitmap.Config.ARGB_8888).asImageBitmap()
}

@Composable
private fun RemoteAvatar(
    url: String?,
    fallbackText: String,
    accent: Color,
    modifier: Modifier = Modifier
) {
    val bitmap = rememberRemoteImageBitmap(
        url = url,
        targetWidth = AVATAR_SIZE,
        targetHeight = AVATAR_SIZE
    )
    Box(
        modifier.clip(CircleShape).background(accent.copy(alpha = 0.18f)),
        contentAlignment = Alignment.Center
    ) {
        bitmap?.let {
            Image(
                bitmap = it,
                contentDescription = "账号头像",
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop
            )
        } ?: LabelText(fallbackText, accent, 22.sp, FontWeight.Bold)
    }
}

private fun openBilibiliLogin(context: Context, url: String) {
    val deepLink = Uri.Builder()
        .scheme("bilibili")
        .authority("browser")
        .appendQueryParameter("url", url)
        .build()
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, deepLink))
    } catch (_: ActivityNotFoundException) {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }
}

private fun copyLoginURL(context: Context, url: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText("Newbili B站登录链接", url))
}

private const val QR_CODE_SIZE = 640
private val AVATAR_SIZE = 58.dp

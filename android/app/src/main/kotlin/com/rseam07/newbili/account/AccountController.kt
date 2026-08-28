package com.rseam07.newbili.account

import android.content.Context
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class QRCodeLoginPhase {
    Idle,
    Generating,
    WaitingForScan,
    WaitingForConfirm,
    Expired,
    Failed,
    Succeeded
}

@Immutable
data class AccountUiState(
    val hasSession: Boolean = false,
    val profile: AccountProfile? = null,
    val isRefreshing: Boolean = false,
    val qrCodeInfo: QRCodeLoginInfo? = null,
    val qrCodePhase: QRCodeLoginPhase = QRCodeLoginPhase.Idle,
    val message: String = ""
)

@Stable
internal class AccountController(
    context: Context,
    private val scope: CoroutineScope,
    private val remote: BiliAccountRemote = BiliAccountApi(),
    private val sessionStore: AccountSessionStore = AccountSessionStore(context)
) {
    var uiState by mutableStateOf(AccountUiState())
        private set

    private var session: AccountSession? = null
    private var initialized = false
    private var refreshJob: Job? = null
    private var qrCodeJob: Job? = null

    fun initialize() {
        if (initialized) return
        initialized = true
        refreshJob = scope.launch {
            val restored = withContext(Dispatchers.IO) { sessionStore.load() }
            session = restored
            updateState { it.copy(hasSession = restored != null) }
            if (restored != null) refreshProfileNow(restored)
        }
    }

    fun refreshProfile() {
        val current = session ?: return
        refreshJob?.cancel()
        refreshJob = scope.launch { refreshProfileNow(current) }
    }

    fun startQRCodeLogin() {
        qrCodeJob?.cancel()
        qrCodeJob = scope.launch {
            updateState {
                it.copy(
                    qrCodeInfo = null,
                    qrCodePhase = QRCodeLoginPhase.Generating,
                    message = "正在生成登录二维码"
                )
            }
            try {
                val info = withContext(Dispatchers.IO) { remote.generateQRCodeLogin() }
                updateState {
                    it.copy(
                        qrCodeInfo = info,
                        qrCodePhase = QRCodeLoginPhase.WaitingForScan,
                        message = "请使用 B 站客户端扫码"
                    )
                }
                pollQRCode(info)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                updateState {
                    it.copy(
                        qrCodePhase = QRCodeLoginPhase.Failed,
                        message = error.userFacingMessage("二维码登录失败")
                    )
                }
            }
        }
    }

    fun cancelQRCodeLogin() {
        qrCodeJob?.cancel()
        qrCodeJob = null
        updateState {
            it.copy(
                qrCodeInfo = null,
                qrCodePhase = QRCodeLoginPhase.Idle,
                message = ""
            )
        }
    }

    fun logout() {
        refreshJob?.cancel()
        qrCodeJob?.cancel()
        sessionStore.clear()
        session = null
        uiState = AccountUiState(message = "已退出登录")
    }

    fun dispose() {
        refreshJob?.cancel()
        qrCodeJob?.cancel()
    }

    private suspend fun pollQRCode(info: QRCodeLoginInfo) {
        while (scope.isActive) {
            delay(POLL_INTERVAL_MILLIS)
            val result = try {
                withContext(Dispatchers.IO) { remote.pollQRCodeLogin(info.authCode) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: IOException) {
                updateState { state ->
                    state.copy(message = "网络暂时不可用，仍在自动重试")
                }
                continue
            }
            when (result.status) {
                QRCodePollStatus.WaitingForScan -> updateState {
                    it.copy(
                        qrCodePhase = QRCodeLoginPhase.WaitingForScan,
                        message = result.message
                    )
                }

                QRCodePollStatus.WaitingForConfirm -> updateState {
                    it.copy(
                        qrCodePhase = QRCodeLoginPhase.WaitingForConfirm,
                        message = result.message
                    )
                }

                QRCodePollStatus.Expired -> {
                    updateState {
                        it.copy(
                            qrCodePhase = QRCodeLoginPhase.Expired,
                            message = result.message
                        )
                    }
                    return
                }

                QRCodePollStatus.Confirmed -> {
                    completeLogin(result)
                    return
                }

                QRCodePollStatus.Unknown -> updateState {
                    it.copy(message = result.message)
                }
            }
        }
    }

    private suspend fun completeLogin(result: QRCodePollResult) {
        try {
            val newSession = AccountSession.fromLogin(result.cookies, result.accessKey)
            withContext(Dispatchers.IO) { sessionStore.save(newSession) }
            session = newSession
            updateState {
                it.copy(
                    hasSession = true,
                    qrCodePhase = QRCodeLoginPhase.Succeeded,
                    message = if (newSession.accessKey == null) {
                        "扫码登录成功，但移动端凭证缺失"
                    } else {
                        "扫码登录成功"
                    }
                )
            }
            refreshProfileNow(newSession, keepSuccessMessage = true)
        } catch (error: Exception) {
            updateState {
                it.copy(
                    qrCodePhase = QRCodeLoginPhase.Failed,
                    message = error.userFacingMessage("登录凭证保存失败")
                )
            }
        }
    }

    private suspend fun refreshProfileNow(
        current: AccountSession,
        keepSuccessMessage: Boolean = false
    ) {
        updateState { it.copy(isRefreshing = true) }
        try {
            val profile = withContext(Dispatchers.IO) { remote.fetchProfile(current) }
            updateState {
                it.copy(
                    hasSession = true,
                    profile = profile,
                    isRefreshing = false,
                    message = if (keepSuccessMessage) it.message else ""
                )
            }
        } catch (error: BiliAccountApiException) {
            if (error.isAuthenticationFailure) {
                withContext(Dispatchers.IO) { sessionStore.clear() }
                session = null
                uiState = AccountUiState(message = error.message)
            } else {
                updateState {
                    it.copy(
                        isRefreshing = false,
                        message = error.userFacingMessage("账号资料刷新失败")
                    )
                }
            }
        } catch (error: Exception) {
            updateState {
                it.copy(
                    isRefreshing = false,
                    message = error.userFacingMessage("账号资料刷新失败")
                )
            }
        }
    }

    private inline fun updateState(transform: (AccountUiState) -> AccountUiState) {
        val next = transform(uiState)
        if (next != uiState) uiState = next
    }

    private fun Throwable.userFacingMessage(fallback: String): String =
        message?.trim()?.takeIf(String::isNotEmpty) ?: fallback

    private companion object {
        const val POLL_INTERVAL_MILLIS = 1_000L
    }
}

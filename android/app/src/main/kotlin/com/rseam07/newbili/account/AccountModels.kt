package com.rseam07.newbili.account

import org.json.JSONObject

data class AccountLevel(
    val currentLevel: Int?,
    val currentMinimumExperience: Long?,
    val currentExperience: Long?,
    val nextLevelExperience: Long?
) {
    val displayLevel: Int?
        get() = currentLevel?.takeIf { it in 0..6 }

    val progress: Float?
        get() {
            if (displayLevel == 6) return 1f
            val minimum = currentMinimumExperience ?: return null
            val current = currentExperience ?: return null
            val next = nextLevelExperience ?: return null
            if (next <= minimum) return null
            return ((current - minimum).toFloat() / (next - minimum).toFloat()).coerceIn(0f, 1f)
        }
}

data class AccountProfile(
    val username: String,
    val avatarURL: String?,
    val mid: Long,
    val level: AccountLevel?
)

data class QRCodeLoginInfo(
    val url: String,
    val authCode: String
)

enum class QRCodePollStatus {
    WaitingForScan,
    WaitingForConfirm,
    Confirmed,
    Expired,
    Unknown
}

data class QRCodePollResult(
    val status: QRCodePollStatus,
    val message: String,
    val cookies: Map<String, String> = emptyMap(),
    val accessKey: String? = null,
    val rawCode: Int = 0
)

data class AccountSession(
    val cookieHeader: String,
    val accessKey: String?
) {
    companion object {
        private val cookieOrder = listOf(
            "SESSDATA",
            "bili_jct",
            "DedeUserID",
            "DedeUserID__ckMd5",
            "sid",
            "buvid3",
            "buvid4",
            "buvid_fp",
            "b_nut"
        )

        fun fromLogin(cookies: Map<String, String>, accessKey: String?): AccountSession {
            val normalized = cookies.mapValues { (_, value) -> sanitizeCookieValue(value) }
            require(normalized["SESSDATA"]?.isNotBlank() == true) {
                "登录成功但未返回 SESSDATA"
            }
            val header = cookieOrder.mapNotNull { name ->
                normalized[name]
                    ?.takeIf(String::isNotBlank)
                    ?.let { value -> "$name=$value" }
            }.joinToString("; ")
            return AccountSession(
                cookieHeader = header,
                accessKey = accessKey?.trim()?.takeIf(String::isNotEmpty)
            )
        }

        private fun sanitizeCookieValue(value: String): String =
            value.trim().replace("\r", "").replace("\n", "").substringBefore(';')
    }
}

internal object BiliAccountJsonParser {
    fun parseQRCodeLoginInfo(json: String): QRCodeLoginInfo {
        val data = requireData(JSONObject(json))
        val url = data.requiredString("url")
        val authCode = data.requiredString("auth_code")
        return QRCodeLoginInfo(url = url, authCode = authCode)
    }

    fun parseQRCodePollResult(json: String): QRCodePollResult {
        val root = JSONObject(json)
        val code = root.flexibleInt("code") ?: Int.MIN_VALUE
        val message = root.optString("message").ifBlank { root.optString("msg") }
        val status = when (code) {
            0 -> QRCodePollStatus.Confirmed
            86038 -> QRCodePollStatus.Expired
            86090 -> QRCodePollStatus.WaitingForConfirm
            86039, 86101 -> QRCodePollStatus.WaitingForScan
            else -> QRCodePollStatus.Unknown
        }
        if (status != QRCodePollStatus.Confirmed) {
            return QRCodePollResult(
                status = status,
                message = message.ifBlank { defaultPollMessage(status, code) },
                rawCode = code
            )
        }

        val data = root.optJSONObject("data")
            ?: throw BiliAccountApiException(code, "登录成功但没有返回凭证")
        val cookies = buildMap {
            val values = data.optJSONObject("cookie_info")?.optJSONArray("cookies")
            if (values != null) {
                for (index in 0 until values.length()) {
                    val cookie = values.optJSONObject(index) ?: continue
                    val name = cookie.optString("name").trim()
                    val value = cookie.optString("value").trim()
                    if (name.isNotEmpty() && value.isNotEmpty()) put(name, value)
                }
            }
        }
        val accessKey = sequenceOf(
            data.optString("access_token"),
            data.optJSONObject("token_info")?.optString("access_token")
        ).filterNotNull().map(String::trim).firstOrNull(String::isNotEmpty)
        return QRCodePollResult(
            status = status,
            message = message.ifBlank { "扫码登录成功" },
            cookies = cookies,
            accessKey = accessKey,
            rawCode = code
        )
    }

    fun parseNavProfile(json: String): AccountProfile {
        val data = requireData(JSONObject(json))
        if (!data.flexibleBoolean("isLogin")) {
            throw BiliAccountApiException(-101, "登录已失效，请重新登录")
        }
        val mid = data.flexibleLong("mid")
            ?: throw BiliAccountApiException(-1, "账号资料缺少 UID")
        val levelData = data.optJSONObject("level_info")
        val level = levelData?.let {
            AccountLevel(
                currentLevel = it.flexibleInt("current_level"),
                currentMinimumExperience = it.flexibleLong("current_min"),
                currentExperience = it.flexibleLong("current_exp"),
                nextLevelExperience = it.flexibleLong("next_exp")
            )
        }
        return AccountProfile(
            username = data.optString("uname").ifBlank { "B站用户" },
            avatarURL = data.optString("face").trim().takeIf(String::isNotEmpty),
            mid = mid,
            level = level
        )
    }

    private fun requireData(root: JSONObject): JSONObject {
        val code = root.flexibleInt("code") ?: Int.MIN_VALUE
        if (code != 0) {
            val message = root.optString("message").ifBlank { root.optString("msg") }
            throw BiliAccountApiException(code, message.ifBlank { "B站接口返回错误 $code" })
        }
        return root.optJSONObject("data")
            ?: throw BiliAccountApiException(code, "B站接口没有返回数据")
    }

    private fun JSONObject.requiredString(name: String): String =
        optString(name).trim().takeIf(String::isNotEmpty)
            ?: throw BiliAccountApiException(-1, "B站接口缺少 $name")

    private fun JSONObject.flexibleInt(name: String): Int? = when (val value = opt(name)) {
        is Number -> value.toInt()
        is String -> value.toIntOrNull()
        else -> null
    }

    private fun JSONObject.flexibleLong(name: String): Long? = when (val value = opt(name)) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull()
        else -> null
    }

    private fun JSONObject.flexibleBoolean(name: String): Boolean = when (val value = opt(name)) {
        is Boolean -> value
        is Number -> value.toInt() != 0
        is String -> value == "1" || value.equals("true", ignoreCase = true)
        else -> false
    }

    private fun defaultPollMessage(status: QRCodePollStatus, code: Int): String = when (status) {
        QRCodePollStatus.WaitingForScan -> "请使用 B 站客户端扫码"
        QRCodePollStatus.WaitingForConfirm -> "已扫码，请在手机上确认"
        QRCodePollStatus.Expired -> "二维码已过期"
        QRCodePollStatus.Confirmed -> "扫码登录成功"
        QRCodePollStatus.Unknown -> "等待登录状态（$code）"
    }
}

class BiliAccountApiException(
    val code: Int,
    override val message: String
) : Exception(message) {
    val isAuthenticationFailure: Boolean
        get() = code == -101 || code == -111
}

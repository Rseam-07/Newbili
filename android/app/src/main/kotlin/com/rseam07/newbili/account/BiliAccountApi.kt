package com.rseam07.newbili.account

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import kotlin.time.Duration.Companion.seconds

internal interface BiliAccountRemote {
    suspend fun generateQRCodeLogin(): QRCodeLoginInfo
    suspend fun pollQRCodeLogin(authCode: String): QRCodePollResult
    suspend fun fetchProfile(session: AccountSession): AccountProfile
}

internal class BiliAccountApi : BiliAccountRemote {
    override suspend fun generateQRCodeLogin(): QRCodeLoginInfo {
        val fields = BiliAppSigner.sign(mapOf("local_id" to "0"))
        val response = request(
            url = "$PASSPORT_BASE/x/passport-tv-login/qrcode/auth_code?${BiliAppSigner.query(fields)}",
            method = "POST",
            headers = appHeaders()
        )
        return BiliAccountJsonParser.parseQRCodeLoginInfo(response)
    }

    override suspend fun pollQRCodeLogin(authCode: String): QRCodePollResult {
        val fields = BiliAppSigner.sign(
            mapOf(
                "auth_code" to authCode,
                "local_id" to "0"
            )
        )
        val response = request(
            url = "$PASSPORT_BASE/x/passport-tv-login/qrcode/poll?${BiliAppSigner.query(fields)}",
            method = "POST",
            headers = appHeaders()
        )
        return BiliAccountJsonParser.parseQRCodePollResult(response)
    }

    override suspend fun fetchProfile(session: AccountSession): AccountProfile {
        val response = request(
            url = "$API_BASE/x/web-interface/nav",
            method = "GET",
            headers = mapOf(
                "Accept" to "application/json",
                "Cookie" to session.cookieHeader,
                "Referer" to "https://www.bilibili.com/",
                "User-Agent" to WEB_USER_AGENT
            )
        )
        return BiliAccountJsonParser.parseNavProfile(response)
    }

    private fun appHeaders(): Map<String, String> = mapOf(
        "Accept" to "application/json",
        "Content-Type" to "application/x-www-form-urlencoded; charset=utf-8",
        "Referer" to "https://www.bilibili.com/",
        "User-Agent" to BiliAppSigner.userAgent,
        "app-key" to BiliAppSigner.appKeyHeader,
        "env" to "prod",
        "bili-http-engine" to "cronet"
    )

    private fun request(
        url: String,
        method: String,
        headers: Map<String, String>
    ): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = NETWORK_TIMEOUT.inWholeMilliseconds.toInt()
            readTimeout = NETWORK_TIMEOUT.inWholeMilliseconds.toInt()
            useCaches = false
            instanceFollowRedirects = true
            headers.forEach { (name, value) -> setRequestProperty(name, value) }
            if (method == "POST") {
                doOutput = true
                setFixedLengthStreamingMode(0)
            }
        }
        return try {
            if (method == "POST") connection.outputStream.use { }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                throw IOException("B站接口 HTTP $status${body.takeIf(String::isNotBlank)?.let { ": ${it.take(160)}" }.orEmpty()}")
            }
            if (body.isBlank()) throw IOException("B站接口返回空数据")
            body
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val PASSPORT_BASE = "https://passport.bilibili.com"
        const val API_BASE = "https://api.bilibili.com"
        const val WEB_USER_AGENT =
            "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
        val NETWORK_TIMEOUT = 15.seconds
    }
}

internal object BiliAppSigner {
    const val appKeyHeader = "android_tv_yst"
    const val userAgent =
        "Mozilla/5.0 BiliDroid/1.44.0 (bbcallen@gmail.com) os/android model/android_tv_yst mobi_app/android_tv_yst build/144000 channel/master innerVer/144000 osVer/12 network/2"
    private const val appKey = "4409e2ce8ffd12b8"
    private const val appSecret = "59b43e04ad6965f34319062b478f83dd"

    fun sign(
        parameters: Map<String, String>,
        timestamp: Long = System.currentTimeMillis() / 1_000
    ): Map<String, String> {
        val unsigned = parameters + mapOf(
            "appkey" to appKey,
            "ts" to timestamp.toString()
        )
        val signature = md5(query(unsigned) + appSecret)
        return unsigned + ("sign" to signature)
    }

    fun query(parameters: Map<String, String>): String = parameters
        .toSortedMap()
        .entries
        .joinToString("&") { (name, value) -> "${encode(name)}=${encode(value)}" }

    private fun encode(value: String): String = URLEncoder
        .encode(value, StandardCharsets.UTF_8.name())
        .replace("+", "%20")
        .replace("%7E", "~")

    private fun md5(value: String): String = MessageDigest
        .getInstance("MD5")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
}

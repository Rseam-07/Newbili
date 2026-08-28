package com.rseam07.newbili.account

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class AccountSessionStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    @Synchronized
    fun load(): AccountSession? {
        val encoded = preferences.getString(SESSION_KEY, null) ?: return null
        return runCatching {
            val parts = encoded.split(':', limit = 2)
            require(parts.size == 2)
            val iv = Base64.decode(parts[0], Base64.NO_WRAP)
            val encrypted = Base64.decode(parts[1], Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, encryptionKey(), GCMParameterSpec(TAG_LENGTH_BITS, iv))
                updateAAD(SESSION_AAD)
            }
            val payload = JSONObject(String(cipher.doFinal(encrypted), Charsets.UTF_8))
            val session = AccountSession(
                cookieHeader = payload.getString("cookie_header"),
                accessKey = payload.optString("access_key").trim().takeIf(String::isNotEmpty)
            )
            require(session.cookieHeader.contains("SESSDATA="))
            session
        }.getOrElse {
            preferences.edit().remove(SESSION_KEY).apply()
            null
        }
    }

    @Synchronized
    fun save(session: AccountSession) {
        require(session.cookieHeader.contains("SESSDATA="))
        val payload = JSONObject()
            .put("cookie_header", session.cookieHeader)
            .put("access_key", session.accessKey.orEmpty())
            .toString()
            .toByteArray(Charsets.UTF_8)
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, encryptionKey())
            updateAAD(SESSION_AAD)
        }
        val encrypted = cipher.doFinal(payload)
        val encoded = listOf(cipher.iv, encrypted)
            .joinToString(":") { bytes -> Base64.encodeToString(bytes, Base64.NO_WRAP) }
        check(preferences.edit().putString(SESSION_KEY, encoded).commit()) {
            "无法持久化登录凭证"
        }
    }

    @Synchronized
    fun clear() {
        preferences.edit().remove(SESSION_KEY).apply()
    }

    private fun encryptionKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                    .build()
            )
            generateKey()
        }
    }

    private companion object {
        const val PREFERENCES_NAME = "newbili_account_session"
        const val SESSION_KEY = "encrypted_session_v1"
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val KEY_ALIAS = "newbili_account_session_aes_v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val TAG_LENGTH_BITS = 128
        val SESSION_AAD = "Newbili Android account session v1".toByteArray(Charsets.UTF_8)
    }
}

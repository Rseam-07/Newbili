package com.example.piliplus

import android.content.Context
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Reads the encrypted session written by Newbili's retired Compose shell. */
internal object LegacyAccountMigration {
    private const val preferencesName = "newbili_account_session"
    private const val sessionKey = "encrypted_session_v1"
    private const val keyAlias = "newbili_account_session_aes_v1"
    private const val transformation = "AES/GCM/NoPadding"
    private const val tagLengthBits = 128
    private val sessionAad = "Newbili Android account session v1".toByteArray(Charsets.UTF_8)

    fun peek(context: Context): Map<String, String?>? = runCatching {
        val preferences = context.applicationContext.getSharedPreferences(
            preferencesName,
            Context.MODE_PRIVATE,
        )
        val encoded = preferences.getString(sessionKey, null) ?: return null
        val parts = encoded.split(':', limit = 2)
        require(parts.size == 2)

        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val key = keyStore.getKey(keyAlias, null) as? SecretKey ?: return null
        val cipher = Cipher.getInstance(transformation).apply {
            init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(tagLengthBits, Base64.decode(parts[0], Base64.NO_WRAP)),
            )
            updateAAD(sessionAad)
        }
        val payload = JSONObject(
            String(
                cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)),
                Charsets.UTF_8,
            ),
        )
        val cookieHeader = payload.getString("cookie_header")
        require(cookieHeader.contains("SESSDATA="))
        mapOf(
            "cookieHeader" to cookieHeader,
            "accessKey" to payload.optString("access_key").trim().ifEmpty { null },
        )
    }.getOrNull()

    fun clear(context: Context): Boolean = context.applicationContext
        .getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        .edit()
        .remove(sessionKey)
        .commit()
}

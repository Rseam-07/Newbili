package com.example.piliplus

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Keeps Hive's account-box key encrypted by a non-exportable Android Keystore key. */
internal object AccountHiveKeyStore {
    private const val preferencesName = "newbili_secure_storage"
    private const val encryptedKeyName = "account_hive_key_v1"
    private const val keyAlias = "newbili_account_hive_key_wrap_v1"
    private const val transformation = "AES/GCM/NoPadding"
    private const val tagLengthBits = 128
    private val aad = "Newbili Android account Hive key v1".toByteArray(Charsets.UTF_8)

    @Synchronized
    fun getOrCreate(context: Context): ByteArray {
        val preferences = context.applicationContext.getSharedPreferences(
            preferencesName,
            Context.MODE_PRIVATE,
        )
        preferences.getString(encryptedKeyName, null)?.let { encoded ->
            val parts = encoded.split(':', limit = 2)
            require(parts.size == 2)
            return Cipher.getInstance(transformation).run {
                init(
                    Cipher.DECRYPT_MODE,
                    wrappingKey(),
                    GCMParameterSpec(
                        tagLengthBits,
                        Base64.decode(parts[0], Base64.NO_WRAP),
                    ),
                )
                updateAAD(aad)
                doFinal(Base64.decode(parts[1], Base64.NO_WRAP))
            }.also { require(it.size == 32) }
        }

        val rawKey = ByteArray(32).also(SecureRandom()::nextBytes)
        val cipher = Cipher.getInstance(transformation).apply {
            init(Cipher.ENCRYPT_MODE, wrappingKey())
            updateAAD(aad)
        }
        val encoded = listOf(cipher.iv, cipher.doFinal(rawKey)).joinToString(":") {
            Base64.encodeToString(it, Base64.NO_WRAP)
        }
        check(preferences.edit().putString(encryptedKeyName, encoded).commit()) {
            "Unable to persist the encrypted account key"
        }
        return rawKey
    }

    private fun wrappingKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(
                KeyGenParameterSpec.Builder(
                    keyAlias,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                    .build(),
            )
            generateKey()
        }
    }
}

package com.rseam07.newbili.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.LinkedHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

@Composable
internal fun rememberRemoteImageBitmap(
    url: String?,
    targetWidth: Dp,
    targetHeight: Dp
): ImageBitmap? {
    val density = LocalDensity.current
    val targetWidthPx = with(density) { targetWidth.roundToPx() }
    val targetHeightPx = with(density) { targetHeight.roundToPx() }
    val bitmap by produceState<ImageBitmap?>(
        initialValue = null,
        key1 = url,
        key2 = targetWidthPx,
        key3 = targetHeightPx
    ) {
        value = null
        value = url
            ?.let { SharedRemoteImageLoader.load(it, targetWidthPx, targetHeightPx) }
            ?.asImageBitmap()
    }
    return bitmap
}

internal data class RemoteImageSize(
    val widthPx: Int,
    val heightPx: Int
) {
    fun bucketed(): RemoteImageSize = RemoteImageSize(
        widthPx = widthPx.toImageSizeBucket(),
        heightPx = heightPx.toImageSizeBucket()
    )
}

internal fun calculateBitmapSampleSize(
    sourceWidth: Int,
    sourceHeight: Int,
    targetWidth: Int,
    targetHeight: Int
): Int {
    if (sourceWidth <= 0 || sourceHeight <= 0 || targetWidth <= 0 || targetHeight <= 0) {
        return 1
    }

    var sampleSize = 1
    val halfWidth = sourceWidth / 2
    val halfHeight = sourceHeight / 2
    while (
        halfWidth / sampleSize >= targetWidth &&
        halfHeight / sampleSize >= targetHeight &&
        sampleSize <= Int.MAX_VALUE / 2
    ) {
        sampleSize *= 2
    }
    return sampleSize
}

internal class WeightedLruCache<Key : Any, Value : Any>(
    private val maxWeight: Int,
    private val weightOf: (Value) -> Int
) {
    private val entries = LinkedHashMap<Key, Value>(0, 0.75f, true)
    private var currentWeight = 0

    init {
        require(maxWeight > 0) { "maxWeight must be positive" }
    }

    operator fun get(key: Key): Value? = entries[key]

    fun put(key: Key, value: Value) {
        val valueWeight = weightOf(value).coerceAtLeast(1)
        entries.remove(key)?.let { currentWeight -= weightOf(it).coerceAtLeast(1) }
        if (valueWeight > maxWeight) {
            return
        }

        entries[key] = value
        currentWeight += valueWeight
        trimToWeight()
    }

    fun clear() {
        entries.clear()
        currentWeight = 0
    }

    private fun trimToWeight() {
        val iterator = entries.entries.iterator()
        while (currentWeight > maxWeight && iterator.hasNext()) {
            val entry = iterator.next()
            currentWeight -= weightOf(entry.value).coerceAtLeast(1)
            iterator.remove()
        }
    }
}

internal fun interface RemoteImageFetcher {
    suspend fun fetch(url: String): ByteArray?
}

internal fun interface RemoteImageDecoder<Value : Any> {
    fun decode(bytes: ByteArray, targetSize: RemoteImageSize): Value?
}

internal class RemoteImagePipeline<Value : Any>(
    private val scope: CoroutineScope,
    maxCacheWeight: Int,
    private val fetcher: RemoteImageFetcher,
    private val decoder: RemoteImageDecoder<Value>,
    weightOf: (Value) -> Int
) {
    private data class ImageKey(
        val url: String,
        val size: RemoteImageSize
    )

    private data class InFlight<Value>(
        val token: Any,
        val deferred: Deferred<Value?>
    )

    private val mutex = Mutex()
    private val cache = WeightedLruCache<ImageKey, Value>(maxCacheWeight, weightOf)
    private val imageTasks = mutableMapOf<ImageKey, InFlight<Value>>()
    private val fetchTasks = mutableMapOf<String, InFlight<ByteArray>>()

    suspend fun load(rawURL: String, targetWidthPx: Int, targetHeightPx: Int): Value? {
        val url = normalizeRemoteImageURL(rawURL) ?: return null
        val key = ImageKey(
            url = url,
            size = RemoteImageSize(targetWidthPx, targetHeightPx).bucketed()
        )
        val task = mutex.withLock {
            cache[key]?.let { return it }
            imageTasks[key]?.deferred ?: createImageTask(key)
        }
        task.start()
        return task.await()
    }

    suspend fun clearMemoryCache() = mutex.withLock {
        cache.clear()
    }

    private fun createImageTask(key: ImageKey): Deferred<Value?> {
        val token = Any()
        val task = scope.async(start = CoroutineStart.LAZY) {
            var decoded: Value? = null
            try {
                decoded = fetchBytes(key.url)?.let { decoder.decode(it, key.size) }
            } catch (cancellation: CancellationException) {
                throw cancellation
            } catch (_: Throwable) {
                decoded = null
            } finally {
                mutex.withLock {
                    if (imageTasks[key]?.token === token) {
                        imageTasks.remove(key)
                        decoded?.let { cache.put(key, it) }
                    }
                }
            }
            decoded
        }
        imageTasks[key] = InFlight(token, task)
        return task
    }

    private suspend fun fetchBytes(url: String): ByteArray? {
        val task = mutex.withLock {
            fetchTasks[url]?.deferred ?: createFetchTask(url)
        }
        task.start()
        return task.await()
    }

    private fun createFetchTask(url: String): Deferred<ByteArray?> {
        val token = Any()
        val task = scope.async(start = CoroutineStart.LAZY) {
            try {
                fetcher.fetch(url)
            } catch (cancellation: CancellationException) {
                throw cancellation
            } catch (_: Throwable) {
                null
            } finally {
                mutex.withLock {
                    if (fetchTasks[url]?.token === token) {
                        fetchTasks.remove(url)
                    }
                }
            }
        }
        fetchTasks[url] = InFlight(token, task)
        return task
    }
}

private object SharedRemoteImageLoader {
    private val cacheBytes = (Runtime.getRuntime().maxMemory() / CACHE_MEMORY_DIVISOR)
        .coerceIn(MIN_CACHE_BYTES, MAX_CACHE_BYTES)
        .toInt()
    private val pipeline = RemoteImagePipeline(
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
        maxCacheWeight = cacheBytes,
        fetcher = HttpRemoteImageFetcher,
        decoder = SampledBitmapDecoder,
        weightOf = { bitmap: Bitmap -> bitmap.allocationByteCount.coerceAtLeast(1) }
    )

    suspend fun load(url: String, targetWidthPx: Int, targetHeightPx: Int): Bitmap? =
        pipeline.load(url, targetWidthPx, targetHeightPx)
}

private object HttpRemoteImageFetcher : RemoteImageFetcher {
    override suspend fun fetch(url: String): ByteArray? = runCatching {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
            connection.readTimeout = NETWORK_TIMEOUT_MILLIS
            connection.instanceFollowRedirects = true
            connection.setRequestProperty("Accept", "image/avif,image/webp,image/*,*/*;q=0.8")
            connection.setRequestProperty("Referer", "https://www.bilibili.com/")
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 12) Newbili/1.0")
            if (connection.responseCode !in 200..299) {
                return@runCatching null
            }
            val contentLength = connection.contentLengthLong
            if (contentLength > MAX_DOWNLOAD_BYTES) {
                return@runCatching null
            }
            connection.inputStream.use { it.readAtMost(MAX_DOWNLOAD_BYTES) }
        } finally {
            connection.disconnect()
        }
    }.getOrNull()
}

private object SampledBitmapDecoder : RemoteImageDecoder<Bitmap> {
    override fun decode(bytes: ByteArray, targetSize: RemoteImageSize): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateBitmapSampleSize(
                sourceWidth = bounds.outWidth,
                sourceHeight = bounds.outHeight,
                targetWidth = targetSize.widthPx,
                targetHeight = targetSize.heightPx
            )
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }
}

private fun normalizeRemoteImageURL(rawURL: String): String? {
    val trimmed = rawURL.trim()
    val secureURL = when {
        trimmed.startsWith("http://", ignoreCase = true) ->
            "https://${trimmed.substringAfter("://")}"
        trimmed.startsWith("//") -> "https:$trimmed"
        else -> trimmed
    }
    return runCatching {
        URL(secureURL).takeIf { it.protocol.equals("https", ignoreCase = true) }?.toExternalForm()
    }.getOrNull()
}

private fun Int.toImageSizeBucket(): Int {
    val bounded = coerceIn(1, MAX_TARGET_DIMENSION_PX)
    return ((bounded + IMAGE_SIZE_BUCKET_PX - 1) / IMAGE_SIZE_BUCKET_PX) * IMAGE_SIZE_BUCKET_PX
}

private fun InputStream.readAtMost(maxBytes: Int): ByteArray? {
    val output = ByteArrayOutputStream(DEFAULT_DOWNLOAD_BUFFER_BYTES)
    val buffer = ByteArray(DEFAULT_DOWNLOAD_BUFFER_BYTES)
    var total = 0
    while (true) {
        val count = read(buffer)
        if (count < 0) {
            break
        }
        total += count
        if (total > maxBytes) {
            return null
        }
        output.write(buffer, 0, count)
    }
    return output.toByteArray()
}

private const val NETWORK_TIMEOUT_MILLIS = 8_000
private const val MAX_DOWNLOAD_BYTES = 8 * 1_024 * 1_024
private const val DEFAULT_DOWNLOAD_BUFFER_BYTES = 16 * 1_024
private const val IMAGE_SIZE_BUCKET_PX = 32
private const val MAX_TARGET_DIMENSION_PX = 4_096
private const val CACHE_MEMORY_DIVISOR = 16
private const val MIN_CACHE_BYTES = 4L * 1_024L * 1_024L
private const val MAX_CACHE_BYTES = 24L * 1_024L * 1_024L

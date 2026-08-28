package com.rseam07.newbili.ui

import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RemoteImageLoaderTest {
    @Test
    fun bitmapSampleSizeAvoidsFullSizeAvatarDecode() {
        assertEquals(32, calculateBitmapSampleSize(2_048, 2_048, 58, 58))
        assertEquals(1, calculateBitmapSampleSize(48, 48, 58, 58))
        assertEquals(1, calculateBitmapSampleSize(0, 2_048, 58, 58))
    }

    @Test
    fun weightedCacheEvictsLeastRecentlyUsedEntry() {
        val cache = WeightedLruCache<String, String>(maxWeight = 4, weightOf = String::length)
        cache.put("first", "aa")
        cache.put("second", "bb")
        assertEquals("aa", cache["first"])

        cache.put("third", "cc")

        assertEquals("aa", cache["first"])
        assertNull(cache["second"])
        assertEquals("cc", cache["third"])
    }

    @Test
    fun concurrentEquivalentRequestsShareDecodeAndCachedResult() = runBlocking {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val fetchCount = AtomicInteger()
        val decodeCount = AtomicInteger()
        val pipeline = RemoteImagePipeline(
            scope = scope,
            maxCacheWeight = 8,
            fetcher = RemoteImageFetcher {
                fetchCount.incrementAndGet()
                delay(30)
                byteArrayOf(1, 2, 3)
            },
            decoder = RemoteImageDecoder { _, size ->
                decodeCount.incrementAndGet()
                "${size.widthPx}x${size.heightPx}"
            },
            weightOf = { _: String -> 1 }
        )
        try {
            val results = List(12) {
                async { pipeline.load("http://i0.hdslb.com/avatar.jpg", 58, 58) }
            }.awaitAll()

            assertEquals(List(12) { "64x64" }, results)
            assertEquals("64x64", pipeline.load("https://i0.hdslb.com/avatar.jpg", 60, 60))
            assertEquals(1, fetchCount.get())
            assertEquals(1, decodeCount.get())
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun differentDisplaySizesStillShareConcurrentDownload() = runBlocking {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val fetchCount = AtomicInteger()
        val decodeCount = AtomicInteger()
        val pipeline = RemoteImagePipeline(
            scope = scope,
            maxCacheWeight = 8,
            fetcher = RemoteImageFetcher {
                fetchCount.incrementAndGet()
                delay(30)
                byteArrayOf(1, 2, 3)
            },
            decoder = RemoteImageDecoder { _, size ->
                decodeCount.incrementAndGet()
                "${size.widthPx}x${size.heightPx}"
            },
            weightOf = { _: String -> 1 }
        )
        try {
            val results = listOf(
                async { pipeline.load("https://i0.hdslb.com/avatar.jpg", 58, 58) },
                async { pipeline.load("https://i0.hdslb.com/avatar.jpg", 110, 110) }
            ).awaitAll()

            assertEquals(listOf("64x64", "128x128"), results)
            assertEquals(1, fetchCount.get())
            assertEquals(2, decodeCount.get())
        } finally {
            scope.cancel()
        }
    }
}

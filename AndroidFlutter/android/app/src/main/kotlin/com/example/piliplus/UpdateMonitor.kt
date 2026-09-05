package com.example.piliplus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicReference
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import javax.net.ssl.HttpsURLConnection

/** Lightweight native checks: no second Flutter engine or concurrent Hive writers. */
internal class UpdateMonitor(private val context: Context, preferencesName: String = "newbili_updates_v1") {
    companion object {
        const val JOB_ID = 10607
        const val SERIES_CHANNEL = "newbili.series.updates"
        const val UP_CHANNEL = "newbili.uploader.updates"
        private var instance: UpdateMonitor? = null
        @Synchronized fun get(context: Context): UpdateMonitor =
            instance ?: UpdateMonitor(context.applicationContext).also { instance = it }
    }

    private val prefs = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
    private val notifications = context.getSystemService(NotificationManager::class.java)
    private val jobs = context.getSystemService(JobScheduler::class.java)
    private val runningCheck = AtomicReference<CompletableFuture<Unit>?>(null)
    private val lock = Any()
    private val aad = "Newbili update checks v1".toByteArray()

    init {
        notifications.createNotificationChannels(listOf(
            NotificationChannel(SERIES_CHANNEL, "追更 · 分 P 更新", NotificationManager.IMPORTANCE_DEFAULT),
            NotificationChannel(UP_CHANNEL, "关注 UP 新投稿", NotificationManager.IMPORTANCE_DEFAULT),
        ))
    }

    private fun tracks() = JSONArray(prefs.getString("tracks", "[]")).objects()
    private fun channelEnabled(id: String) = notifications.areNotificationsEnabled() &&
        notifications.getNotificationChannel(id)?.importance != NotificationManager.IMPORTANCE_NONE

    fun state(): String = synchronized(lock) {
        JSONObject().put("level", prefs.getString("level", "off"))
            .put("tracks", JSONArray(tracks())).put("checking", runningCheck.get() != null)
            .put("permission", notifications.areNotificationsEnabled())
            .put("seriesPermission", channelEnabled(SERIES_CHANNEL))
            .put("upPermission", channelEnabled(UP_CHANNEL))
            .put("loggedIn", prefs.getLong("mid", 0) > 0)
            .put("lastChecked", prefs.getLong("lastChecked", 0))
            .put("status", prefs.getString("status", "尚未检查更新"))
            .put("recent", JSONArray(prefs.getString("recent", "[]"))).toString()
    }

    fun configure(level: String, mid: Long, cookie: String) = synchronized(lock) {
        require(level in UpdatePolicy.levels)
        val effectiveMid = if (level == "off" || cookie.isEmpty()) 0 else mid
        val credential = if (effectiveMid > 0) cookie else ""
        val digest = MessageDigest.getInstance("SHA-256").digest(credential.toByteArray())
            .joinToString("") { "%02x".format(it) }
        val changed = prefs.getString("level", "off") != level || prefs.getLong("mid", 0) != effectiveMid
        val editor = prefs.edit().putString("level", level).putLong("mid", effectiveMid)
        if (changed) {
            editor.putBoolean("baseline", false).remove("seen")
                .putInt("generation", prefs.getInt("generation", 0) + 1)
            if (prefs.getLong("mid", 0) != effectiveMid) {
                // A new account must not see the previous account's update history.
                editor.remove("recent")
                notifications.activeNotifications.filter { it.tag?.startsWith("up.") == true }
                    .forEach { notifications.cancel(it.tag, it.id) }
            }
        }
        if (prefs.getString("credentialDigest", "") != digest) {
            editor.putString("credentialDigest", digest)
            if (credential.isEmpty()) editor.remove("credential")
            else editor.putString("credential", seal(credential))
        }
        check(editor.commit()) { "无法保存通知设置" }
        schedule()
    }

    fun mark(data: JSONObject) = synchronized(lock) {
        val snapshot = UpdatePolicy.snapshot(data, System.currentTimeMillis())
        val current = tracks()
        if (current.any { it.getString("bvid") == snapshot.getString("bvid") }) return@synchronized
        snapshot.put("known", JSONArray(snapshot.getJSONArray("pages").objects().map { it.getLong("cid") }))
        check(prefs.edit().putString("tracks", JSONArray(listOf(snapshot) + current).toString())
            .putString("status", "已添加追更，可检查新增分 P")
            .putLong("lastChecked", 0)
            .putInt("generation", prefs.getInt("generation", 0) + 1).commit())
        schedule()
    }

    fun unmark(bvid: String) = synchronized(lock) {
        require(UpdatePolicy.validBvid(bvid))
        check(prefs.edit().putString("tracks", JSONArray(tracks().filter { it.getString("bvid") != bvid }).toString())
            .putInt("generation", prefs.getInt("generation", 0) + 1).commit())
        notifications.cancel("series.$bvid", 0)
        schedule()
    }

    fun schedule() = synchronized(lock) {
        val hasTargets = (tracks().isNotEmpty() && channelEnabled(SERIES_CHANNEL)) ||
            (prefs.getString("level", "off") != "off" && prefs.getLong("mid", 0) > 0 && channelEnabled(UP_CHANNEL))
        if (!hasTargets) jobs.cancel(JOB_ID)
        else if (jobs.getPendingJob(JOB_ID) == null) {
            jobs.schedule(JobInfo.Builder(JOB_ID, ComponentName(context, UpdateCheckJob::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPeriodic(15 * 60 * 1000L)
                .setPersisted(true).setRequiresBatteryNotLow(true).build())
        }
    }

    fun checkUpdates(
        manual: Boolean = false,
        cancelled: () -> Boolean = { Thread.currentThread().isInterrupted },
        request: (String, String) -> Any = ::api,
    ): String {
        val completion = CompletableFuture<Unit>()
        if (!runningCheck.compareAndSet(null, completion)) {
            runningCheck.get()?.get()
            return state()
        }
        var checks = 0
        var failures = 0
        var sent = 0
        try {
            schedule()
            if (!notifications.areNotificationsEnabled()) {
                prefs.edit().putString("status", "系统通知已关闭，请前往系统设置开启").apply()
                return state()
            }
            if (!manual && System.currentTimeMillis() - prefs.getLong("lastChecked", 0) < 5 * 60 * 1000) return state()
            val generation = prefs.getInt("generation", 0)
            fun stale() = cancelled() || generation != prefs.getInt("generation", 0)
            val start = SystemClock.elapsedRealtime()
            val current = synchronized(lock) { tracks() }
            val cursor = prefs.getInt("cursor", 0).let { if (current.isEmpty()) 0 else it % current.size }
            var checkedTracks = 0
            if (channelEnabled(SERIES_CHANNEL)) {
                for (item in (current.drop(cursor) + current.take(cursor)).take(20)) {
                    if (stale() || SystemClock.elapsedRealtime() - start > 60_000) break
                    try {
                        val bvid = item.getString("bvid")
                        val data = request("/x/web-interface/view?bvid=$bvid", "") as JSONObject
                        require(data.getString("bvid") == bvid)
                        val updated = UpdatePolicy.snapshot(data, item.getLong("markedAt"), System.currentTimeMillis())
                        val pages = updated.getJSONArray("pages").objects()
                        val known = item.optJSONArray("known").longs().ifEmpty {
                            item.optJSONArray("pages").objects().map { it.getLong("cid") }.toSet()
                        }
                        val added = UpdatePolicy.addedPages(known, pages)
                        synchronized(lock) {
                            if (!stale()) {
                                if (added.isNotEmpty()) {
                                    val title = "追更提醒 · ${updated.getString("title")}"
                                    val first = added.first()
                                    val body = if (added.size == 1) "${first.optString("title").ifBlank { "新分 P" }} 已更新，点此继续观看。"
                                        else "新增 ${added.size} 个分 P，点此继续观看。"
                                    post(SERIES_CHANNEL, "series.$bvid", title, body, bvid, first.optInt("page", 1))
                                    sent++
                                }
                                updated.put("known", JSONArray((pages.map { it.getLong("cid") } + known).distinct().take(4096)))
                                check(prefs.edit().putString("tracks", JSONArray(tracks().map {
                                    if (it.getString("bvid") == bvid) updated else it
                                }).toString()).commit())
                                checks++
                            }
                        }
                    } catch (_: Exception) { failures++ }
                    checkedTracks++
                }
                prefs.edit().putInt("cursor", cursor + checkedTracks).apply()
            }
            val level = prefs.getString("level", "off")
            val mid = prefs.getLong("mid", 0)
            if (!stale() && level != "off" && mid > 0 && channelEnabled(UP_CHANNEL)) {
                try {
                    val cookie = unseal(prefs.getString("credential", "")!!)
                    val allowed = if (level == "specialOnly") {
                        val result = linkedSetOf<Long>()
                        for (page in 1..10) {
                            check(!stale() && SystemClock.elapsedRealtime() - start < 60_000)
                            val values = (request("/x/relation/tag?tagid=-10&pn=$page&ps=50", cookie) as JSONArray).objects()
                            result.addAll(values.map { it.getLong("mid") })
                            if (values.size < 50 || stale()) break
                            check(page < 10) { "特别关注列表尚未读取完整" }
                        }
                        result
                    } else null
                    val records = UpdatePolicy.records(request("/x/polymer/web-dynamic/v1/feed/all?type=video", cookie) as JSONObject)
                    synchronized(lock) {
                        if (!stale()) {
                            val seen = JSONArray(prefs.getString("seen", "[]")).strings().toMutableSet()
                            val fresh = UpdatePolicy.newRecords(records, seen, prefs.getBoolean("baseline", false), allowed)
                            for (record in fresh.take(20)) {
                                post(UP_CHANNEL, "up.${record.getString("id")}",
                                    "${record.getString("owner").ifBlank { "关注的 UP" }} 更新了",
                                    record.getString("title"), record.getString("bvid"), 1)
                                seen.add(record.getString("id"))
                                check(prefs.edit().putString("seen", JSONArray(seen.toList().takeLast(512)).toString()).commit())
                                sent++
                            }
                            check(prefs.edit().putBoolean("baseline", true)
                                .putString("seen", JSONArray((records.map { it.getString("id") } + seen).distinct().take(512)).toString()).commit())
                            checks++
                        }
                    }
                } catch (_: Exception) { failures++ }
            }
            if (!stale()) {
                val message = when {
                    failures > 0 -> "已检查 $checks 项，$failures 项暂时失败，将在下次检查时重试"
                    sent > 0 -> "发现 $sent 条更新，已发送通知"
                    checks > 0 -> "已检查 $checks 项，目前没有新内容"
                    else -> "没有可执行的更新检查"
                } + if (level != "off" && mid == 0L) "；关注 UP 未登录，本次未检查" else ""
                prefs.edit().putLong("lastChecked", System.currentTimeMillis()).putString("status", message).apply()
            }
        } finally {
            runningCheck.compareAndSet(completion, null)
            completion.complete(Unit)
        }
        return state()
    }

    private fun api(path: String, cookie: String = ""): Any {
        val connection = URL("https://api.bilibili.com$path").openConnection() as HttpsURLConnection
        try {
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36")
            connection.setRequestProperty("Referer", "https://www.bilibili.com/")
            if (cookie.isNotEmpty()) connection.setRequestProperty("Cookie", cookie)
            check(connection.responseCode == 200) { "Update request failed" }
            val response = connection.inputStream.bufferedReader().use { reader ->
                val buffer = CharArray(8192)
                val text = StringBuilder()
                while (true) {
                    val count = reader.read(buffer)
                    if (count < 0) break
                    check(text.length + count <= 2_000_000) { "Update response too large" }
                    text.append(buffer, 0, count)
                }
                JSONObject(text.toString())
            }
            check(response.getInt("code") == 0) { "Update API unavailable" }
            return response.get("data")
        } finally { connection.disconnect() }
    }

    private fun post(channel: String, tag: String, title: String, body: String, bvid: String, page: Int) {
        check(channelEnabled(channel)) { "Notification channel disabled" }
        val intent = Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("https://www.bilibili.com/video/$bvid?p=${page.coerceAtLeast(1)}"))
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(context, tag.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(context, channel).setSmallIcon(R.drawable.ic_notification_icon)
            .setContentTitle(title).setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE).build()
        notifications.notify(tag, 0, notification)
        val entry = JSONObject().put("id", tag).put("title", title).put("body", body)
            .put("bvid", bvid).put("page", page).put("time", System.currentTimeMillis())
        val recent = JSONArray(prefs.getString("recent", "[]")).objects().filter { it.optString("id") != tag }
        prefs.edit().putString("recent", JSONArray((listOf(entry) + recent).take(50)).toString()).apply()
    }

    private fun seal(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(AccountHiveKeyStore.getOrCreate(context), "AES"))
        cipher.updateAAD(aad)
        return listOf(cipher.iv, cipher.doFinal(value.toByteArray())).joinToString(":") {
            Base64.encodeToString(it, Base64.NO_WRAP)
        }
    }

    private fun unseal(value: String): String {
        val parts = value.split(':', limit = 2)
        require(parts.size == 2)
        return Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, SecretKeySpec(AccountHiveKeyStore.getOrCreate(context), "AES"),
                GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
            updateAAD(aad)
            doFinal(Base64.decode(parts[1], Base64.NO_WRAP)).toString(Charsets.UTF_8)
        }
    }
}

package com.example.piliplus

import android.app.Activity
import android.app.Instrumentation
import android.app.NotificationManager
import android.app.job.JobScheduler
import android.content.Context
import android.os.Bundle
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicInteger

/** Device-side tests use isolated preferences and synthetic API responses only. */
class UpdateMonitorInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val report = Bundle()
        val context = targetContext
        val prefs = context.getSharedPreferences("newbili_updates_instrumentation", Context.MODE_PRIVATE)
        val notifications = context.getSystemService(NotificationManager::class.java)
        val jobs = context.getSystemService(JobScheduler::class.java)
        var checks = 0
        try {
            check(context.packageName.endsWith(".debug")) { "Only the isolated Debug target may run these checks" }
            check(notifications.areNotificationsEnabled()) { "Enable notifications on the test emulator first" }
            check(prefs.edit().clear().commit())
            val monitor = UpdateMonitor(context, "newbili_updates_instrumentation")
            val bvid = "BV1td8R6EE2L"
            fun video(vararg ids: Long) = JSONObject().put("bvid", bvid).put("title", "Newbili 通知回归样本")
                .put("owner", JSONObject().put("name", "QA"))
                .put("pages", JSONArray(ids.mapIndexed { index, cid ->
                    JSONObject().put("cid", cid).put("page", index + 1).put("part", "P${index + 1}")
                }))
            fun state() = JSONObject(monitor.state())

            monitor.mark(video(101))
            check(jobs.getPendingJob(UpdateMonitor.JOB_ID) != null)
            monitor.checkUpdates(true, request = { _, _ -> video(101) })
            check(state().getJSONArray("recent").length() == 0)
            checks++

            monitor.checkUpdates(true, request = { _, _ -> video(101, 202) })
            check(state().getJSONArray("recent").length() == 1)
            val notification = notifications.activeNotifications.single { it.tag == "series.$bvid" }.notification
            check(notification.contentIntent != null && notification.smallIcon != null)
            check(notification.extras.getString("android.title")!!.startsWith("追更提醒"))
            check(state().getJSONArray("tracks").getJSONObject(0).getJSONArray("pages").length() == 2)
            checks++

            monitor.checkUpdates(true, request = { _, _ -> video(202, 101) })
            check(state().getJSONArray("recent").length() == 1)
            monitor.checkUpdates(true, request = { _, _ -> throw IOException("synthetic offline") })
            check(state().getJSONArray("tracks").getJSONObject(0).getJSONArray("pages").length() == 2)
            check(state().getString("status").contains("失败"))
            monitor.checkUpdates(true, request = { _, _ -> video(101, 202, 303) })
            check(state().getJSONArray("tracks").getJSONObject(0).getJSONArray("pages").length() == 3)
            checks++

            monitor.checkUpdates(true, request = { _, _ -> monitor.unmark(bvid); video(101, 202, 303, 404) })
            check(state().getJSONArray("tracks").length() == 0)
            check(notifications.activeNotifications.none { it.tag == "series.$bvid" })
            check(jobs.getPendingJob(UpdateMonitor.JOB_ID) == null)
            checks++

            monitor.mark(video(101))
            val entered = CountDownLatch(1)
            val release = CountDownLatch(1)
            val calls = AtomicInteger()
            val executor = Executors.newFixedThreadPool(2)
            try {
                val first = executor.submit<String> {
                    monitor.checkUpdates(true, request = { _, _ ->
                        calls.incrementAndGet()
                        entered.countDown()
                        check(release.await(5, TimeUnit.SECONDS))
                        video(101)
                    })
                }
                check(entered.await(5, TimeUnit.SECONDS))
                val second = executor.submit<String> {
                    monitor.checkUpdates(true, request = { _, _ -> calls.incrementAndGet(); video(101) })
                }
                try {
                    second.get(100, TimeUnit.MILLISECONDS)
                    error("A concurrent check returned before the shared request completed")
                } catch (_: TimeoutException) { /* Expected: callers share the same check. */ }
                release.countDown()
                first.get(5, TimeUnit.SECONDS)
                second.get(5, TimeUnit.SECONDS)
                check(calls.get() == 1)
                check(!state().getBoolean("checking"))
            } finally {
                release.countDown()
                executor.shutdownNow()
                monitor.unmark(bvid)
            }
            checks++

            fun dynamic(id: String, mid: Long) = JSONObject().put("id_str", id).put("modules",
                JSONObject().put("module_author", JSONObject().put("mid", mid).put("name", "QA UP"))
                    .put("module_dynamic", JSONObject().put("major", JSONObject().put("archive",
                        JSONObject().put("bvid", bvid).put("title", "测试投稿")))))
            var records = listOf(dynamic("qa-old", 1))
            var specialFails = false
            val request: (String, String) -> Any = { path, cookie ->
                check(cookie == "SESSDATA=synthetic-test-not-a-real-session")
                if (path.contains("relation/tag")) {
                    if (specialFails) throw IOException("synthetic partial failure")
                    JSONArray(listOf(JSONObject().put("mid", 1)))
                } else JSONObject().put("items", JSONArray(records))
            }
            monitor.configure("specialOnly", 123, "SESSDATA=synthetic-test-not-a-real-session")
            check(!prefs.getString("credential", "")!!.contains("SESSDATA"))
            monitor.checkUpdates(true, request = request)
            check(state().getJSONArray("recent").length() == 0)
            records = listOf(dynamic("qa-old", 1), dynamic("qa-new", 1), dynamic("qa-other", 2))
            specialFails = true
            monitor.checkUpdates(true, request = request)
            check(state().getJSONArray("recent").length() == 0)
            specialFails = false
            monitor.checkUpdates(true, request = request)
            check(state().getJSONArray("recent").length() == 1)
            check(notifications.activeNotifications.any { it.tag == "up.qa-new" })
            check(notifications.activeNotifications.none { it.tag == "up.qa-other" })
            checks++

            monitor.configure("allFollowing", 456, "SESSDATA=synthetic-test-not-a-real-session")
            monitor.checkUpdates(true, request = request)
            check(state().getJSONArray("recent").length() == 0)
            monitor.configure("off", 0, "")
            check(!prefs.contains("credential"))
            check(jobs.getPendingJob(UpdateMonitor.JOB_ID) == null)
            checks++
            report.putString("stream", "\nOK ($checks device notification checks)\n")
            report.putInt("passed", checks)
            finish(Activity.RESULT_OK, report)
        } catch (error: Throwable) {
            report.putString("stream", "\nFAILED after $checks checks: ${error.stackTraceToString()}\n")
            finish(Activity.RESULT_CANCELED, report)
        } finally {
            notifications.cancel("series.BV1td8R6EE2L", 0)
            notifications.cancel("up.qa-new", 0)
            jobs.cancel(UpdateMonitor.JOB_ID)
            prefs.edit().clear().commit()
        }
    }
}

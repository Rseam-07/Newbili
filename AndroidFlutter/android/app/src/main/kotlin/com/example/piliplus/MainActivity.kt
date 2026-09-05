package com.example.piliplus

import android.app.ActivityManager
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val updateExecutor = Executors.newCachedThreadPool()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rseam07.newbili/updates")
            .setMethodCallHandler { call, result ->
                updateExecutor.execute {
                    try {
                        val monitor = UpdateMonitor.get(this)
                        when (call.method) {
                            "state" -> monitor.schedule()
                            "configure" -> monitor.configure(
                                call.argument<String>("level") ?: "off",
                                call.argument<Number>("mid")?.toLong() ?: 0,
                                call.argument<String>("cookie") ?: "",
                            )
                            "mark" -> monitor.mark(JSONObject(call.argument<String>("video")!!))
                            "unmark" -> monitor.unmark(call.argument<String>("bvid")!!)
                            "check" -> monitor.checkUpdates(call.argument<Boolean>("manual") == true)
                            else -> {
                                runOnUiThread { result.notImplemented() }
                                return@execute
                            }
                        }
                        val state = monitor.state()
                        runOnUiThread { result.success(state) }
                    } catch (_: Exception) {
                        runOnUiThread { result.error("update_monitor", "更新检查暂时不可用，请稍后重试", null) }
                    }
                }
            }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rseam07.newbili/glass",
        ).setMethodCallHandler { call, result ->
            if (call.method != "capability") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val activityManager = getSystemService(ActivityManager::class.java)
            val powerManager = getSystemService(PowerManager::class.java)
            result.success(
                mapOf(
                    "api" to Build.VERSION.SDK_INT,
                    "lowRam" to (activityManager?.isLowRamDevice ?: true),
                    "powerSave" to (powerManager?.isPowerSaveMode ?: true),
                ),
            )
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rseam07.newbili/legacy_account",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "peek" -> result.success(LegacyAccountMigration.peek(this))
                "clear" -> result.success(LegacyAccountMigration.clear(this))
                "accountHiveKey" -> runCatching {
                    AccountHiveKeyStore.getOrCreate(this)
                }.fold(
                    onSuccess = result::success,
                    onFailure = {
                        result.error("secure_storage", "Unable to unlock account storage", null)
                    },
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onDestroy() {
        updateExecutor.shutdownNow()
        stopService(Intent(this, com.ryanheise.audioservice.AudioService::class.java))
        super.onDestroy()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}

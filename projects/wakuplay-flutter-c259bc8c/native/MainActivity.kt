package com.wakuplay.app

import android.app.PictureInPictureParams
import android.content.pm.ActivityInfo
import android.os.Build
import android.util.Rational
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.wakuplay.notify.NotifyBridge
import io.flutter.plugin.common.MethodChannel

/// Pengganti plugin Capacitor wp-pip: PiP, landscape pemutar, mode immersive.
class MainActivity : FlutterActivity() {
    private var pipAllowed = false
    private var channel: MethodChannel? = null
    private var pendingTap: Map<String, Any?>? = null

    private fun readTap(i: android.content.Intent?): Map<String, Any?>? {
        if (i == null || !i.hasExtra("wp_type")) return null
        val m = mapOf("type" to i.getStringExtra("wp_type"), "title" to i.getStringExtra("wp_title"), "data" to i.getStringExtra("wp_data"))
        i.removeExtra("wp_type")
        return m
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        val t = readTap(intent) ?: return
        if (channel != null) channel!!.invokeMethod("notifTap", t) else pendingTap = t
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wakuplay/native")
        pendingTap = readTap(intent)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setPipAllowed" -> { pipAllowed = call.argument<Boolean>("enabled") == true; result.success(null) }
                "setLandscape" -> {
                    requestedOrientation = if (call.argument<Boolean>("enabled") == true)
                        ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE else ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    result.success(null)
                }
                "setImmersive" -> {
                    val c = WindowInsetsControllerCompat(window, window.decorView)
                    if (call.argument<Boolean>("enabled") == true) {
                        c.hide(WindowInsetsCompat.Type.systemBars())
                        c.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    } else c.show(WindowInsetsCompat.Type.systemBars())
                    result.success(null)
                }
                "notifConfigure" -> {
                    val ok = NotifyBridge.configure(this, call.argument("url"), call.argument("key"), call.argument("device"),
                        call.argument("secret"), call.argument("uid"), call.argument("since"), (call.argument<Number>("interval") ?: 30000).toLong())
                    result.success(ok)
                }
                "notifSetSpeed" -> { NotifyBridge.setSpeed(this, (call.argument<Number>("interval") ?: 30000).toLong()); result.success(null) }
                "takeLaunchNotif" -> { val t = pendingTap; pendingTap = null; result.success(t) }
                "notifStatus" -> result.success(NotifyBridge.status(this))
                "notifAdvance" -> { NotifyBridge.advance(this, call.argument("since")); result.success(null) }
                "notifClear" -> { NotifyBridge.clear(this); result.success(null) }
                "openBatterySettings" -> { NotifyBridge.openBatterySettings(this); result.success(null) }
                "openNotifSettings" -> { NotifyBridge.openNotifSettings(this); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    // Notifikasi sistem ditahan saat aplikasi sedang terlihat (sama seperti versi lama)
    override fun onResume() { super.onResume(); NotifyBridge.setForeground(true) }
    override fun onPause() { super.onPause(); NotifyBridge.setForeground(false) }

    // PiP otomatis saat keluar aplikasi ketika sedang menonton.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipAllowed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            enterPictureInPictureMode(PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build())
    }
}

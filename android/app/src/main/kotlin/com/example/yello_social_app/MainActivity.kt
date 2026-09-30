package com.example.yello_social_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter engine, plus two small platform channels:
 *
 * - `yello/installer`, behind the in-app updater: Yello is installed from an
 *   APK rather than from a store, so the app downloads its own update and
 *   hands it to the OS package installer. See ADR-029 and
 *   `settings/data/datasources/apk_installer.dart`.
 * - `yello/call`, which keeps a call alive off screen ([CallService]) and
 *   the screen awake during a video call. See `core/call/call_keep_alive.dart`.
 *
 * Written here rather than pulled from pub.dev: each is a handful of
 * platform calls, and every package in either space bundles far more than
 * that (a download stack the app already has in `dio`; a general-purpose
 * background isolate the call does not need).
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startCallService" -> {
                val title = call.argument<String>("title")
                if (call.argument<Boolean>("screenCapture") == true) {
                    startForScreenCapture(title, result)
                } else {
                    result.success(startCallService(title, false))
                }
            }
            "stopCallService" -> {
                stopService(Intent(this, CallService::class.java))
                result.success(null)
            }
            "setKeepScreenOn" -> {
                if (call.argument<Boolean>("on") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * False when the service was not started: neither the microphone
     * permission nor a screen capture gives it a type to enter the
     * foreground with, or the app is not on screen (Android 8+ refuses a
     * background start). Starting it while it runs re-promotes it.
     */
    private fun startCallService(title: String?, screenCapture: Boolean): Boolean {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
        if (granted != PackageManager.PERMISSION_GRANTED && !screenCapture) return false
        return try {
            startService(
                Intent(this, CallService::class.java)
                    .putExtra(CallService.EXTRA_TITLE, title)
                    .putExtra(CallService.EXTRA_SCREEN_CAPTURE, screenCapture),
            )
            true
        } catch (e: Exception) {
            Log.w("YelloCallService", "Could not start the call service", e)
            false
        }
    }

    /**
     * Answers only once the service has actually entered the foreground with
     * the `mediaProjection` type — the capture Dart starts next is refused
     * until then — or after [PROMOTION_TIMEOUT_MS] without word.
     */
    private fun startForScreenCapture(title: String?, result: MethodChannel.Result) {
        val handler = Handler(Looper.getMainLooper())
        var answered = false
        lateinit var timeout: Runnable
        val answer = { promoted: Boolean ->
            if (!answered) {
                answered = true
                handler.removeCallbacks(timeout)
                CallService.onPromoted = null
                result.success(promoted)
            }
        }
        timeout = Runnable { answer(false) }
        CallService.onPromoted = answer
        if (!startCallService(title, true)) {
            answer(false)
            return
        }
        handler.postDelayed(timeout, PROMOTION_TIMEOUT_MS)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateDirectory" -> result.success(updateDirectory().absolutePath)
            "canInstallPackages" -> result.success(canInstallPackages())
            "openInstallPermissionSettings" -> {
                openInstallPermissionSettings()
                result.success(null)
            }
            "install" -> {
                val path = call.argument<String>("filePath")
                if (path.isNullOrEmpty()) {
                    result.error("no_file", "No APK path was given to install.", null)
                } else {
                    install(path, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * App-private cache, so no storage permission is involved and the OS
     * reclaims an abandoned download on its own. The FileProvider declared
     * in the manifest is what lets the installer read back out of it.
     */
    private fun updateDirectory(): File = File(cacheDir, UPDATE_DIR).apply { mkdirs() }

    /** Granted at install time below Android 8, per-app from 8 onwards. */
    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    /**
     * Returns false — not an error — when the permission above is still
     * off, which is the ordinary first run. Dart turns that into the
     * "Android needs your permission" state rather than a failure.
     */
    private fun install(path: String, result: MethodChannel.Result) {
        if (!canInstallPackages()) {
            result.success(false)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("missing_file", "The downloaded update is no longer on this device.", null)
            return
        }

        try {
            val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            startActivity(
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, APK_MIME)
                    // The installer is a different app: without the read
                    // grant it sees an unreadable file and reports the
                    // package as corrupt.
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("install_failed", e.message ?: "The installer could not be started.", null)
        }
    }

    private companion object {
        const val CHANNEL = "yello/installer"
        const val CALL_CHANNEL = "yello/call"
        const val PROMOTION_TIMEOUT_MS = 3000L
        const val UPDATE_DIR = "updates"
        const val APK_MIME = "application/vnd.android.package-archive"
    }
}

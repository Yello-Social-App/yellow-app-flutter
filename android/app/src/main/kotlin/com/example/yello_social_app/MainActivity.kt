package com.example.yello_social_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter engine, plus the `yello/installer` channel behind the
 * in-app updater: Yello is installed from an APK rather than from a store,
 * so the app downloads its own update and hands it to the OS package
 * installer. See ADR-029 and `settings/data/datasources/apk_installer.dart`.
 *
 * Written here rather than pulled from pub.dev: it is three intents and a
 * directory, and every package in this space bundles a download stack the
 * app already has in `dio`.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
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
        const val UPDATE_DIR = "updates"
        const val APK_MIME = "application/vnd.android.package-archive"
    }
}

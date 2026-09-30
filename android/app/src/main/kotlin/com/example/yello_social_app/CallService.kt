package com.example.yello_social_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.Manifest
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Keeps a call's microphone alive while Yello is not on screen.
 *
 * Android silences an app's microphone shortly after the app leaves the
 * foreground — the screen timing out mid-call is enough — unless it is
 * running a foreground service of type `microphone`. The service does
 * nothing else: WebRTC keeps capturing in the app's own process, and this
 * only changes how the OS ranks that process. Its notification is the
 * ongoing "call in progress" row the OS requires, and tapping it brings the
 * call back.
 *
 * Started and stopped by `CallKeepAlive` over the `yello/call` channel (see
 * [MainActivity]), always while the app is on screen. It is started with a
 * plain `startService` and promotes *itself* here, rather than through
 * `startForegroundService`: that call's contract is "promote within seconds
 * or the app is killed", and Android 14 refuses the promotion outright
 * unless RECORD_AUDIO is already granted — which it is not on a first call,
 * before WebRTC's own prompt. A refused promotion here just leaves a service
 * that stops itself; Dart asks again once the microphone is live.
 *
 * While the user shares their screen it also carries the `mediaProjection`
 * type ([EXTRA_SCREEN_CAPTURE]): without it Android refuses to hand WebRTC a
 * screen capture. Dart starts the service again with the flag set right
 * after the user allowed the capture — Android 14 refuses the type before
 * that — and again without it when the share stops; each start re-promotes
 * the running service with the new set of types.
 */
class CallService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Yello call"
        val type = foregroundType(intent?.getBooleanExtra(EXTRA_SCREEN_CAPTURE, false) == true)
        if (type == NO_TYPE) {
            stopSelf()
            reportPromotion(false)
            return START_NOT_STICKY
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(title), type)
            reportPromotion(true)
        } catch (e: Exception) {
            Log.w(TAG, "Could not enter the foreground for the call", e)
            stopSelf()
            reportPromotion(false)
        }
        // A call does not survive the process; nothing to restart into.
        return START_NOT_STICKY
    }

    private fun reportPromotion(promoted: Boolean) {
        val listener = onPromoted ?: return
        onPromoted = null
        listener(promoted)
    }

    /**
     * Only the types whose permission is already granted: asking for
     * `microphone` without RECORD_AUDIO is refused on Android 14, and would
     * take the screen share down with it.
     */
    private fun foregroundType(screenCapture: Boolean): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        var type = 0
        val micGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (micGranted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        if (screenCapture) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
        return if (type == 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) NO_TYPE else type
    }

    override fun onDestroy() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun notification(title: String): Notification {
        ensureChannel()
        val open = packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = open?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("Tap to return to the call")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(tap)
            .build()
    }

    /** Low importance: the row is a status, not an alert — it never sounds. */
    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Ongoing calls", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shown while a Yello call is in progress."
                setShowBadge(false)
            },
        )
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_SCREEN_CAPTURE = "screenCapture"
        private const val NO_TYPE = -1

        /**
         * Told once whether the next start entered the foreground. A start is
         * asynchronous — `startService` returns before [onStartCommand] runs —
         * and a screen capture must not begin until the `mediaProjection` type
         * is actually in place, so [MainActivity] waits on this. Main thread
         * only, like both of its callers.
         */
        var onPromoted: ((Boolean) -> Unit)? = null
        private const val TAG = "YelloCallService"
        private const val CHANNEL_ID = "yello_calls"
        private const val NOTIFICATION_ID = 7201
    }
}

package com.example.mobile

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var originalRingVolume: Int? = null
    private var originalNotificationVolume: Int? = null
    private var rampingHandler: Handler? = null
    private var rampingRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Desde Android 14 USE_FULL_SCREEN_INTENT ya no se concede sola:
                    // sin este acceso especial la alerta de trabajo nuevo degrada a
                    // un aviso normal y no enciende la pantalla.
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "openFullScreenIntentSettings" -> {
                        openFullScreenIntentSettings()
                        result.success(null)
                    }
                    "startRampingVolume" -> {
                        startRampingVolume()
                        result.success(null)
                    }
                    "restoreVolume" -> {
                        restoreVolume()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startRampingVolume() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return

        // Guardar volúmenes originales si no se han guardado antes
        if (originalRingVolume == null) {
            originalRingVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
        }
        if (originalNotificationVolume == null) {
            originalNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
        }

        val maxRing = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
        val maxNotif = audioManager.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION)

        stopRamping()

        var currentPercent = 0.40f
        fun applyVolume(percent: Float) {
            val ringTarget = (maxRing * percent).toInt().coerceAtLeast(1)
            val notifTarget = (maxNotif * percent).toInt().coerceAtLeast(1)
            try {
                audioManager.setStreamVolume(AudioManager.STREAM_RING, ringTarget, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, notifTarget, 0)
            } catch (_: Exception) {}
        }

        applyVolume(currentPercent)

        val handler = Handler(Looper.getMainLooper())
        rampingHandler = handler

        val runnable = object : Runnable {
            override fun run() {
                currentPercent += 0.20f
                if (currentPercent >= 1.0f) {
                    applyVolume(1.0f)
                    stopRamping()
                } else {
                    applyVolume(currentPercent)
                    handler.postDelayed(this, 1500)
                }
            }
        }
        rampingRunnable = runnable
        handler.postDelayed(runnable, 1500)
    }

    private fun stopRamping() {
        rampingRunnable?.let { rampingHandler?.removeCallbacks(it) }
        rampingHandler = null
        rampingRunnable = null
    }

    private fun restoreVolume() {
        stopRamping()
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            originalRingVolume?.let {
                audioManager.setStreamVolume(AudioManager.STREAM_RING, it, 0)
            }
            originalNotificationVolume?.let {
                audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, it, 0)
            }
        } catch (_: Exception) {}
        originalRingVolume = null
        originalNotificationVolume = null
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private companion object {
        const val CHANNEL = "chamba/system"
    }
}

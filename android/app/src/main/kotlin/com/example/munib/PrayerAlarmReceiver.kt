package com.example.munib

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class PrayerAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PRAYER_ALARM = "com.example.munib.PRAYER_ALARM"
        const val ACTION_STOP_ADHAN = "com.example.munib.STOP_ADHAN"
        const val ACTION_OPEN_MUNIB_GUARDED = "com.example.munib.OPEN_FROM_PRAYER_NOTIFICATION"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_LANGUAGE = "language"
        const val EXTRA_VOICE = "voice"
        const val EXTRA_SILENT = "silent"

        private const val CHANNEL_ID = "prayer_events_v2"
        private const val TAP_PREFS = "prayer_notification_taps"
        private const val DOUBLE_TAP_WINDOW_MS = 3_500L

        internal fun notification(
            context: Context,
            notificationId: Int,
            prayer: String,
            languageCode: String,
            playing: Boolean,
            silent: Boolean,
        ): android.app.Notification {
            ensureChannel(context)
            val ar = languageCode != "en"
            val localizedPrayer = when (prayer) {
                "Fajr" -> if (ar) "الفجر" else "Fajr"
                "Dhuhr" -> if (ar) "الظهر" else "Dhuhr"
                "Asr" -> if (ar) "العصر" else "Asr"
                "Maghrib" -> if (ar) "المغرب" else "Maghrib"
                "Isha" -> if (ar) "العشاء" else "Isha"
                else -> prayer
            }

            val guardedOpenIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                action = ACTION_OPEN_MUNIB_GUARDED
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_LANGUAGE, if (ar) "ar" else "en")
            }
            val guardedOpenPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId + 200_000,
                guardedOpenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val stopIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                action = ACTION_STOP_ADHAN
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            }
            val stopPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId + 100_000,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val title = if (ar) "حان وقت الصلاة" else "Prayer time"
            val body = if (ar) {
                "حان الآن وقت صلاة $localizedPrayer"
            } else {
                "It is time for $localizedPrayer"
            }

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(guardedOpenPendingIntent)
                .setDeleteIntent(stopPendingIntent)
                .setAutoCancel(false)
                .setOngoing(false)
                .setOnlyAlertOnce(true)
                .setSilent(silent || playing)
                .apply {
                    if (playing) {
                        addAction(
                            0,
                            if (ar) "إيقاف الأذان" else "Stop adhan",
                            stopPendingIntent,
                        )
                    }
                }
                .build()
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Munib Prayer Times",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    setSound(null, null)
                    description = "Prayer-time alerts from Munib"
                },
            )
        }

        private fun notificationsAllowed(context: Context): Boolean {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return false
            }
            return NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> PrayerAlarmScheduler.restore(context)

            ACTION_STOP_ADHAN -> {
                val id = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
                context.stopService(Intent(context, AdhanPlaybackService::class.java))
                if (id >= 0) NotificationManagerCompat.from(context).cancel(id)
            }

            ACTION_OPEN_MUNIB_GUARDED -> handleGuardedOpen(context, intent)
            ACTION_PRAYER_ALARM -> handlePrayerAlarm(context, intent)
        }
    }

    private fun handleGuardedOpen(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (id < 0) return

        val language = intent.getStringExtra(EXTRA_LANGUAGE) ?: "ar"
        val prefs = context.getSharedPreferences(TAP_PREFS, Context.MODE_PRIVATE)
        val key = "last_tap_$id"
        val now = SystemClock.elapsedRealtime()
        val lastTap = prefs.getLong(key, -1L)
        val elapsed = if (lastTap >= 0L) now - lastTap else Long.MAX_VALUE

        if (elapsed in 0..DOUBLE_TAP_WINDOW_MS) {
            prefs.edit().remove(key).apply()
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    )
                }
                ?: Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            context.startActivity(launchIntent)
            return
        }

        prefs.edit().putLong(key, now).apply()
        Toast.makeText(
            context,
            if (language == "en") "Tap again to open Munib" else "اضغط مرة أخرى للدخول لمنيب",
            Toast.LENGTH_SHORT,
        ).show()
    }

    private fun handlePrayerAlarm(context: Context, intent: Intent) {
        if (!notificationsAllowed(context)) return

        val id = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        val prayer = intent.getStringExtra(EXTRA_PRAYER)
        val language = intent.getStringExtra(EXTRA_LANGUAGE) ?: "ar"
        val voice = intent.getStringExtra(EXTRA_VOICE) ?: "Madinah"
        val silent = intent.getBooleanExtra(EXTRA_SILENT, false)
        if (id < 0 || prayer !in setOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")) {
            return
        }

        if (silent || voice == "None") {
            NotificationManagerCompat.from(context).notify(
                id,
                notification(
                    context = context,
                    notificationId = id,
                    prayer = prayer,
                    languageCode = language,
                    playing = false,
                    silent = true,
                ),
            )
            return
        }

        val service = Intent(context, AdhanPlaybackService::class.java).apply {
            putExtra(EXTRA_NOTIFICATION_ID, id)
            putExtra(EXTRA_PRAYER, prayer)
            putExtra(EXTRA_LANGUAGE, language)
            putExtra(EXTRA_VOICE, voice)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(service)
        } else {
            context.startService(service)
        }
    }
}

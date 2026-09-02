package com.example.munib

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.provider.Settings

internal object NafahatAlarmScheduler {
    private const val PREFS_NAME = "nafahat_prefs"
    private const val KEY_ENABLED = "nafahat_enabled_v1"
    private const val KEY_INTERVAL_MINUTES = "interval_minutes"
    private const val KEY_MORNING_AT = "morning_azkar_at"
    private const val KEY_EVENING_AT = "evening_azkar_at"
    private const val KEY_MORNING_ENABLED = "morning_azkar_enabled"
    private const val KEY_EVENING_ENABLED = "evening_azkar_enabled"

    private const val REQUEST_REGULAR = 91_270
    private const val REQUEST_MORNING = 91_271
    private const val REQUEST_EVENING = 91_272

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)

    fun canScheduleExactly(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    fun enable(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, true)
            .apply()
        rescheduleAll(context)
    }

    fun disable(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .apply()
        cancelAll(context)
    }

    fun restore(context: Context) {
        if (!isEnabled(context) || !canScheduleExactly(context)) {
            cancelAll(context)
            return
        }
        rescheduleAll(context)
    }

    fun rescheduleAll(context: Context) {
        cancelAll(context)
        if (!isEnabled(context) || !canScheduleExactly(context)) return
        scheduleNextRegular(context)
        scheduleAzkarAlarms(context)
    }

    fun onRegularAlarmFired(context: Context) {
        if (!isEnabled(context) || !canScheduleExactly(context)) return
        scheduleNextRegular(context)
    }

    fun scheduleAzkarAlarms(context: Context) {
        cancel(context, REQUEST_MORNING, NafahatAlarmReceiver.ACTION_MORNING)
        cancel(context, REQUEST_EVENING, NafahatAlarmReceiver.ACTION_EVENING)
        if (!isEnabled(context) || !canScheduleExactly(context)) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        scheduleAzkar(
            context = context,
            requestCode = REQUEST_MORNING,
            action = NafahatAlarmReceiver.ACTION_MORNING,
            enabled = prefs.getBoolean(KEY_MORNING_ENABLED, true),
            atMillis = prefs.getLong(KEY_MORNING_AT, 0L),
        )
        scheduleAzkar(
            context = context,
            requestCode = REQUEST_EVENING,
            action = NafahatAlarmReceiver.ACTION_EVENING,
            enabled = prefs.getBoolean(KEY_EVENING_ENABLED, true),
            atMillis = prefs.getLong(KEY_EVENING_AT, 0L),
        )
    }

    private fun scheduleNextRegular(context: Context) {
        cancel(context, REQUEST_REGULAR, NafahatAlarmReceiver.ACTION_REGULAR)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val intervalMinutes = prefs.getInt(KEY_INTERVAL_MINUTES, 30).coerceIn(10, 180)
        val triggerAt = SystemClock.elapsedRealtime() + intervalMinutes * 60_000L
        scheduleExact(
            context = context,
            type = AlarmManager.ELAPSED_REALTIME_WAKEUP,
            triggerAt = triggerAt,
            requestCode = REQUEST_REGULAR,
            action = NafahatAlarmReceiver.ACTION_REGULAR,
        )
    }

    private fun scheduleAzkar(
        context: Context,
        requestCode: Int,
        action: String,
        enabled: Boolean,
        atMillis: Long,
    ) {
        if (!enabled || atMillis <= 0L) return
        val triggerAt = atMillis.coerceAtLeast(System.currentTimeMillis() + 1_000L)
        scheduleExact(
            context = context,
            type = AlarmManager.RTC_WAKEUP,
            triggerAt = triggerAt,
            requestCode = requestCode,
            action = action,
        )
    }

    private fun scheduleExact(
        context: Context,
        type: Int,
        triggerAt: Long,
        requestCode: Int,
        action: String,
    ) {
        if (!canScheduleExactly(context)) return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(
            context,
            requestCode,
            action,
            PendingIntent.FLAG_UPDATE_CURRENT,
        ) ?: return

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(type, triggerAt, pending)
            } else {
                alarmManager.setExact(type, triggerAt, pending)
            }
        }
    }

    private fun cancelAll(context: Context) {
        cancel(context, REQUEST_REGULAR, NafahatAlarmReceiver.ACTION_REGULAR)
        cancel(context, REQUEST_MORNING, NafahatAlarmReceiver.ACTION_MORNING)
        cancel(context, REQUEST_EVENING, NafahatAlarmReceiver.ACTION_EVENING)
    }

    private fun cancel(
        context: Context,
        requestCode: Int,
        action: String,
    ) {
        val pending = pendingIntent(
            context,
            requestCode,
            action,
            PendingIntent.FLAG_NO_CREATE,
        ) ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pending)
        pending.cancel()
    }

    private fun pendingIntent(
        context: Context,
        requestCode: Int,
        action: String,
        modeFlag: Int,
    ): PendingIntent? {
        val intent = Intent(context, NafahatAlarmReceiver::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            modeFlag or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class NafahatAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_REGULAR = "com.example.munib.NAFAHAT_REGULAR_ALARM"
        const val ACTION_MORNING = "com.example.munib.NAFAHAT_MORNING_ALARM"
        const val ACTION_EVENING = "com.example.munib.NAFAHAT_EVENING_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                NafahatAlarmScheduler.restore(context)
            }

            ACTION_REGULAR -> {
                if (!NafahatAlarmScheduler.isEnabled(context)) return
                NafahatAlarmScheduler.onRegularAlarmFired(context)
                showBubble(context, NafahatBubbleService.ACTION_SHOW_REGULAR)
            }

            ACTION_MORNING,
            ACTION_EVENING -> {
                if (!NafahatAlarmScheduler.isEnabled(context)) return
                showBubble(context, NafahatBubbleService.ACTION_SHOW_AZKAR)
            }
        }
    }

    private fun showBubble(context: Context, action: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(context)
        ) {
            return
        }

        val service = Intent(context, NafahatBubbleService::class.java).apply {
            this.action = action
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        }
    }
}

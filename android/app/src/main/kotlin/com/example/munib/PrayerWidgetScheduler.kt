package com.example.munib

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

object PrayerWidgetScheduler {
    private data class PrayerPoint(val name: String, val atMillis: Long)

    fun refresh(context: Context) {
        val prefs = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()
        val next = readSchedule(prefs.getString("prayer_schedule_json", null))
            .firstOrNull { it.atMillis > now }

        if (next == null) {
            updateEmptyState(context)
            cancelAlarm(context)
            return
        }

        prefs.edit()
            .putString("next_prayer", next.name)
            .putLong("next_prayer_at", next.atMillis)
            .apply()

        updateWidgets(context, next, now)
        scheduleNextTransition(context, next.atMillis)
    }

    private fun readSchedule(raw: String?): List<PrayerPoint> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val item = array.optJSONObject(i) ?: continue
                    val name = item.optString("name")
                    val at = item.optLong("at", 0L)
                    if (name.isNotBlank() && at > 0L) add(PrayerPoint(name, at))
                }
            }.sortedBy { it.atMillis }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun updateWidgets(context: Context, next: PrayerPoint, now: Long) {
        val manager = AppWidgetManager.getInstance(context)
        updateProvider(context, manager, PrayerWidgetSmall::class.java, R.layout.widget_small, next, now)
        updateProvider(context, manager, PrayerWidgetMedium::class.java, R.layout.widget_medium, next, now)
        updateProvider(context, manager, PrayerWidgetLarge::class.java, R.layout.widget_large, next, now)
    }

    private fun updateProvider(
        context: Context,
        manager: AppWidgetManager,
        providerClass: Class<*>,
        layoutRes: Int,
        next: PrayerPoint,
        now: Long,
    ) {
        val ids = manager.getAppWidgetIds(ComponentName(context, providerClass))
        if (ids.isEmpty()) return

        for (id in ids) {
            val views = RemoteViews(context.packageName, layoutRes)
            views.setViewVisibility(R.id.widget_active_layout, View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty_layout, View.GONE)
            views.setTextViewText(R.id.widget_next_prayer, next.name.uppercase())

            val remaining = (next.atMillis - now).coerceAtLeast(0L)
            val chronometerBase = SystemClock.elapsedRealtime() + remaining
            views.setChronometer(R.id.widget_time_left, chronometerBase, null, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.widget_time_left, true)
            }

            val nextLower = next.name.lowercase()
            val bgRes = when (nextLower) {
                "fajr", "sunrise" -> R.drawable.widget_bg_fajr
                "dhuhr" -> R.drawable.widget_bg_dhuhr
                "asr" -> R.drawable.widget_bg_asr
                "maghrib" -> R.drawable.widget_bg_maghrib
                else -> R.drawable.widget_bg_isha
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", bgRes)

            if (layoutRes == R.layout.widget_medium) {
                val iconRes = when (nextLower) {
                    "fajr", "maghrib", "isha" -> R.drawable.ic_crescent
                    else -> R.drawable.ic_sun
                }
                views.setImageViewResource(R.id.widget_bg_icon, iconRes)
                val dhikrs = arrayOf(
                    "سبحان الله وبحمده",
                    "أستغفر الله وأتوب إليه",
                    "اللهم صل وسلم على نبينا محمد",
                    "لا حول ولا قوة إلا بالله",
                    "سبحان الله العظيم",
                )
                val index = ((now / 86_400_000L) % dhikrs.size).toInt()
                views.setTextViewText(R.id.widget_dhikr, dhikrs[index])
            }

            manager.updateAppWidget(id, views)
        }
    }

    private fun updateEmptyState(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val providers = listOf(
            Triple(PrayerWidgetSmall::class.java, R.layout.widget_small, "small"),
            Triple(PrayerWidgetMedium::class.java, R.layout.widget_medium, "medium"),
            Triple(PrayerWidgetLarge::class.java, R.layout.widget_large, "large"),
        )
        for ((provider, layout, _) in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            for (id in ids) {
                val views = RemoteViews(context.packageName, layout)
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                manager.updateAppWidget(id, views)
            }
        }
    }

    private fun scheduleNextTransition(context: Context, atMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidgetUpdateReceiver::class.java).apply {
            action = PrayerWidgetUpdateReceiver.ACTION_REFRESH
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            4107,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val triggerAt = atMillis + 1_500L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidgetUpdateReceiver::class.java).apply {
            action = PrayerWidgetUpdateReceiver.ACTION_REFRESH
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            4107,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }
}

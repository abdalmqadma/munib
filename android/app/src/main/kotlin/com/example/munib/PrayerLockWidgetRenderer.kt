package com.example.munib

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

object PrayerLockWidgetRenderer {
    private data class PrayerPoint(val name: String, val atMillis: Long)

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, PrayerLockWidget::class.java))
        if (ids.isEmpty()) {
            cancelAlarms(context)
            return
        }

        val prefs = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()
        val scheduleNext = readSchedule(prefs.getString("prayer_schedule_json", null))
            .firstOrNull { it.atMillis > now }
        val cachedName = prefs.getString("next_prayer", null)
        val cachedAt = prefs.getLong("next_prayer_at", 0L)
        val cachedNext = if (!cachedName.isNullOrBlank() && cachedAt > now) {
            PrayerPoint(cachedName, cachedAt)
        } else {
            null
        }
        val next = scheduleNext ?: cachedNext

        if (next == null) {
            updateEmptyState(context, manager, ids)
            cancelAlarms(context)
            return
        }

        updateActiveState(context, manager, ids, next, now)
        scheduleNextTransition(context, next.atMillis)
        scheduleMinuteRefresh(context, now)
    }

    fun disable(context: Context) {
        cancelAlarms(context)
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

    private fun updateActiveState(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        next: PrayerPoint,
        now: Long,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val language = prefs.getString("widget_language", "ar") ?: "ar"
        val isArabic = language.lowercase().startsWith("ar")
        val prayerName = localizePrayer(next.name, isArabic)
        val remaining = (next.atMillis - now).coerceAtLeast(0L)
        val chronometerBase = SystemClock.elapsedRealtime() + remaining
        val openApp = launchPendingIntent(context)

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_lock)
            views.setViewVisibility(R.id.widget_lock_active, View.VISIBLE)
            views.setViewVisibility(R.id.widget_lock_empty, View.GONE)
            views.setTextViewText(R.id.widget_lock_prayer, prayerName)
            views.setTextViewText(R.id.widget_lock_dhikr, shortDhikr(now, isArabic))
            views.setChronometer(R.id.widget_lock_countdown, chronometerBase, null, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.widget_lock_countdown, true)
            }
            views.setOnClickPendingIntent(R.id.widget_lock_root, openApp)
            applyAdaptiveLockColors(views)
            manager.updateAppWidget(id, views)
        }
    }

    private fun updateEmptyState(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val language = prefs.getString("widget_language", "ar") ?: "ar"
        val isArabic = language.lowercase().startsWith("ar")
        val message = if (isArabic) {
            "افتح منيب لتحميل المواقيت"
        } else {
            "Open Munib to load prayer times"
        }
        val openApp = launchPendingIntent(context)

        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_lock)
            views.setViewVisibility(R.id.widget_lock_active, View.GONE)
            views.setViewVisibility(R.id.widget_lock_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_lock_empty, message)
            views.setOnClickPendingIntent(R.id.widget_lock_root, openApp)
            applyAdaptiveLockColors(views)
            manager.updateAppWidget(id, views)
        }
    }

    private fun applyAdaptiveLockColors(views: RemoteViews) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorAttr(
                R.id.widget_lock_prayer,
                "setTextColor",
                android.R.attr.textColorPrimary,
            )
            views.setColorAttr(
                R.id.widget_lock_separator,
                "setTextColor",
                android.R.attr.textColorPrimary,
            )
            views.setColorAttr(
                R.id.widget_lock_countdown,
                "setTextColor",
                android.R.attr.textColorPrimary,
            )
            views.setColorAttr(
                R.id.widget_lock_dhikr,
                "setTextColor",
                android.R.attr.textColorSecondary,
            )
            views.setColorAttr(
                R.id.widget_lock_empty,
                "setTextColor",
                android.R.attr.textColorPrimary,
            )
            return
        }

        views.setTextColor(R.id.widget_lock_prayer, Color.WHITE)
        views.setTextColor(R.id.widget_lock_separator, Color.WHITE)
        views.setTextColor(R.id.widget_lock_countdown, Color.WHITE)
        views.setTextColor(R.id.widget_lock_dhikr, Color.argb(204, 255, 255, 255))
        views.setTextColor(R.id.widget_lock_empty, Color.WHITE)
    }

    private fun localizePrayer(name: String, isArabic: Boolean): String {
        if (!isArabic) return name
        return when (name.lowercase()) {
            "fajr" -> "الفجر"
            "sunrise" -> "الشروق"
            "dhuhr" -> "الظهر"
            "asr" -> "العصر"
            "maghrib" -> "المغرب"
            "isha" -> "العشاء"
            else -> name
        }
    }

    private fun shortDhikr(now: Long, isArabic: Boolean): String {
        val arabic = arrayOf(
            "سبحان الله",
            "الحمد لله",
            "الله أكبر",
            "أستغفر الله",
            "حسبي الله",
        )
        val english = arrayOf(
            "Glory to Allah",
            "Praise be to Allah",
            "Allah is Greatest",
            "I seek forgiveness",
            "Allah is sufficient",
        )
        val list = if (isArabic) arabic else english
        val minute = now / 60_000L
        return list[(minute % list.size).toInt()]
    }

    private fun launchPendingIntent(context: Context): PendingIntent {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            ?: Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context,
            4209,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleNextTransition(context: Context, atMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = refreshPendingIntent(context, 4207)
        val triggerAt = atMillis + 1_500L
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                alarmManager.canScheduleExactAlarms() -> {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
            else -> alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun scheduleMinuteRefresh(context: Context, now: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = refreshPendingIntent(context, 4208)
        val nextMinute = ((now / 60_000L) + 1L) * 60_000L + 250L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
        }
    }

    private fun refreshPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, PrayerLockWidgetUpdateReceiver::class.java).apply {
            action = PrayerLockWidgetUpdateReceiver.ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cancelAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (requestCode in listOf(4207, 4208)) {
            val intent = Intent(context, PrayerLockWidgetUpdateReceiver::class.java).apply {
                action = PrayerLockWidgetUpdateReceiver.ACTION_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            ) ?: continue
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }
}

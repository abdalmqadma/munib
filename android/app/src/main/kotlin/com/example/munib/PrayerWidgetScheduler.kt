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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object PrayerWidgetScheduler {
    private data class PrayerPoint(val name: String, val atMillis: Long)

    fun refresh(context: Context) {
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
            updateEmptyState(context)
            cancelAlarms(context)
            return
        }

        prefs.edit()
            .putString("next_prayer", next.name)
            .putLong("next_prayer_at", next.atMillis)
            .apply()

        updateWidgets(context, next, now)
        scheduleNextTransition(context, next.atMillis)
        scheduleMinuteRefresh(context, now)
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

        val prefs = HomeWidgetPlugin.getData(context)
        val language = prefs.getString("widget_language", "ar") ?: "ar"
        val isArabic = language.lowercase().startsWith("ar")
        val use24Hour = prefs.getBoolean("widget_use_24h", true)
        val timeZoneId = prefs.getString("widget_timezone", null)?.trim().orEmpty()
        val selectedTimeZone = if (
            timeZoneId.isNotEmpty() && TimeZone.getAvailableIDs().contains(timeZoneId)
        ) {
            TimeZone.getTimeZone(timeZoneId)
        } else {
            TimeZone.getDefault()
        }
        val locationName = prefs.getString("widget_location", "")?.trim().orEmpty()
        val localizedName = localizePrayer(next.name, isArabic)
        val locale = if (isArabic) Locale("ar") else Locale.ENGLISH
        val dateFormat = SimpleDateFormat("EEE d MMMM", locale).apply {
            timeZone = selectedTimeZone
        }
        val isMorning = Calendar.getInstance(selectedTimeZone).run {
            timeInMillis = now
            get(Calendar.AM_PM) == Calendar.AM
        }
        val timePattern = when {
            use24Hour -> "HH:mm"
            isArabic && isMorning -> "h:mm 'ص'"
            isArabic -> "h:mm 'م'"
            else -> "h:mm a"
        }
        val timeFormat = SimpleDateFormat(timePattern, locale).apply {
            timeZone = selectedTimeZone
        }
        val dhikr = minuteDhikr(now, isArabic)
        val nextLabel = if (isArabic) "الصلاة التالية" else "Next prayer"
        val remainingLabel = if (isArabic) "متبقي" else "remaining"
        val openApp = launchPendingIntent(context)

        val nextLower = next.name.lowercase()
        val iconRes = when (nextLower) {
            "fajr", "maghrib", "isha" -> R.drawable.ic_crescent
            else -> R.drawable.ic_sun
        }

        for (id in ids) {
            val views = RemoteViews(context.packageName, layoutRes)
            views.setViewVisibility(R.id.widget_active_layout, View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty_layout, View.GONE)

            views.setTextViewText(R.id.widget_next_label, nextLabel)
            views.setTextViewText(
                R.id.widget_next_prayer,
                if (isArabic) localizedName else localizedName.uppercase(),
            )
            views.setTextViewText(R.id.widget_remaining_label, remainingLabel)
            views.setTextViewText(R.id.widget_dhikr, dhikr)
            views.setTextViewText(R.id.widget_date, dateFormat.format(Date(now)))
            if (layoutRes == R.layout.widget_large) {
                views.setCharSequence(R.id.widget_current_time, "setFormat12Hour", timePattern)
                views.setCharSequence(R.id.widget_current_time, "setFormat24Hour", timePattern)
                views.setString(R.id.widget_current_time, "setTimeZone", selectedTimeZone.id)
                views.setTextViewText(
                    R.id.widget_location,
                    locationName.ifBlank {
                        if (isArabic) "الموقع غير محدد" else "Location not set"
                    },
                )
            } else {
                views.setTextViewText(R.id.widget_current_time, timeFormat.format(Date(now)))
            }
            views.setImageViewResource(R.id.widget_bg_icon, iconRes)
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_glass_background)
            views.setOnClickPendingIntent(R.id.widget_root, openApp)

            val remaining = (next.atMillis - now).coerceAtLeast(0L)
            val chronometerBase = SystemClock.elapsedRealtime() + remaining
            views.setChronometer(R.id.widget_time_left, chronometerBase, null, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.widget_time_left, true)
            }

            manager.updateAppWidget(id, views)
        }
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

    private fun minuteDhikr(now: Long, isArabic: Boolean): String {
        val arabic = arrayOf(
            "سبحان الله وبحمده",
            "أستغفر الله وأتوب إليه",
            "لا حول ولا قوة إلا بالله",
            "اللهم صل وسلم على نبينا محمد",
            "سبحان الله العظيم",
            "الحمد لله رب العالمين",
            "لا إله إلا الله وحده لا شريك له",
            "حسبي الله ونعم الوكيل",
        )
        val english = arrayOf(
            "Glory be to Allah and praise be to Him",
            "I seek Allah's forgiveness and repent to Him",
            "There is no power nor strength except through Allah",
            "O Allah, send peace and blessings upon Muhammad",
            "Glory be to Allah, the Magnificent",
            "All praise is due to Allah",
            "There is no god but Allah alone",
            "Allah is sufficient for me and the best Disposer of affairs",
        )
        val list = if (isArabic) arabic else english
        val minute = now / 60_000L
        return list[(minute % list.size).toInt()]
    }

    private fun updateEmptyState(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val prefs = HomeWidgetPlugin.getData(context)
        val language = prefs.getString("widget_language", "ar") ?: "ar"
        val isArabic = language.lowercase().startsWith("ar")
        val message = if (isArabic) {
            "افتح التطبيق مرة واحدة لتحميل المواقيت"
        } else {
            "Open Munib once to load prayer times"
        }
        val providers = listOf(
            Pair(PrayerWidgetSmall::class.java, R.layout.widget_small),
            Pair(PrayerWidgetMedium::class.java, R.layout.widget_medium),
            Pair(PrayerWidgetLarge::class.java, R.layout.widget_large),
        )
        val openApp = launchPendingIntent(context)
        for ((provider, layout) in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            for (id in ids) {
                val views = RemoteViews(context.packageName, layout)
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_glass_background)
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_message, message)
                views.setOnClickPendingIntent(R.id.widget_root, openApp)
                manager.updateAppWidget(id, views)
            }
        }
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
            4109,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleNextTransition(context: Context, atMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = refreshPendingIntent(context, 4107)
        val triggerAt = atMillis + 1_500L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun scheduleMinuteRefresh(context: Context, now: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = refreshPendingIntent(context, 4108)
        val nextMinute = ((now / 60_000L) + 1L) * 60_000L + 250L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
        }
    }

    private fun refreshPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, PrayerWidgetUpdateReceiver::class.java).apply {
            action = PrayerWidgetUpdateReceiver.ACTION_REFRESH
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
        for (requestCode in listOf(4107, 4108)) {
            val intent = Intent(context, PrayerWidgetUpdateReceiver::class.java).apply {
                action = PrayerWidgetUpdateReceiver.ACTION_REFRESH
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

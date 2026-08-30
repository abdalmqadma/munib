package com.example.munib

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

internal data class PrayerAlarmSpec(
    val id: Int,
    val atMillis: Long,
    val prayer: String,
    val languageCode: String,
    val voice: String,
    val silent: Boolean,
)

internal object PrayerAlarmScheduler {
    private const val PREFS_NAME = "prayer_alarm_prefs"
    private const val KEY_SPECS = "scheduled_prayer_alarms_v1"
    private const val MIN_ID = 60_000
    private const val MAX_ID = 99_999
    private const val MAX_ALARMS = 180

    fun sync(context: Context, specs: List<PrayerAlarmSpec>) {
        cancelAll(context)
        val now = System.currentTimeMillis()
        val safeSpecs = specs
            .asSequence()
            .filter { it.id in MIN_ID..MAX_ID }
            .filter { it.atMillis > now }
            .filter { it.prayer in setOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha") }
            .filter { it.languageCode == "ar" || it.languageCode == "en" }
            .filter { it.voice in setOf("Madinah", "Meccan", "None") }
            .distinctBy { it.id }
            .take(MAX_ALARMS)
            .toList()

        persist(context, safeSpecs)
        scheduleInternal(context, safeSpecs)
    }

    fun restore(context: Context) {
        val specs = readPersisted(context)
            .filter { it.atMillis > System.currentTimeMillis() }
        if (specs.isEmpty()) return
        persist(context, specs)
        scheduleInternal(context, specs)
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (spec in readPersisted(context)) {
            val pending = pendingIntent(context, spec, PendingIntent.FLAG_NO_CREATE)
                ?: continue
            alarmManager.cancel(pending)
            pending.cancel()
        }
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SPECS)
            .apply()
    }

    private fun scheduleInternal(context: Context, specs: List<PrayerAlarmSpec>) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (spec in specs) {
            val pending = pendingIntent(context, spec, PendingIntent.FLAG_UPDATE_CURRENT)
                ?: continue
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    alarmManager.canScheduleExactAlarms() -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        spec.atMillis,
                        pending,
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        spec.atMillis,
                        pending,
                    )
                }
                else -> {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, spec.atMillis, pending)
                }
            }
        }
    }

    private fun pendingIntent(
        context: Context,
        spec: PrayerAlarmSpec,
        modeFlag: Int,
    ): PendingIntent? {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = PrayerAlarmReceiver.ACTION_PRAYER_ALARM
            putExtra(PrayerAlarmReceiver.EXTRA_NOTIFICATION_ID, spec.id)
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER, spec.prayer)
            putExtra(PrayerAlarmReceiver.EXTRA_LANGUAGE, spec.languageCode)
            putExtra(PrayerAlarmReceiver.EXTRA_VOICE, spec.voice)
            putExtra(PrayerAlarmReceiver.EXTRA_SILENT, spec.silent)
        }
        val flags = modeFlag or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, spec.id, intent, flags)
    }

    private fun persist(context: Context, specs: List<PrayerAlarmSpec>) {
        val json = JSONArray()
        specs.forEach { spec ->
            json.put(JSONObject().apply {
                put("id", spec.id)
                put("at", spec.atMillis)
                put("prayer", spec.prayer)
                put("language", spec.languageCode)
                put("voice", spec.voice)
                put("silent", spec.silent)
            })
        }
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SPECS, json.toString())
            .apply()
    }

    private fun readPersisted(context: Context): List<PrayerAlarmSpec> {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SPECS, null)
            ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val id = item.optInt("id", -1)
                    val at = item.optLong("at", 0L)
                    val prayer = item.optString("prayer")
                    val language = item.optString("language", "ar")
                    val voice = item.optString("voice", "Madinah")
                    val silent = item.optBoolean("silent", false)
                    if (id !in MIN_ID..MAX_ID || at <= 0L) continue
                    if (prayer !in setOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")) continue
                    add(
                        PrayerAlarmSpec(
                            id = id,
                            atMillis = at,
                            prayer = prayer,
                            languageCode = if (language == "en") "en" else "ar",
                            voice = if (voice in setOf("Madinah", "Meccan", "None")) voice else "Madinah",
                            silent = silent,
                        ),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}

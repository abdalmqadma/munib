package com.example.munib

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val nafahatChannelName = "com.example.munib/nafahat"
    private val adhanChannelName = "com.example.munib/adhan"
    private val prefsName = "nafahat_prefs"
    private var pendingAzkarCategory: String? = null
    private var startNafahatAfterOverlayPermission = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureAzkarNavigation(intent)
        configureNafahatChannel(flutterEngine)
        configureAdhanChannel(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        if (!startNafahatAfterOverlayPermission) return
        startNafahatAfterOverlayPermission = false
        if (canDrawOverlays()) startNafahatService()
    }

    private fun configureNafahatChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nafahatChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !canDrawOverlays()) {
                            startNafahatAfterOverlayPermission = true
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } else {
                            startNafahatService()
                        }
                        result.success(true)
                    }
                    "startNafahat" -> startNafahat(result)
                    "stopNafahat" -> {
                        stopService(Intent(this, NafahatBubbleService::class.java))
                        result.success(true)
                    }
                    "isNafahatRunning" -> result.success(NafahatBubbleService.isRunning)
                    "getNafahatSettings" -> result.success(readNafahatSettings())
                    "setNafahatSettings" -> {
                        saveNafahatSettings(
                            enabledKinds = call.argument<List<String>>("enabledKinds"),
                            intervalMinutes = call.argument<Int>("intervalMinutes"),
                            contextualMode = call.argument<Boolean>("contextualMode"),
                        )
                        refreshNafahatIfRunning()
                        result.success(true)
                    }
                    "setNafahatAppearance" -> {
                        val themeMode = call.argument<String>("themeMode")
                            ?.takeIf { it in setOf("system", "light", "dark") }
                            ?: "system"
                        getSharedPreferences(prefsName, MODE_PRIVATE)
                            .edit()
                            .putString("theme_mode", themeMode)
                            .apply()
                        refreshNafahatIfRunning()
                        result.success(true)
                    }
                    "setAzkarNafahatSchedule" -> {
                        saveAzkarSchedule(
                            morningEnabled = call.argument<Boolean>("morningEnabled") ?: true,
                            morningAt = call.argument<Number>("morningAt")?.toLong() ?: 0L,
                            eveningEnabled = call.argument<Boolean>("eveningEnabled") ?: true,
                            eveningAt = call.argument<Number>("eveningAt")?.toLong() ?: 0L,
                        )
                        refreshNafahatIfRunning()
                        result.success(true)
                    }
                    "queueAzkarNavigation" -> {
                        val category = call.argument<String>("category")
                            ?.takeIf { it == "Morning" || it == "Evening" }
                        pendingAzkarCategory = category
                        result.success(category != null)
                    }
                    "consumePendingAzkarNavigation" -> {
                        val category = pendingAzkarCategory
                        pendingAzkarCategory = null
                        result.success(category)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun configureAdhanChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, adhanChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareAdhanVoice" -> {
                        val voice = call.argument<String>("voice")
                        if (voice !in setOf("Madinah", "Meccan")) {
                            result.error("invalid_voice", "Unsupported adhan voice", null)
                            return@setMethodCallHandler
                        }
                        AdhanPlaybackService.prepareVoice(this, voice!!)
                        result.success(true)
                    }
                    "syncPrayerAlarms" -> {
                        val language = call.argument<String>("languageCode")
                            ?.takeIf { it == "en" }
                            ?: "ar"
                        val voice = call.argument<String>("voice")
                            ?.takeIf { it in setOf("Madinah", "Meccan", "None") }
                            ?: "Madinah"
                        val silent = call.argument<Boolean>("silent") ?: false
                        val rawAlarms = call.argument<List<*>>("alarms").orEmpty()
                        val specs = rawAlarms.mapNotNull { raw ->
                            val map = raw as? Map<*, *> ?: return@mapNotNull null
                            val id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null
                            val at = (map["at"] as? Number)?.toLong() ?: return@mapNotNull null
                            val prayer = map["prayer"] as? String ?: return@mapNotNull null
                            PrayerAlarmSpec(
                                id = id,
                                atMillis = at,
                                prayer = prayer,
                                languageCode = language,
                                voice = voice,
                                silent = silent,
                            )
                        }
                        PrayerAlarmScheduler.sync(this, specs)
                        if (!silent && voice != "None") {
                            AdhanPlaybackService.prepareVoice(this, voice)
                        }
                        result.success(true)
                    }
                    "cancelPrayerAlarms" -> {
                        PrayerAlarmScheduler.cancelAll(this)
                        stopService(Intent(this, AdhanPlaybackService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAzkarNavigation(intent)
    }

    private fun captureAzkarNavigation(intent: Intent?) {
        val category = intent?.getStringExtra(NafahatBubbleService.EXTRA_OPEN_AZKAR_CATEGORY)
        pendingAzkarCategory = category?.takeIf { it == "Morning" || it == "Evening" }
    }

    private fun startNafahat(result: MethodChannel.Result) {
        if (!canDrawOverlays()) {
            result.error("overlay_permission", "Overlay permission is required", null)
            return
        }
        startNafahatService()
        result.success(true)
    }

    private fun startNafahatService() {
        if (NafahatBubbleService.isRunning) return
        val intent = Intent(this, NafahatBubbleService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
    }

    private fun readNafahatSettings(): Map<String, Any> {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        return mapOf(
            "enabledKinds" to (prefs.getStringSet("enabled_kinds", null)
                ?: setOf("آية", "حديث", "ذكر", "أثر طيب")).toList(),
            "intervalMinutes" to prefs.getInt("interval_minutes", 30),
            "contextualMode" to prefs.getBoolean("contextual_mode", true),
            "themeMode" to (prefs.getString("theme_mode", "system") ?: "system"),
        )
    }

    private fun saveNafahatSettings(
        enabledKinds: List<String>?,
        intervalMinutes: Int?,
        contextualMode: Boolean?,
    ) {
        val kinds = enabledKinds
            ?.filter { it in setOf("آية", "حديث", "ذكر", "أثر طيب") }
            ?.toSet()
            ?.takeIf { it.isNotEmpty() }
            ?: setOf("آية", "حديث", "ذكر", "أثر طيب")
        val interval = (intervalMinutes ?: 30).coerceIn(10, 180)

        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putStringSet("enabled_kinds", kinds)
            .putInt("interval_minutes", interval)
            .putBoolean("contextual_mode", contextualMode ?: true)
            .apply()
    }

    private fun saveAzkarSchedule(
        morningEnabled: Boolean,
        morningAt: Long,
        eveningEnabled: Boolean,
        eveningAt: Long,
    ) {
        val now = System.currentTimeMillis()
        val maxFuture = now + 48L * 60L * 60L * 1000L
        val safeMorning = morningAt.takeIf { it in 1..maxFuture } ?: 0L
        val safeEvening = eveningAt.takeIf { it in 1..maxFuture } ?: 0L
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putBoolean("morning_azkar_enabled", morningEnabled)
            .putLong("morning_azkar_at", safeMorning)
            .putBoolean("evening_azkar_enabled", eveningEnabled)
            .putLong("evening_azkar_at", safeEvening)
            .apply()
    }

    private fun refreshNafahatIfRunning() {
        if (!NafahatBubbleService.isRunning) return
        val refresh = Intent(this, NafahatBubbleService::class.java).apply {
            action = NafahatBubbleService.ACTION_REFRESH_SETTINGS
        }
        // This call comes from the foreground activity and targets the already
        // running service, so it refreshes timers without reposting its notice.
        startService(refresh)
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
}

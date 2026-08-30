package com.example.munib

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.munib/nafahat"
    private val prefsName = "nafahat_prefs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
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
                    else -> result.notImplemented()
                }
            }
    }

    private fun startNafahat(result: MethodChannel.Result) {
        if (!canDrawOverlays()) {
            result.error("overlay_permission", "Overlay permission is required", null)
            return
        }
        val intent = Intent(this, NafahatBubbleService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
        result.success(true)
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

    private fun refreshNafahatIfRunning() {
        if (!NafahatBubbleService.isRunning) return
        val refresh = Intent(this, NafahatBubbleService::class.java).apply {
            action = NafahatBubbleService.ACTION_REFRESH_SETTINGS
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(refresh)
        else startService(refresh)
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
}

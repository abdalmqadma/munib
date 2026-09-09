package com.example.munib

import android.animation.ValueAnimator
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.hypot

class NafahatBubbleService : Service() {
    companion object {
        @Volatile
        var isRunning: Boolean = false

        const val ACTION_REFRESH_SETTINGS = "com.example.munib.NAFAHAT_REFRESH_SETTINGS"
        const val ACTION_SHOW_REGULAR = "com.example.munib.NAFAHAT_SHOW_REGULAR"
        const val ACTION_SHOW_AZKAR = "com.example.munib.NAFAHAT_SHOW_AZKAR"
        const val EXTRA_FIRST_RUN = "nafahat_first_run"
        const val EXTRA_OPEN_AZKAR_CATEGORY = "open_azkar_category"

        private const val CHANNEL_ID = "nafahat_service_quiet_v2"
        private const val NOTIFICATION_ID = 9127
        private const val PREFS_NAME = "nafahat_prefs"
        private const val KEY_MORNING_AT = "morning_azkar_at"
        private const val KEY_EVENING_AT = "evening_azkar_at"
        private const val KEY_MORNING_ENABLED = "morning_azkar_enabled"
        private const val KEY_EVENING_ENABLED = "evening_azkar_enabled"
        private const val KEY_LAST_MORNING_DAY = "last_morning_azkar_day"
        private const val KEY_LAST_EVENING_DAY = "last_evening_azkar_day"
        private const val KEY_CONTENT_INDEX = "last_content_index"
        private const val MORNING_AFTER_FAJR_MINUTES = 15L

        private val GOLD = Color.rgb(244, 199, 106)
        private val GOLD_DARK = Color.rgb(157, 112, 30)
        private val DARK_BUBBLE = Color.rgb(11, 31, 58)
        private val DARK_BORDER = Color.rgb(62, 82, 106)
        private val DARK_MUTED = Color.rgb(169, 176, 181)
        private val LIGHT_SURFACE = Color.rgb(247, 244, 238)
        private val LIGHT_BORDER = Color.rgb(218, 211, 199)
        private val LIGHT_TEXT = Color.rgb(29, 35, 42)
        private val LIGHT_MUTED = Color.rgb(99, 105, 113)
    }

    private val items = NafahatContentRepository.items

    private lateinit var wm: WindowManager
    private lateinit var bubble: TextView
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var bubbleAttached = false
    private var card: LinearLayout? = null
    private var deleteTarget: TextView? = null
    private var deleteTargetParams: WindowManager.LayoutParams? = null
    private var deleteTargetAttached = false
    private var deleteTargetVisible = false
    private var snapAnimator: ValueAnimator? = null
    private var index = 0
    private var unread = true
    private var activeAzkarCategory: String? = null
    private var cardWasVisibleBeforeDrag = false

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForegroundNotification()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        index = prefs().getInt(KEY_CONTENT_INDEX, 0).coerceIn(0, items.lastIndex)
        createBubbleIfNeeded()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!NafahatAlarmScheduler.isEnabled(this) ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                !Settings.canDrawOverlays(this))
        ) {
            finishBubbleSession()
            return START_NOT_STICKY
        }

        when (intent?.action) {
            ACTION_REFRESH_SETTINGS -> {
                if (items[index].kind !in enabledKinds()) {
                    selectContent(firstRun = false)
                }
                applyBubbleStyle()
                updateCard()
            }
            ACTION_SHOW_AZKAR -> {
                val shown = presentDueAzkarPrompt()
                NafahatAlarmScheduler.scheduleAzkarAlarms(this)
                if (!shown) finishBubbleSession()
            }
            else -> {
                presentRegularContent(
                    firstRun = intent?.getBooleanExtra(EXTRA_FIRST_RUN, false) == true,
                )
            }
        }
        return START_NOT_STICKY
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (themeMode() == "system") {
            applyBubbleStyle()
            updateCard()
        }
    }

    override fun onDestroy() {
        snapAnimator?.cancel()
        removeCard()
        removeDeleteTarget()
        if (bubbleAttached) runCatching { wm.removeView(bubble) }
        bubbleAttached = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun prefs() = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

    private fun contextualMode(): Boolean = prefs().getBoolean("contextual_mode", true)

    private fun themeMode(): String = prefs().getString("theme_mode", "system") ?: "system"

    private fun enabledKinds(): Set<String> =
        prefs().getStringSet("enabled_kinds", null)?.takeIf { it.isNotEmpty() }
            ?: setOf("آية", "حديث", "ذكر", "أثر طيب")

    private fun filteredItems(): List<NafhaContent> =
        items.filter { it.kind in enabledKinds() }.ifEmpty { items }

    private fun presentRegularContent(firstRun: Boolean = false) {
        activeAzkarCategory = null
        selectContent(firstRun)
        showCurrentNafha()
    }

    private fun presentDueAzkarPrompt(): Boolean {
        val now = System.currentTimeMillis()
        normalizeExpiredAzkarAt("Morning", now)
        normalizeExpiredAzkarAt("Evening", now)
        val special = dueAzkarCategory(now) ?: return false
        activeAzkarCategory = special
        markAzkarPromptShown(special)
        showCurrentNafha()
        return true
    }

    private fun selectContent(firstRun: Boolean) {
        val available = filteredItems()
        if (contextualMode()) {
            val tag = currentContextTag()
            val contextual = available.filter { tag != null && it.contextTag == tag }
            if (contextual.isNotEmpty()) {
                val selected = contextual.firstOrNull { items.indexOf(it) != index }
                    ?: contextual.first()
                index = items.indexOf(selected).coerceAtLeast(0)
                persistContentIndex()
                return
            }
        }
        if (firstRun) {
            index = items.indexOf(available.first()).coerceAtLeast(0)
        } else {
            selectNextItem()
        }
        persistContentIndex()
    }

    private fun persistContentIndex() {
        prefs().edit().putInt(KEY_CONTENT_INDEX, index).apply()
    }

    private fun selectNextItem() {
        val available = filteredItems()
        val currentPosition = available.indexOf(items[index])
        val nextPosition = if (currentPosition >= 0) currentPosition + 1 else 0
        val selected = available[nextPosition % available.size]
        index = items.indexOf(selected).coerceAtLeast(0)
    }

    private fun currentContextTag(): String? {
        val calendar = Calendar.getInstance(selectedTimeZone())
        if (calendar.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY) return "friday"
        val untilPrayer = millisUntilNextPrayer()
        if (untilPrayer != null && untilPrayer in 1..(20 * 60_000L)) return "pre_prayer"
        return when (calendar.get(Calendar.HOUR_OF_DAY)) {
            in 5..10 -> "morning"
            in 17..22 -> "evening"
            else -> null
        }
    }

    private fun selectedTimeZone(): TimeZone {
        val id = widgetPrefs().getString("widget_timezone", null)?.trim().orEmpty()
        return if (id.isNotEmpty() && TimeZone.getAvailableIDs().contains(id)) {
            TimeZone.getTimeZone(id)
        } else {
            TimeZone.getDefault()
        }
    }

    private fun millisUntilNextPrayer(): Long? = try {
        val raw = widgetPrefs().getString("prayer_schedule_json", null) ?: return null
        val now = System.currentTimeMillis()
        val array = JSONArray(raw)
        var closest: Long? = null
        for (i in 0 until array.length()) {
            val at = array.optJSONObject(i)?.optLong("at", 0L) ?: continue
            if (at > now && (closest == null || at < closest!!)) closest = at
        }
        closest?.minus(now)
    } catch (_: Exception) {
        null
    }

    private fun dueAzkarCategory(now: Long): String? {
        for (category in listOf("Morning", "Evening")) {
            val at = azkarAt(category)
            if (!azkarEnabled(category) || at <= 0L) continue
            val sameDay = dayKey(at) == dayKey(now)
            val alreadyShown = lastShownDay(category) == dayKey(now)
            if (sameDay && !alreadyShown && now >= at) return category
        }
        return null
    }

    private fun nextUnshownAzkarAt(category: String, now: Long): Long? {
        if (!azkarEnabled(category)) return null
        val at = azkarAt(category)
        if (at <= now) return null
        return if (lastShownDay(category) == dayKey(at)) null else at
    }

    private fun azkarEnabled(category: String): Boolean = when (category) {
        "Morning" -> prefs().getBoolean(KEY_MORNING_ENABLED, true)
        else -> prefs().getBoolean(KEY_EVENING_ENABLED, true)
    }

    private fun azkarAt(category: String): Long = when (category) {
        "Morning" -> prefs().getLong(KEY_MORNING_AT, 0L)
        else -> prefs().getLong(KEY_EVENING_AT, 0L)
    }

    private fun azkarAtKey(category: String): String =
        if (category == "Morning") KEY_MORNING_AT else KEY_EVENING_AT

    private fun lastShownDay(category: String): String = when (category) {
        "Morning" -> prefs().getString(KEY_LAST_MORNING_DAY, "") ?: ""
        else -> prefs().getString(KEY_LAST_EVENING_DAY, "") ?: ""
    }

    private fun markAzkarPromptShown(category: String) {
        val now = System.currentTimeMillis()
        val shownAt = azkarAt(category).takeIf { it > 0L } ?: now
        val lastDayKey = if (category == "Morning") {
            KEY_LAST_MORNING_DAY
        } else {
            KEY_LAST_EVENING_DAY
        }
        val nextAt = nextAzkarAfter(category, shownAt)
        prefs().edit()
            .putString(lastDayKey, dayKey(now))
            .putLong(azkarAtKey(category), nextAt)
            .apply()
    }

    private fun normalizeExpiredAzkarAt(category: String, now: Long) {
        if (!azkarEnabled(category)) return
        var at = azkarAt(category)
        if (at <= 0L) return
        var changed = false
        var guard = 0
        while (at < now && dayKey(at) != dayKey(now) && guard < 40) {
            val next = nextAzkarAfter(category, at)
            if (next <= at) break
            at = next
            changed = true
            guard++
        }
        if (changed) prefs().edit().putLong(azkarAtKey(category), at).apply()
    }

    private fun nextAzkarAfter(category: String, currentAt: Long): Long {
        if (category == "Morning" && isMorningFajrBased(currentAt)) {
            val nextFajr = nextPrayerAt("Fajr", currentAt)
            if (nextFajr != null) {
                return nextFajr + MORNING_AFTER_FAJR_MINUTES * 60_000L
            }
        }
        val calendar = Calendar.getInstance(selectedTimeZone()).apply {
            timeInMillis = currentAt
            add(Calendar.DAY_OF_MONTH, 1)
        }
        return calendar.timeInMillis
    }

    private fun isMorningFajrBased(at: Long): Boolean {
        val fajr = prayerAtOnSameDay("Fajr", at) ?: return false
        val expected = fajr + MORNING_AFTER_FAJR_MINUTES * 60_000L
        return abs(expected - at) <= 2 * 60_000L
    }

    private fun prayerAtOnSameDay(prayer: String, referenceAt: Long): Long? =
        prayerSchedule()
            .firstOrNull { (name, at) -> name == prayer && dayKey(at) == dayKey(referenceAt) }
            ?.second

    private fun nextPrayerAt(prayer: String, after: Long): Long? =
        prayerSchedule()
            .asSequence()
            .filter { (name, at) -> name == prayer && at > after }
            .map { it.second }
            .minOrNull()

    private fun prayerSchedule(): List<Pair<String, Long>> = try {
        val raw = widgetPrefs().getString("prayer_schedule_json", null) ?: return emptyList()
        val array = JSONArray(raw)
        buildList {
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                val name = item.optString("name")
                val at = item.optLong("at", 0L)
                if (name.isNotBlank() && at > 0L) add(name to at)
            }
        }
    } catch (_: Exception) {
        emptyList()
    }

    private fun dayKey(at: Long): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
        timeZone = selectedTimeZone()
    }.format(Date(at))

    private fun showCurrentNafha() {
        createBubbleIfNeeded()
        val params = bubbleParams ?: return
        unread = true
        resetBubblePosition(params)
        applyBubbleStyle()

        if (!bubbleAttached) {
            // Keep the delete target window behind the Nafahat head. It stays
            // transparent until dragging begins, so the head remains visible
            // above it when both centers meet.
            ensureDeleteTargetWindow()
            bubble.alpha = 0f
            wm.addView(bubble, params)
            bubbleAttached = true
            bubble.animate().alpha(1f).setDuration(220L).start()
        } else {
            wm.updateViewLayout(bubble, params)
            bubble.alpha = 1f
        }
        removeCard()
        if (activeAzkarCategory != null) showCard()
    }

    private fun resetBubblePosition(params: WindowManager.LayoutParams) {
        val size = dp(58)
        params.x = screenWidth() - size - dp(10)
        val usableHeight = (safeBottom() - safeTop() - size).coerceAtLeast(0)
        params.y = safeTop() + (usableHeight * .38f).toInt()
    }

    private fun dismissCurrentBubble() {
        removeCard()
        hideDeleteTarget()
        activeAzkarCategory = null
        val params = bubbleParams
        if (params != null) resetBubblePosition(params)
        if (!bubbleAttached) {
            finishBubbleSession()
            return
        }
        bubble.animate().cancel()
        bubble.animate()
            .alpha(0f)
            .setDuration(160L)
            .withEndAction {
                if (bubbleAttached) runCatching { wm.removeView(bubble) }
                bubbleAttached = false
                finishBubbleSession()
            }
            .start()
    }

    private fun finishBubbleSession() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun widgetPrefs() = HomeWidgetPlugin.getData(this)

    private fun isDarkTheme(): Boolean {
        return when (themeMode()) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
    }

    private fun createBubbleIfNeeded() {
        if (::bubble.isInitialized) return
        val view = TextView(this).apply {
            text = "✦"
            textSize = 25f
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            elevation = 18f
            setOnClickListener {
                markRead()
                showCard()
            }
        }

        val size = dp(58)
        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = screenWidth() - size - dp(10)
            y = safeTop() + dp(140)
        }

        view.setOnTouchListener(object : View.OnTouchListener {
            private var downX = 0f
            private var downY = 0f
            private var startX = 0
            private var startY = 0
            private var dragging = false
            private var lockedToDeleteTarget = false

            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        downX = event.rawX
                        downY = event.rawY
                        startX = params.x
                        startY = params.y
                        dragging = false
                        lockedToDeleteTarget = false
                        cardWasVisibleBeforeDrag = card != null
                        return true
                    }

                    MotionEvent.ACTION_MOVE -> {
                        val dx = event.rawX - downX
                        val dy = event.rawY - downY
                        if (!dragging && hypot(dx.toDouble(), dy.toDouble()) > dp(5)) {
                            dragging = true
                            if (cardWasVisibleBeforeDrag) collapseCardForDrag()
                            showDeleteTarget()
                        }
                        if (!dragging) return true

                        val maxY = safeBottom() - size
                        val desiredX = (startX + dx).toInt().coerceIn(0, screenWidth() - size)
                        val desiredY = (startY + dy).toInt().coerceIn(safeTop(), maxY)
                        val magnetized = magnetizedPosition(desiredX, desiredY, size)
                        params.x = magnetized.first
                        params.y = magnetized.second
                        lockedToDeleteTarget = isInsideDeleteSnapRange(params.x, params.y, size)
                        updateDeleteTargetState(params, size)
                        if (bubbleAttached) runCatching { wm.updateViewLayout(view, params) }
                        return true
                    }

                    MotionEvent.ACTION_UP -> {
                        if (!dragging) {
                            performClick()
                            return true
                        }

                        if (lockedToDeleteTarget ||
                            isInsideDeleteSnapRange(params.x, params.y, size)
                        ) {
                            dismissCurrentBubble()
                        } else {
                            restoreCardAfterDrag()
                            snapToNearestEdge()
                        }
                        return true
                    }

                    MotionEvent.ACTION_CANCEL -> {
                        lockedToDeleteTarget = false
                        hideDeleteTarget()
                        restoreCardAfterDrag()
                        snapToNearestEdge()
                        return true
                    }
                }
                return false
            }
        })

        bubble = view
        bubbleParams = params
    }

    private fun deleteTargetTopLeft(size: Int): Pair<Int, Int> =
        ((screenWidth() - size) / 2) to
            (screenHeight() - navigationBarHeight() - dp(18) - size)

    private fun deleteTargetCenter(): Pair<Float, Float> {
        val size = dp(76)
        val position = deleteTargetTopLeft(size)
        return (position.first + size / 2f) to (position.second + size / 2f)
    }

    private fun magnetizedPosition(x: Int, y: Int, size: Int): Pair<Int, Int> {
        if (!deleteTargetVisible) return x to y
        val centerX = x + size / 2f
        val centerY = y + size / 2f
        val target = deleteTargetCenter()
        val targetX = target.first
        val targetY = target.second
        val distance = hypot((centerX - targetX).toDouble(), (centerY - targetY).toDouble())
        if (isInsideDeleteSnapRange(x, y, size)) {
            return (targetX - size / 2f).toInt().coerceIn(0, screenWidth() - size) to
                (targetY - size / 2f).toInt().coerceIn(safeTop(), safeBottom() - size)
        }

        val magnetRadius = dp(180).toDouble()
        if (distance > magnetRadius) return x to y
        val strength = ((magnetRadius - distance) / magnetRadius).coerceIn(0.20, 0.78)
        val snappedCenterX = centerX + ((targetX - centerX) * strength).toFloat()
        val snappedCenterY = centerY + ((targetY - centerY) * strength).toFloat()
        return (snappedCenterX - size / 2f).toInt().coerceIn(0, screenWidth() - size) to
            (snappedCenterY - size / 2f).toInt().coerceIn(safeTop(), safeBottom() - size)
    }

    private fun collapseCardForDrag() {
        val current = card ?: return
        current.animate().cancel()
        current.animate()
            .scaleX(.72f)
            .scaleY(.72f)
            .alpha(0f)
            .setDuration(140L)
            .withEndAction {
                if (card === current) removeCard()
            }
            .start()
    }

    private fun restoreCardAfterDrag() {
        if (!cardWasVisibleBeforeDrag) return
        showCard()
        card?.apply {
            alpha = 0f
            scaleX = .78f
            scaleY = .78f
            animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(180L).start()
        }
    }

    private fun markRead() {
        unread = false
        applyBubbleStyle()
    }

    private fun applyBubbleStyle() {
        if (!::bubble.isInitialized) return
        val dark = isDarkTheme()
        bubble.setTextColor(if (dark) GOLD else GOLD_DARK)
        bubble.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (dark) DARK_BUBBLE else LIGHT_SURFACE)
            val border = when {
                unread && dark -> GOLD
                unread -> GOLD_DARK
                dark -> DARK_BORDER
                else -> LIGHT_BORDER
            }
            setStroke(dp(if (unread) 3 else 1), border)
        }
    }

    private fun snapToNearestEdge() {
        val params = bubbleParams ?: return
        if (!bubbleAttached) return
        val size = dp(58)
        val edge = dp(10)
        val targetX = if (params.x + size / 2 < screenWidth() / 2) edge
        else screenWidth() - size - edge
        params.y = params.y.coerceIn(safeTop(), safeBottom() - size)
        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(params.x, targetX).apply {
            duration = 220L
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener {
                params.x = it.animatedValue as Int
                if (bubbleAttached) runCatching { wm.updateViewLayout(bubble, params) }
            }
            start()
        }
    }

    private fun ensureDeleteTargetWindow() {
        if (deleteTargetAttached) return

        val view = TextView(this).apply {
            text = "×"
            textSize = 32f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(70, 70, 70))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(217, 160, 160, 160))
                setStroke(dp(2), Color.rgb(80, 80, 80))
            }
            elevation = 18f
            alpha = 0f
            scaleX = .92f
            scaleY = .92f
        }

        val size = dp(76)
        val targetPosition = deleteTargetTopLeft(size)
        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = targetPosition.first
            y = targetPosition.second
        }

        deleteTarget = view
        deleteTargetParams = params
        wm.addView(view, params)
        deleteTargetAttached = true
    }

    private fun showDeleteTarget() {
        ensureDeleteTargetWindow()
        val view = deleteTarget ?: return
        val params = deleteTargetParams ?: return
        val size = dp(76)
        val targetPosition = deleteTargetTopLeft(size)
        params.x = targetPosition.first
        params.y = targetPosition.second
        if (deleteTargetAttached) runCatching { wm.updateViewLayout(view, params) }

        deleteTargetVisible = true
        view.animate().cancel()
        view.scaleX = .92f
        view.scaleY = .92f
        view.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(140L)
            .start()
    }

    private fun updateDeleteTargetState(params: WindowManager.LayoutParams, bubbleSize: Int) {
        deleteTarget?.takeIf { deleteTargetVisible }?.apply {
            val inside =
                isInsideDeleteSnapRange(params.x, params.y, bubbleSize)
            val bubbleCenterX = params.x + bubbleSize / 2f
            val bubbleCenterY = params.y + bubbleSize / 2f
            val target = deleteTargetCenter()
            val distance = hypot(
                (bubbleCenterX - target.first).toDouble(),
                (bubbleCenterY - target.second).toDouble(),
            )
            val near = distance <= dp(180)
            animate().cancel()
            animate()
                .scaleX(if (inside) 1.18f else if (near) 1.08f else 1f)
                .scaleY(if (inside) 1.18f else if (near) 1.08f else 1f)
                .alpha(1f)
                .setDuration(90L)
                .start()
        }
    }

    private fun isInsideDeleteSnapRange(
        x: Int,
        y: Int,
        bubbleSize: Int,
    ): Boolean {
        if (!deleteTargetVisible) return false
        val bubbleRadius = bubbleSize / 2f
        val centerX = x + bubbleRadius
        val centerY = y + bubbleRadius
        val target = deleteTargetCenter()
        return hypot(
            (centerX - target.first).toDouble(),
            (centerY - target.second).toDouble(),
        ) <= dp(112)
    }

    private fun hideDeleteTarget() {
        deleteTargetVisible = false
        deleteTarget?.apply {
            animate().cancel()
            animate()
                .alpha(0f)
                .scaleX(.92f)
                .scaleY(.92f)
                .setDuration(120L)
                .start()
        }
    }

    private fun removeDeleteTarget() {
        deleteTargetVisible = false
        deleteTarget?.animate()?.cancel()
        if (deleteTargetAttached) {
            runCatching { wm.removeView(deleteTarget) }
        }
        deleteTargetAttached = false
        deleteTarget = null
        deleteTargetParams = null
    }

    private fun showCard() {
        if (!bubbleAttached) return
        removeCard()
        unread = false
        applyBubbleStyle()

        val isSpecialAzkar = activeAzkarCategory != null
        val content = if (isSpecialAzkar) specialAzkarContent(activeAzkarCategory!!) else items[index]
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(22), dp(18), dp(22), dp(18))
            elevation = 24f
            background = GradientDrawable().apply {
                cornerRadius = dp(22).toFloat()
                setColor(if (isDarkTheme()) DARK_BUBBLE else LIGHT_SURFACE)
                setStroke(dp(1), if (isDarkTheme()) DARK_BORDER else LIGHT_BORDER)
            }
        }

        val title = TextView(this).apply {
            text = content.title
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(if (isDarkTheme()) GOLD else GOLD_DARK)
            typeface = Typeface.DEFAULT_BOLD
        }
        root.addView(
            title,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        if (content.body.isNotBlank()) {
            root.addView(TextView(this).apply {
                text = content.body
                textSize = 14f
                gravity = Gravity.CENTER
                setTextColor(if (isDarkTheme()) Color.WHITE else LIGHT_TEXT)
                setPadding(0, dp(10), 0, 0)
            })
        }

        if (isSpecialAzkar) {
            root.addView(TextView(this).apply {
                text = if (widgetPrefs().getString("widget_language", "ar") == "en") {
                    "Open adhkar"
                } else {
                    "فتح الأذكار"
                }
                textSize = 13f
                gravity = Gravity.CENTER
                setTextColor(if (isDarkTheme()) DARK_MUTED else LIGHT_MUTED)
                setPadding(0, dp(10), 0, 0)
            })
            root.setOnClickListener {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(EXTRA_OPEN_AZKAR_CATEGORY, activeAzkarCategory)
                }
                startActivity(intent)
                dismissCurrentBubble()
            }
        }

        val width = (screenWidth() - dp(40)).coerceAtMost(dp(360))
        val height = WindowManager.LayoutParams.WRAP_CONTENT
        val params = WindowManager.LayoutParams(
            width,
            height,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }
        card = root
        wm.addView(root, params)
    }

    private fun updateCard() {
        if (card != null) showCard()
    }

    private fun removeCard() {
        card?.let { runCatching { wm.removeView(it) } }
        card = null
    }

    private fun specialAzkarContent(category: String): NafhaContent {
        val en = widgetPrefs().getString("widget_language", "ar") == "en"
        return if (category == "Morning") {
            if (en) NafhaContent("Morning adhkar", "A gentle reminder for your morning adhkar.", "ذكر")
            else NafhaContent("أذكار الصباح", "موعد أذكار الصباح.", "ذكر")
        } else {
            if (en) NafhaContent("Evening adhkar", "A gentle reminder for your evening adhkar.", "ذكر")
            else NafhaContent("أذكار المساء", "موعد أذكار المساء.", "ذكر")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Munib Nafahat",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                description = "Keeps Munib's floating Nafahat available quietly."
            },
        )
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            9128,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("Munib")
            .setContentText("Nafahat is ready")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun screenWidth(): Int = resources.displayMetrics.widthPixels
    private fun screenHeight(): Int = resources.displayMetrics.heightPixels

    private fun safeTop(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else 0
    }

    private fun safeBottom(): Int = screenHeight() - navigationBarHeight()

    private fun navigationBarHeight(): Int {
        val id = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else 0
    }

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}

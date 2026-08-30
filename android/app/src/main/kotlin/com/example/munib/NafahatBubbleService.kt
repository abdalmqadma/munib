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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
        const val EXTRA_OPEN_AZKAR_CATEGORY = "open_azkar_category"

        private const val CHANNEL_ID = "nafahat_bubble"
        private const val NOTIFICATION_ID = 9127
        private const val PREFS_NAME = "nafahat_prefs"
        private const val KEY_NEXT_DUE_AT = "next_due_at"
        private const val KEY_MORNING_AT = "morning_azkar_at"
        private const val KEY_EVENING_AT = "evening_azkar_at"
        private const val KEY_MORNING_ENABLED = "morning_azkar_enabled"
        private const val KEY_EVENING_ENABLED = "evening_azkar_enabled"
        private const val KEY_LAST_MORNING_DAY = "last_morning_azkar_day"
        private const val KEY_LAST_EVENING_DAY = "last_evening_azkar_day"

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
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var wm: WindowManager
    private lateinit var bubble: TextView
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var bubbleAttached = false
    private var card: LinearLayout? = null
    private var deleteTarget: TextView? = null
    private var snapAnimator: ValueAnimator? = null
    private var index = 0
    private var unread = true
    private var activeAzkarCategory: String? = null
    private var cardWasVisibleBeforeDrag = false

    private val nextNafha = object : Runnable {
        override fun run() {
            presentDueContent()
            scheduleNextWakeup()
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForegroundNotification()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        createBubbleIfNeeded()
        presentDueContent(firstRun = true)
        scheduleNextWakeup()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_REFRESH_SETTINGS) {
            handler.removeCallbacks(nextNafha)
            if (items[index].kind !in enabledKinds()) selectContent(firstRun = false)
            applyBubbleStyle()
            updateCard()
            startForegroundNotification()
            scheduleNextWakeup()
        }
        return START_STICKY
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (themeMode() == "system") {
            applyBubbleStyle()
            updateCard()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        snapAnimator?.cancel()
        removeCard()
        hideDeleteTarget()
        if (bubbleAttached) runCatching { wm.removeView(bubble) }
        bubbleAttached = false
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun prefs() = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

    private fun intervalMinutes(): Int =
        prefs().getInt("interval_minutes", 30).coerceIn(10, 180)

    private fun contextualMode(): Boolean = prefs().getBoolean("contextual_mode", true)

    private fun themeMode(): String = prefs().getString("theme_mode", "system") ?: "system"

    private fun enabledKinds(): Set<String> =
        prefs().getStringSet("enabled_kinds", null)?.takeIf { it.isNotEmpty() }
            ?: setOf("آية", "حديث", "ذكر", "أثر طيب")

    private fun filteredItems(): List<NafhaContent> =
        items.filter { it.kind in enabledKinds() }.ifEmpty { items }

    private fun presentDueContent(firstRun: Boolean = false) {
        val special = dueAzkarCategory(System.currentTimeMillis())
        if (special != null) {
            activeAzkarCategory = special
            markAzkarPromptShown(special)
        } else {
            activeAzkarCategory = null
            selectContent(firstRun)
            prefs().edit()
                .putLong(KEY_NEXT_DUE_AT, System.currentTimeMillis() + intervalMinutes() * 60_000L)
                .apply()
        }
        showCurrentNafha()
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
                return
            }
        }
        if (firstRun) {
            index = items.indexOf(available.first()).coerceAtLeast(0)
        } else {
            selectNextItem()
        }
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

    private fun scheduleNextWakeup() {
        val now = System.currentTimeMillis()
        val editor = prefs().edit()
        var regularDue = prefs().getLong(KEY_NEXT_DUE_AT, 0L)
        if (regularDue <= now) {
            regularDue = now + intervalMinutes() * 60_000L
            editor.putLong(KEY_NEXT_DUE_AT, regularDue).apply()
        }

        val candidates = mutableListOf(regularDue)
        nextUnshownAzkarAt("Morning", now)?.let(candidates::add)
        nextUnshownAzkarAt("Evening", now)?.let(candidates::add)
        scheduleAt(candidates.minOrNull() ?: regularDue)
    }

    private fun scheduleAt(dueAt: Long) {
        handler.removeCallbacks(nextNafha)
        handler.postDelayed(
            nextNafha,
            (dueAt - System.currentTimeMillis()).coerceAtLeast(1_000L),
        )
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
        if (at <= now || dayKey(at) != dayKey(now)) return null
        return if (lastShownDay(category) == dayKey(now)) null else at
    }

    private fun azkarEnabled(category: String): Boolean = when (category) {
        "Morning" -> prefs().getBoolean(KEY_MORNING_ENABLED, true)
        else -> prefs().getBoolean(KEY_EVENING_ENABLED, true)
    }

    private fun azkarAt(category: String): Long = when (category) {
        "Morning" -> prefs().getLong(KEY_MORNING_AT, 0L)
        else -> prefs().getLong(KEY_EVENING_AT, 0L)
    }

    private fun lastShownDay(category: String): String = when (category) {
        "Morning" -> prefs().getString(KEY_LAST_MORNING_DAY, "") ?: ""
        else -> prefs().getString(KEY_LAST_EVENING_DAY, "") ?: ""
    }

    private fun markAzkarPromptShown(category: String) {
        val key = if (category == "Morning") KEY_LAST_MORNING_DAY else KEY_LAST_EVENING_DAY
        prefs().edit().putString(key, dayKey(System.currentTimeMillis())).apply()
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
        if (!bubbleAttached) return
        bubble.animate().cancel()
        bubble.animate()
            .alpha(0f)
            .setDuration(160L)
            .withEndAction {
                if (bubbleAttached) runCatching { wm.removeView(bubble) }
                bubbleAttached = false
            }
            .start()
    }

    private fun createBubbleIfNeeded() {
        if (::bubble.isInitialized) return
        bubble = TextView(this).apply {
            text = "✦"
            textSize = 26f
            gravity = Gravity.CENTER
            elevation = 14f
        }
        applyBubbleStyle()

        val size = dp(58)
        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        resetBubblePosition(params)
        bubbleParams = params
        installBubbleTouchListener(params, size)
    }

    private fun installBubbleTouchListener(params: WindowManager.LayoutParams, size: Int) {
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false

        bubble.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnimator?.cancel()
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    bubble.alpha = 1f
                    cardWasVisibleBeforeDrag = card != null
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > dp(4) || abs(dy) > dp(4)) {
                        if (!moved) {
                            showDeleteTarget()
                            collapseCardForDrag()
                        }
                        moved = true
                    }
                    var nextX = (startX + dx).coerceIn(0, screenWidth() - size)
                    var nextY = (startY + dy).coerceIn(safeTop(), safeBottom() - size)
                    val magnetized = magnetizedPosition(nextX, nextY, size)
                    nextX = magnetized.first
                    nextY = magnetized.second
                    params.x = nextX
                    params.y = nextY
                    if (bubbleAttached) wm.updateViewLayout(bubble, params)
                    updateDeleteTargetState(params, size)
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val dismiss = moved && isFullyInsideDeleteTarget(params, size)
                    hideDeleteTarget()
                    when {
                        dismiss -> dismissCurrentBubble()
                        !moved -> {
                            markRead()
                            if (activeAzkarCategory != null) {
                                launchAzkar(activeAzkarCategory!!)
                            } else {
                                toggleCard()
                            }
                        }
                        else -> {
                            restoreCardAfterDrag()
                            snapToNearestEdge()
                        }
                    }
                    true
                }

                else -> false
            }
        }
    }

    private fun magnetizedPosition(x: Int, y: Int, size: Int): Pair<Int, Int> {
        if (deleteTarget == null) return x to y
        val centerX = x + size / 2f
        val centerY = y + size / 2f
        val targetX = screenWidth() / 2f
        val targetY = deleteTargetCenterY()
        val distance = hypot((centerX - targetX).toDouble(), (centerY - targetY).toDouble())
        val magnetRadius = dp(130).toDouble()
        if (distance > magnetRadius) return x to y

        val strength = ((magnetRadius - distance) / magnetRadius).coerceIn(0.18, 0.72)
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

    private fun showDeleteTarget() {
        if (deleteTarget != null) return
        val dark = isDarkTheme()
        val view = TextView(this).apply {
            text = "×"
            textSize = 32f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(if (dark) Color.rgb(145, 35, 45) else Color.rgb(180, 45, 55))
                setStroke(dp(2), if (dark) GOLD else GOLD_DARK)
            }
            elevation = 18f
            alpha = .92f
            scaleX = .92f
            scaleY = .92f
            animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(140L).start()
        }
        val size = dp(76)
        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = navigationBarHeight() + dp(18)
        }
        deleteTarget = view
        wm.addView(view, params)
    }

    private fun updateDeleteTargetState(params: WindowManager.LayoutParams, bubbleSize: Int) {
        deleteTarget?.apply {
            val inside = isFullyInsideDeleteTarget(params, bubbleSize)
            val bubbleCenterX = params.x + bubbleSize / 2f
            val bubbleCenterY = params.y + bubbleSize / 2f
            val distance = hypot(
                (bubbleCenterX - screenWidth() / 2f).toDouble(),
                (bubbleCenterY - deleteTargetCenterY()).toDouble(),
            )
            val near = distance <= dp(130)
            animate().cancel()
            animate()
                .scaleX(if (inside) 1.18f else if (near) 1.08f else 1f)
                .scaleY(if (inside) 1.18f else if (near) 1.08f else 1f)
                .alpha(if (near) 1f else .88f)
                .setDuration(90L)
                .start()
        }
    }

    private fun isFullyInsideDeleteTarget(
        params: WindowManager.LayoutParams,
        bubbleSize: Int,
    ): Boolean {
        val targetRadius = dp(38).toFloat()
        val bubbleRadius = bubbleSize / 2f
        val maxCenterDistance = (targetRadius - bubbleRadius).coerceAtLeast(0f)
        val centerX = params.x + bubbleRadius
        val centerY = params.y + bubbleRadius
        return hypot(
            (centerX - screenWidth() / 2f).toDouble(),
            (centerY - deleteTargetCenterY()).toDouble(),
        ) <= maxCenterDistance
    }

    private fun deleteTargetCenterY(): Float =
        screenHeight() - navigationBarHeight() - dp(18) - dp(38).toFloat()

    private fun hideDeleteTarget() {
        deleteTarget?.let { runCatching { wm.removeView(it) } }
        deleteTarget = null
    }

    private fun toggleCard() {
        if (card != null) removeCard() else showCard()
    }

    private fun showCard() {
        if (card != null) return
        val specialCategory = activeAzkarCategory
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = cardBackground()
            elevation = 18f
        }

        if (specialCategory != null) {
            val ar = isArabic()
            container.addView(TextView(this).apply {
                tag = "azkar_prompt"
                text = when (specialCategory) {
                    "Morning" -> if (ar) "اضغط لقراءة أذكار الصباح" else "Tap to read morning adhkar"
                    else -> if (ar) "اضغط لقراءة أذكار المساء" else "Tap to read evening adhkar"
                }
                textSize = 15f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(if (isDarkTheme()) Color.WHITE else LIGHT_TEXT)
                gravity = Gravity.CENTER
                textDirection = if (ar) View.TEXT_DIRECTION_RTL else View.TEXT_DIRECTION_LTR
            })
            container.setOnClickListener { launchAzkar(specialCategory) }
        } else {
            container.addView(contentText("title", 13f, true))
            container.addView(contentText("body", 17f, true).apply {
                setPadding(0, dp(10), 0, dp(7))
                setLineSpacing(0f, 1.25f)
            })
            container.addView(contentText("source", 11f, false))
            container.addView(contentText("detail_title", 11f, true).apply {
                setPadding(0, dp(13), 0, dp(3))
            })
            container.addView(contentText("detail", 13f, false).apply {
                setLineSpacing(0f, 1.18f)
            })
        }

        val bubbleLayout = bubbleParams ?: return
        val cardWidth = if (specialCategory != null) dp(250) else dp(318)
        val bubbleSize = dp(58)
        val onLeft = bubbleLayout.x + bubbleSize / 2 < screenWidth() / 2
        val desiredX = if (onLeft) bubbleLayout.x + bubbleSize + dp(8)
        else bubbleLayout.x - cardWidth - dp(8)

        val params = WindowManager.LayoutParams(
            cardWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = desiredX.coerceIn(dp(8), screenWidth() - cardWidth - dp(8))
            y = bubbleLayout.y.coerceIn(
                safeTop() + dp(4),
                (safeBottom() - dp(if (specialCategory != null) 110 else 330))
                    .coerceAtLeast(safeTop() + dp(4)),
            )
        }

        card = container
        wm.addView(container, params)
        if (specialCategory == null) updateCard()
    }

    private fun contentText(tagValue: String, size: Float, bold: Boolean): TextView =
        TextView(this).apply {
            tag = tagValue
            textSize = size
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    private fun updateCard() {
        val container = card ?: return
        if (activeAzkarCategory != null) return
        val item = items[index]
        val ar = isArabic()
        val dark = isDarkTheme()
        val primary = if (dark) Color.WHITE else LIGHT_TEXT
        val secondary = if (dark) DARK_MUTED else LIGHT_MUTED
        val accent = if (dark) GOLD else GOLD_DARK
        container.background = cardBackground()

        val title = container.findViewWithTag<TextView>("title")
        val body = container.findViewWithTag<TextView>("body")
        val source = container.findViewWithTag<TextView>("source")
        val detailTitle = container.findViewWithTag<TextView>("detail_title")
        val detail = container.findViewWithTag<TextView>("detail")

        title?.text = kindLabel(item.kind, ar)
        body?.text = if (ar) item.textAr else item.textEn
        source?.text = if (ar) item.sourceAr else item.sourceEn
        detailTitle?.text = if (ar) item.detailTitleAr else item.detailTitleEn
        detail?.text = if (ar) item.detailAr else item.detailEn

        title?.setTextColor(accent)
        body?.setTextColor(primary)
        source?.setTextColor(accent)
        detailTitle?.setTextColor(secondary)
        detail?.setTextColor(primary)

        listOf(title, body, source, detailTitle, detail).forEach { view ->
            view ?: return@forEach
            view.gravity = if (ar) Gravity.END else Gravity.START
            view.textDirection = if (ar) View.TEXT_DIRECTION_RTL else View.TEXT_DIRECTION_LTR
        }
    }

    private fun launchAzkar(category: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra(EXTRA_OPEN_AZKAR_CATEGORY, category)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
        removeCard()
    }

    private fun kindLabel(kind: String, ar: Boolean): String {
        if (ar) return kind
        return when (kind) {
            "آية" -> "Verse"
            "حديث" -> "Hadith"
            "ذكر" -> "Dhikr"
            else -> "Reflection"
        }
    }

    private fun cardBackground(): GradientDrawable {
        val dark = isDarkTheme()
        val colors = if (dark) {
            intArrayOf(Color.rgb(11, 31, 58), Color.rgb(16, 40, 70))
        } else {
            intArrayOf(Color.WHITE, LIGHT_SURFACE)
        }
        return GradientDrawable(GradientDrawable.Orientation.TL_BR, colors).apply {
            cornerRadius = dp(22).toFloat()
            setStroke(dp(1), if (dark) DARK_BORDER else LIGHT_BORDER)
        }
    }

    private fun removeCard() {
        card?.animate()?.cancel()
        card?.let { runCatching { wm.removeView(it) } }
        card = null
    }

    private fun widgetPrefs() = HomeWidgetPlugin.getData(this)

    private fun isArabic(): Boolean =
        (widgetPrefs().getString("widget_language", "ar") ?: "ar")
            .lowercase()
            .startsWith("ar")

    private fun isDarkTheme(): Boolean = when (themeMode()) {
        "dark" -> true
        "light" -> false
        else -> resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
    }

    private fun startForegroundNotification() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val ar = isArabic()
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(if (ar) "منيب • نفحات" else "Munib • Nafahat")
                .setContentText(
                    if (ar) "نفحات مفعلة حسب جدولك" else "Nafahat is active on your schedule",
                )
                .setOngoing(true)
                .setSilent(true)
                .setContentIntent(pending)
                .build(),
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Munib Nafahat",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
    }

    private fun overlayType(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
        @Suppress("DEPRECATION")
        WindowManager.LayoutParams.TYPE_PHONE
    }

    private fun screenWidth(): Int = resources.displayMetrics.widthPixels
    private fun screenHeight(): Int = resources.displayMetrics.heightPixels
    private fun safeTop(): Int = statusBarHeight() + dp(10)
    private fun safeBottom(): Int = screenHeight() - navigationBarHeight() - dp(12)

    private fun statusBarHeight(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else dp(24)
    }

    private fun navigationBarHeight(): Int {
        val id = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else dp(24)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}

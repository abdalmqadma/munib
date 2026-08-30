package com.example.munib

import android.animation.ValueAnimator
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.res.ColorStateList
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
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.util.Calendar
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.hypot

class NafahatBubbleService : Service() {
    companion object {
        @Volatile
        var isRunning: Boolean = false

        const val ACTION_REFRESH_SETTINGS = "com.example.munib.NAFAHAT_REFRESH_SETTINGS"
        private const val CHANNEL_ID = "nafahat_bubble"
        private const val NOTIFICATION_ID = 9127
        private const val PREFS_NAME = "nafahat_prefs"
        private const val KEY_NEXT_DUE_AT = "next_due_at"
    }

    private val items = NafahatContentRepository.items
    private lateinit var wm: WindowManager
    private lateinit var bubble: TextView
    private var bubbleAttached = false
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var card: LinearLayout? = null
    private var deleteTarget: TextView? = null
    private var index = 0
    private var unread = true
    private var snapAnimator: ValueAnimator? = null
    private val handler = Handler(Looper.getMainLooper())

    private val nextNafha = object : Runnable {
        override fun run() {
            selectContextualItem(firstRun = false)
            showCurrentNafha()
            scheduleNextFromNow()
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForegroundNotification()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        createBubbleIfNeeded()

        val dueAt = prefs().getLong(KEY_NEXT_DUE_AT, 0L)
        val now = System.currentTimeMillis()
        if (dueAt > now) {
            scheduleAt(dueAt)
        } else {
            selectContextualItem(firstRun = true)
            showCurrentNafha()
            scheduleNextFromNow()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_REFRESH_SETTINGS) {
            handler.removeCallbacks(nextNafha)
            if (currentFilteredItems().none { it == items[index] }) {
                selectContextualItem(firstRun = false)
            }
            applyBubbleStyle()
            updateCard()
            startForegroundNotification()

            val dueAt = prefs().getLong(KEY_NEXT_DUE_AT, 0L)
            if (dueAt > System.currentTimeMillis()) scheduleAt(dueAt)
            else scheduleNextFromNow()
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

    private fun contextualMode(): Boolean =
        prefs().getBoolean("contextual_mode", true)

    private fun themeMode(): String =
        prefs().getString("theme_mode", "system") ?: "system"

    private fun enabledKinds(): Set<String> =
        prefs().getStringSet("enabled_kinds", null)?.takeIf { it.isNotEmpty() }
            ?: setOf("آية", "حديث", "ذكر", "أثر طيب")

    private fun currentFilteredItems(): List<NafhaContent> =
        items.filter { it.kind in enabledKinds() }.ifEmpty { items }

    private fun selectContextualItem(firstRun: Boolean) {
        val available = currentFilteredItems()
        if (contextualMode()) {
            val tag = currentContextTag()
            val contextual = tag?.let { wanted ->
                available.filter { it.contextTag == wanted }
            }.orEmpty()
            if (contextual.isNotEmpty()) {
                val current = contextual.firstOrNull { items.indexOf(it) != index }
                    ?: contextual.first()
                index = items.indexOf(current).coerceAtLeast(0)
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
        val available = currentFilteredItems()
        val current = items[index]
        val currentPos = available.indexOf(current)
        val next = available[(if (currentPos >= 0) currentPos + 1 else 0) % available.size]
        index = items.indexOf(next).coerceAtLeast(0)
    }

    private fun currentContextTag(): String? {
        val calendar = Calendar.getInstance(selectedTimeZone())
        if (calendar.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY) return "friday"

        val untilPrayer = millisUntilNextPrayer()
        if (untilPrayer != null && untilPrayer in 1..(20 * 60_000L)) {
            return "pre_prayer"
        }

        return when (calendar.get(Calendar.HOUR_OF_DAY)) {
            in 5..10 -> "morning"
            in 17..22 -> "evening"
            else -> null
        }
    }

    private fun selectedTimeZone(): TimeZone {
        val raw = HomeWidgetPlugin.getData(this)
            .getString("widget_timezone", null)
            ?.trim()
            .orEmpty()
        return if (raw.isNotEmpty() && TimeZone.getAvailableIDs().contains(raw)) {
            TimeZone.getTimeZone(raw)
        } else {
            TimeZone.getDefault()
        }
    }

    private fun millisUntilNextPrayer(): Long? = try {
        val raw = HomeWidgetPlugin.getData(this)
            .getString("prayer_schedule_json", null)
            ?: return null
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

    private fun scheduleNextFromNow() {
        val dueAt = System.currentTimeMillis() + intervalMinutes() * 60_000L
        prefs().edit().putLong(KEY_NEXT_DUE_AT, dueAt).apply()
        scheduleAt(dueAt)
    }

    private fun scheduleAt(dueAt: Long) {
        handler.removeCallbacks(nextNafha)
        handler.postDelayed(
            nextNafha,
            (dueAt - System.currentTimeMillis()).coerceAtLeast(1_000L),
        )
    }

    private fun showCurrentNafha() {
        createBubbleIfNeeded()
        unread = true
        applyBubbleStyle()

        if (!bubbleAttached) {
            bubble.alpha = 0f
            wm.addView(bubble, bubbleParams)
            bubbleAttached = true
            bubble.animate()
                .alpha(1f)
                .setDuration(220L)
                .start()
            snapToNearestEdge()
        } else {
            bubble.alpha = 1f
        }

        updateCard()
        // Deliberately no automatic dismissal: a Nafha remains visible until
        // the user hides it or until a later scheduled Nafha replaces it.
    }

    private fun dismissCurrentBubble() {
        removeCard()
        hideDeleteTarget()
        if (!bubbleAttached) return
        bubble.animate().cancel()
        bubble.animate()
            .alpha(0f)
            .setDuration(180L)
            .withEndAction {
                if (bubbleAttached) runCatching { wm.removeView(bubble) }
                bubbleAttached = false
            }
            .start()
        // next_due_at is preserved so the next scheduled Nafha can appear.
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
            x = screenWidth() - size - dp(10)
            y = safeTop() + dp(90)
        }
        bubbleParams = params

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
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > dp(4) || abs(dy) > dp(4)) {
                        if (!moved) showDeleteTarget()
                        moved = true
                    }
                    params.x = (startX + dx).coerceIn(0, screenWidth() - size)
                    params.y = (startY + dy).coerceIn(safeTop(), safeBottom() - size)
                    if (bubbleAttached) wm.updateViewLayout(bubble, params)
                    updateDeleteTargetState(event.rawX, event.rawY)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val shouldDismiss = moved && isInsideDeleteTarget(event.rawX, event.rawY)
                    hideDeleteTarget()
                    when {
                        shouldDismiss -> dismissCurrentBubble()
                        !moved -> {
                            markRead()
                            toggleCard()
                        }
                        else -> snapToNearestEdge()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun applyBubbleStyle() {
        if (!::bubble.isInitialized) return
        bubble.setTextColor(if (isDarkTheme()) GOLD else GOLD_DARK)
        bubble.background = bubbleBackground(unread)
    }

    private fun bubbleBackground(isUnread: Boolean): GradientDrawable {
        val dark = isDarkTheme()
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (dark) DARK_BUBBLE else LIGHT_SURFACE)
            val stroke = when {
                isUnread && dark -> GOLD
                isUnread -> GOLD_DARK
                dark -> DARK_BORDER
                else -> LIGHT_BORDER
            }
            setStroke(dp(if (isUnread) 3 else 1), stroke)
        }
    }

    private fun snapToNearestEdge() {
        val params = bubbleParams ?: return
        if (!bubbleAttached) return
        val size = dp(58)
        val edge = dp(10)
        val midpoint = screenWidth() / 2
        val targetX = if (params.x + size / 2 < midpoint) {
            edge
        } else {
            screenWidth() - size - edge
        }
        params.y = params.y.coerceIn(safeTop(), safeBottom() - size)
        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(params.x, targetX).apply {
            duration = 260L
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { animator ->
                params.x = animator.animatedValue as Int
                if (bubbleAttached) runCatching { wm.updateViewLayout(bubble, params) }
            }
            start()
        }
    }

    private fun showDeleteTarget() {
        if (deleteTarget != null) return
        val dark = isDarkTheme()
        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (dark) Color.rgb(145, 35, 45) else Color.rgb(180, 45, 55))
            setStroke(dp(2), if (dark) GOLD else GOLD_DARK)
        }
        val view = TextView(this).apply {
            text = "×"
            textSize = 30f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            this.background = background
            elevation = 18f
            alpha = .94f
        }
        val size = dp(64)
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

    private fun updateDeleteTargetState(rawX: Float, rawY: Float) {
        deleteTarget?.apply {
            val inside = isInsideDeleteTarget(rawX, rawY)
            scaleX = if (inside) 1.18f else 1f
            scaleY = if (inside) 1.18f else 1f
            alpha = if (inside) 1f else .88f
        }
    }

    private fun isInsideDeleteTarget(rawX: Float, rawY: Float): Boolean {
        val centerX = screenWidth() / 2f
        val centerY = screenHeight() - navigationBarHeight() - dp(18) - dp(32)
        return hypot(
            (rawX - centerX).toDouble(),
            (rawY - centerY).toDouble(),
        ) <= dp(82)
    }

    private fun hideDeleteTarget() {
        deleteTarget?.let { runCatching { wm.removeView(it) } }
        deleteTarget = null
    }

    private fun markRead() {
        unread = false
        applyBubbleStyle()
        bubble.alpha = 1f
    }

    private fun toggleCard() {
        if (card != null) {
            removeCard()
            return
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(14))
            background = cardBackground()
            elevation = 18f
        }

        val title = textView("nafha_title", 13f, true)
        val body = textView("nafha_body", 17f, true).apply {
            setPadding(0, dp(10), 0, dp(7))
            setLineSpacing(0f, 1.25f)
        }
        val source = textView("nafha_source", 11f, false)
        val detailTitle = textView("nafha_detail_title", 11f, true).apply {
            setPadding(0, dp(13), 0, dp(3))
        }
        val detail = textView("nafha_detail", 13f, false).apply {
            setLineSpacing(0f, 1.18f)
        }

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, dp(12), 0, 0)
        }
        val next = Button(this).apply {
            tag = "nafha_next"
            setOnClickListener {
                selectNextItem()
                unread = false
                applyBubbleStyle()
                updateCard()
                scheduleNextFromNow()
            }
        }
        val hide = Button(this).apply {
            tag = "nafha_hide"
            setOnClickListener { dismissCurrentBubble() }
        }
        actions.addView(next)
        actions.addView(hide)

        container.addView(title)
        container.addView(body)
        container.addView(source)
        container.addView(detailTitle)
        container.addView(detail)
        container.addView(actions)

        val bp = bubbleParams ?: return
        val cardWidth = dp(318)
        val bubbleSize = dp(58)
        val onLeft = bp.x + bubbleSize / 2 < screenWidth() / 2
        val desiredX = if (onLeft) {
            bp.x + bubbleSize + dp(8)
        } else {
            bp.x - cardWidth - dp(8)
        }
        val params = WindowManager.LayoutParams(
            cardWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = desiredX.coerceIn(dp(8), screenWidth() - cardWidth - dp(8))
            y = bp.y.coerceIn(
                safeTop() + dp(4),
                (safeBottom() - dp(330)).coerceAtLeast(safeTop() + dp(4)),
            )
        }

        card = container
        wm.addView(container, params)
        updateCard()
    }

    private fun textView(tagValue: String, size: Float, bold: Boolean): TextView =
        TextView(this).apply {
            tag = tagValue
            textSize = size
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    private fun updateCard() {
        val container = card ?: return
        val item = items[index]
        val ar = isArabic()
        val dark = isDarkTheme()
        val primaryText = if (dark) Color.WHITE else LIGHT_TEXT
        val secondaryText = if (dark) DARK_MUTED else LIGHT_MUTED
        val accent = if (dark) GOLD else GOLD_DARK

        container.background = cardBackground()

        fun applyDirection(view: TextView?) {
            view ?: return
            view.gravity = if (ar) Gravity.END else Gravity.START
            view.textDirection = if (ar) View.TEXT_DIRECTION_RTL else View.TEXT_DIRECTION_LTR
        }

        val title = container.findViewWithTag<TextView>("nafha_title")
        val body = container.findViewWithTag<TextView>("nafha_body")
        val source = container.findViewWithTag<TextView>("nafha_source")
        val detailTitle = container.findViewWithTag<TextView>("nafha_detail_title")
        val detail = container.findViewWithTag<TextView>("nafha_detail")
        val next = container.findViewWithTag<Button>("nafha_next")
        val hide = container.findViewWithTag<Button>("nafha_hide")

        title?.text = kindLabel(item.kind, ar)
        body?.text = if (ar) item.textAr else item.textEn
        source?.text = if (ar) item.sourceAr else item.sourceEn
        detailTitle?.text = if (ar) item.detailTitleAr else item.detailTitleEn
        detail?.text = if (ar) item.detailAr else item.detailEn

        title?.setTextColor(accent)
        body?.setTextColor(primaryText)
        source?.setTextColor(accent)
        detailTitle?.setTextColor(secondaryText)
        detail?.setTextColor(primaryText)

        listOf(title, body, source, detailTitle, detail).forEach(::applyDirection)

        next?.apply {
            text = if (ar) "التالي" else "Next"
            setTextColor(if (dark) DARK_BUBBLE else Color.WHITE)
            backgroundTintList = ColorStateList.valueOf(accent)
        }
        hide?.apply {
            text = if (ar) "إخفاء" else "Hide"
            setTextColor(primaryText)
            backgroundTintList = ColorStateList.valueOf(
                if (dark) Color.rgb(37, 52, 71) else Color.rgb(231, 226, 216),
            )
        }
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
            intArrayOf(Color.rgb(255, 255, 255), Color.rgb(247, 244, 238))
        }
        return GradientDrawable(GradientDrawable.Orientation.TL_BR, colors).apply {
            cornerRadius = dp(22).toFloat()
            setStroke(dp(1), if (dark) DARK_BORDER else LIGHT_BORDER)
        }
    }

    private fun removeCard() {
        card?.let { runCatching { wm.removeView(it) } }
        card = null
    }

    private fun isArabic(): Boolean {
        val language = HomeWidgetPlugin.getData(this)
            .getString("widget_language", "ar")
            ?: "ar"
        return language.lowercase().startsWith("ar")
    }

    private fun isDarkTheme(): Boolean {
        return when (themeMode()) {
            "dark" -> true
            "light" -> false
            else -> {
                resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
                    Configuration.UI_MODE_NIGHT_YES
            }
        }
    }

    private fun startForegroundNotification() {
        val pending = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
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

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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

    private companion object Colors {
        val GOLD: Int = Color.rgb(244, 199, 106)
        val GOLD_DARK: Int = Color.rgb(157, 112, 30)
        val DARK_BUBBLE: Int = Color.rgb(11, 31, 58)
        val DARK_BORDER: Int = Color.rgb(62, 82, 106)
        val DARK_MUTED: Int = Color.rgb(169, 176, 181)
        val LIGHT_SURFACE: Int = Color.rgb(247, 244, 238)
        val LIGHT_BORDER: Int = Color.rgb(218, 211, 199)
        val LIGHT_TEXT: Int = Color.rgb(29, 35, 42)
        val LIGHT_MUTED: Int = Color.rgb(99, 105, 113)
    }
}

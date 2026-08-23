package com.example.munib

import android.animation.ValueAnimator
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
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
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.hypot

class NafahatBubbleService : Service() {
    companion object {
        @Volatile var isRunning: Boolean = false
        const val ACTION_REFRESH_SETTINGS = "com.example.munib.NAFAHAT_REFRESH_SETTINGS"
        private const val channelId = "nafahat_bubble"
        private const val notificationId = 9127
        private const val prefsName = "nafahat_prefs"
    }

    private data class Nafha(
        val kind: String,
        val text: String,
        val source: String,
        val detailTitle: String,
        val detail: String,
        val extraTitle: String? = null,
        val extra: String? = null,
    )

    /*
     * Religious text is intentionally fixed local content rather than AI-generated.
     * Tafsir lines are short summaries; where no specific sabab al-nuzul is included,
     * we say so instead of inventing one.
     */
    private val items = listOf(
        Nafha(
            "آية",
            "﴿ألا بذكر الله تطمئن القلوب﴾",
            "الرعد: 28",
            "تفسير مختصر",
            "تطمئن قلوب المؤمنين بذكر الله ومعرفته والأنس به.",
            "سبب النزول",
            "لا نعرض سبب نزول خاصاً لهذه الآية في النسخة الحالية لعدم الجزم برواية مخصوصة.",
        ),
        Nafha(
            "حديث",
            "أحب الأعمال إلى الله أدومها وإن قل",
            "متفق عليه",
            "الفائدة",
            "الاستمرار على العمل الصالح القليل أحب من نشاطٍ ينقطع سريعاً.",
        ),
        Nafha(
            "ذكر",
            "سبحان الله وبحمده",
            "ذكر ثابت في السنة",
            "من فضائله",
            "ذكرٌ عظيم الأجر، يجمع تنزيه الله وحمده، ويُستحب الإكثار منه.",
        ),
        Nafha(
            "آية",
            "﴿ومن يتوكل على الله فهو حسبه﴾",
            "الطلاق: 3",
            "تفسير مختصر",
            "من يعتمد على الله بصدقٍ مع أخذ الأسباب كفاه الله ما أهمّه.",
            "سبب النزول",
            "لا نعرض سبب نزول خاصاً لهذه الآية في النسخة الحالية لعدم الجزم برواية مخصوصة.",
        ),
        Nafha(
            "حديث",
            "الكلمة الطيبة صدقة",
            "متفق عليه",
            "الفائدة",
            "الكلام الحسن والإحسان باللسان بابٌ من أبواب الصدقة اليومية.",
        ),
        Nafha(
            "ذكر",
            "لا حول ولا قوة إلا بالله",
            "ذكر ثابت في السنة",
            "من فضائله",
            "تفويضٌ واستعانة بالله، وتذكيرٌ بأن القوة والتوفيق منه سبحانه.",
        ),
        Nafha(
            "آية",
            "﴿إن مع العسر يسرا﴾",
            "الشرح: 6",
            "تفسير مختصر",
            "وعدٌ بأن الشدة لا تنفك عن تيسيرٍ وفرجٍ من الله.",
            "سبب النزول",
            "لا نعرض سبب نزول خاصاً لهذه الآية في النسخة الحالية لعدم الجزم برواية مخصوصة.",
        ),
        Nafha(
            "أثر طيب",
            "اجعل لك خبيئة من عمل صالح لا يعلم بها أحد.",
            "تذكير تربوي",
            "المعنى",
            "إخفاء بعض الطاعات يعين على الإخلاص ويجعل بين العبد وربه عملاً لا يراه الناس.",
        ),
    )

    private lateinit var wm: WindowManager
    private lateinit var bubble: TextView
    private var card: LinearLayout? = null
    private var deleteTarget: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var index = 0
    private var unread = true
    private var snapAnimator: ValueAnimator? = null

    private val handler = Handler(Looper.getMainLooper())
    private val rotate = object : Runnable {
        override fun run() {
            selectNextItem()
            markUnread()
            updateCard()
            scheduleNextRotation()
        }
    }
    private val quietDim = Runnable {
        if (::bubble.isInitialized && card == null) bubble.alpha = 0.55f
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForegroundNotification()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        showBubble()
        scheduleNextRotation()
        scheduleQuietDim()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_REFRESH_SETTINGS) {
            handler.removeCallbacks(rotate)
            scheduleNextRotation()
            scheduleQuietDim()
            if (currentFilteredItems().none { it == items[index] }) {
                selectNextItem()
                markUnread()
                updateCard()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        snapAnimator?.cancel()
        if (::bubble.isInitialized) runCatching { wm.removeView(bubble) }
        card?.let { runCatching { wm.removeView(it) } }
        deleteTarget?.let { runCatching { wm.removeView(it) } }
        card = null
        deleteTarget = null
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun prefs() = getSharedPreferences(prefsName, MODE_PRIVATE)

    private fun intervalMinutes(): Int = prefs().getInt("interval_minutes", 30).coerceIn(10, 180)
    private fun quietMode(): Boolean = prefs().getBoolean("quiet_mode", false)

    private fun enabledKinds(): Set<String> {
        val saved = prefs().getStringSet("enabled_kinds", null)
        return saved?.takeIf { it.isNotEmpty() } ?: setOf("آية", "حديث", "ذكر", "أثر طيب")
    }

    private fun currentFilteredItems(): List<Nafha> {
        val kinds = enabledKinds()
        return items.filter { kinds.contains(it.kind) }.ifEmpty { items }
    }

    private fun selectNextItem() {
        val available = currentFilteredItems()
        val current = items[index]
        val currentPos = available.indexOf(current)
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // Morning/evening gently prioritise adhkar when the user enabled them.
        val preferredKind = if (hour in 5..9 || hour in 17..22) "ذكر" else null
        val preferred = preferredKind?.let { kind -> available.filter { it.kind == kind } }.orEmpty()

        val next = if (preferred.isNotEmpty() && current.kind != preferredKind) {
            preferred.first()
        } else {
            available[(if (currentPos >= 0) currentPos + 1 else 0) % available.size]
        }
        index = items.indexOf(next).coerceAtLeast(0)
    }

    private fun scheduleNextRotation() {
        handler.removeCallbacks(rotate)
        handler.postDelayed(rotate, intervalMinutes() * 60_000L)
    }

    private fun scheduleQuietDim() {
        handler.removeCallbacks(quietDim)
        if (!::bubble.isInitialized) return
        bubble.alpha = 1f
        if (quietMode()) handler.postDelayed(quietDim, 12_000L)
    }

    private fun overlayType(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
    }

    private fun showBubble() {
        bubble = TextView(this).apply {
            text = "✦"
            textSize = 26f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(244, 199, 106))
            setBackgroundResource(R.drawable.nafahat_bubble_unread_bg)
            elevation = 14f
        }

        val size = dp(58)
        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
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
                    wm.updateViewLayout(bubble, params)
                    updateDeleteTargetState(event.rawX, event.rawY)
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val shouldDelete = moved && isInsideDeleteTarget(event.rawX, event.rawY)
                    hideDeleteTarget()
                    if (shouldDelete) {
                        stopSelf()
                    } else if (!moved) {
                        markRead()
                        toggleCard()
                    } else {
                        snapToNearestEdge()
                    }
                    scheduleQuietDim()
                    true
                }

                else -> false
            }
        }
        wm.addView(bubble, params)
        snapToNearestEdge()
    }

    private fun snapToNearestEdge() {
        val params = bubbleParams ?: return
        val size = dp(58)
        val edge = dp(10)
        val midpoint = screenWidth() / 2
        val targetX = if (params.x + size / 2 < midpoint) edge else screenWidth() - size - edge
        params.y = params.y.coerceIn(safeTop(), safeBottom() - size)

        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(params.x, targetX).apply {
            duration = 240L
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { animator ->
                params.x = animator.animatedValue as Int
                if (::bubble.isInitialized) runCatching { wm.updateViewLayout(bubble, params) }
            }
            start()
        }
    }

    private fun showDeleteTarget() {
        if (deleteTarget != null) return
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.rgb(145, 35, 45))
            setStroke(dp(2), Color.argb(210, 244, 199, 106))
        }
        val view = TextView(this).apply {
            text = "×"
            textSize = 30f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = bg
            elevation = 18f
            alpha = .92f
        }
        val size = dp(64)
        val p = WindowManager.LayoutParams(
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
        wm.addView(view, p)
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
        return hypot((rawX - centerX).toDouble(), (rawY - centerY).toDouble()) <= dp(82)
    }

    private fun hideDeleteTarget() {
        deleteTarget?.let { runCatching { wm.removeView(it) } }
        deleteTarget = null
    }

    private fun markUnread() {
        unread = true
        if (::bubble.isInitialized) {
            bubble.setBackgroundResource(R.drawable.nafahat_bubble_unread_bg)
            bubble.alpha = 1f
        }
        scheduleQuietDim()
    }

    private fun markRead() {
        unread = false
        bubble.setBackgroundResource(R.drawable.nafahat_bubble_bg)
        bubble.alpha = 1f
    }

    private fun toggleCard() {
        if (card != null) {
            wm.removeView(card)
            card = null
            return
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(14))
            setBackgroundResource(R.drawable.nafahat_card_bg)
            elevation = 18f
        }
        val title = TextView(this).apply {
            tag = "nafha_title"
            setTextColor(Color.rgb(244, 199, 106))
            textSize = 13f
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.END
        }
        val body = TextView(this).apply {
            tag = "nafha_body"
            setTextColor(Color.WHITE)
            textSize = 17f
            setLineSpacing(0f, 1.25f)
            gravity = Gravity.END
            textDirection = View.TEXT_DIRECTION_RTL
            setPadding(0, dp(10), 0, dp(7))
        }
        val source = TextView(this).apply {
            tag = "nafha_source"
            setTextColor(Color.rgb(244, 199, 106))
            textSize = 11f
            gravity = Gravity.END
        }
        val detailTitle = TextView(this).apply {
            tag = "nafha_detail_title"
            setTextColor(Color.rgb(169, 176, 181))
            textSize = 11f
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.END
            setPadding(0, dp(13), 0, dp(3))
        }
        val detail = TextView(this).apply {
            tag = "nafha_detail"
            setTextColor(Color.WHITE)
            textSize = 13f
            setLineSpacing(0f, 1.18f)
            gravity = Gravity.END
            textDirection = View.TEXT_DIRECTION_RTL
        }
        val extraTitle = TextView(this).apply {
            tag = "nafha_extra_title"
            setTextColor(Color.rgb(169, 176, 181))
            textSize = 11f
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.END
            setPadding(0, dp(11), 0, dp(3))
        }
        val extra = TextView(this).apply {
            tag = "nafha_extra"
            setTextColor(Color.WHITE)
            textSize = 12f
            setLineSpacing(0f, 1.15f)
            gravity = Gravity.END
            textDirection = View.TEXT_DIRECTION_RTL
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, dp(12), 0, 0)
        }
        val next = Button(this).apply {
            text = "التالي"
            setOnClickListener {
                selectNextItem()
                markRead()
                updateCard()
                scheduleNextRotation()
            }
        }
        val close = Button(this).apply {
            text = "×"
            setOnClickListener { toggleCard() }
        }
        actions.addView(next)
        actions.addView(close)

        container.addView(title)
        container.addView(body)
        container.addView(source)
        container.addView(detailTitle)
        container.addView(detail)
        container.addView(extraTitle)
        container.addView(extra)
        container.addView(actions)

        val bp = bubbleParams ?: return
        val cardWidth = dp(318)
        val size = dp(58)
        val onLeft = bp.x + size / 2 < screenWidth() / 2
        val desiredX = if (onLeft) bp.x + size + dp(8) else bp.x - cardWidth - dp(8)
        val params = WindowManager.LayoutParams(
            cardWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = desiredX.coerceIn(dp(8), screenWidth() - cardWidth - dp(8))
            y = bp.y.coerceIn(safeTop() + dp(4), safeBottom() - dp(330))
        }
        card = container
        wm.addView(container, params)
        updateCard()
    }

    private fun updateCard() {
        val c = card ?: return
        val item = items[index]
        c.findViewWithTag<TextView>("nafha_title")?.text = item.kind
        c.findViewWithTag<TextView>("nafha_body")?.text = item.text
        c.findViewWithTag<TextView>("nafha_source")?.text = item.source
        c.findViewWithTag<TextView>("nafha_detail_title")?.text = item.detailTitle
        c.findViewWithTag<TextView>("nafha_detail")?.text = item.detail

        val extraTitle = c.findViewWithTag<TextView>("nafha_extra_title")
        val extra = c.findViewWithTag<TextView>("nafha_extra")
        if (item.extraTitle.isNullOrBlank() || item.extra.isNullOrBlank()) {
            extraTitle?.visibility = View.GONE
            extra?.visibility = View.GONE
        } else {
            extraTitle?.visibility = View.VISIBLE
            extra?.visibility = View.VISIBLE
            extraTitle?.text = item.extraTitle
            extra?.text = item.extra
        }
    }

    private fun startForegroundNotification() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        startForeground(
            notificationId,
            NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("منيب • نفحات")
                .setContentText("النفحات العائمة مفعلة")
                .setOngoing(true)
                .setContentIntent(pending)
                .build(),
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(channelId, "نفحات منيب", NotificationManager.IMPORTANCE_LOW),
            )
        }
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

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}

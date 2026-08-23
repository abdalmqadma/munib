package com.example.munib

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.abs

class NafahatBubbleService : Service() {
    companion object {
        @Volatile var isRunning: Boolean = false
        private const val channelId = "nafahat_bubble"
        private const val notificationId = 9127
    }

    private data class Nafha(val kind: String, val text: String, val source: String)

    private val items = listOf(
        Nafha("آية", "﴿ألا بذكر الله تطمئن القلوب﴾", "الرعد 28"),
        Nafha("حديث", "أحب الأعمال إلى الله أدومها وإن قل", "متفق عليه"),
        Nafha("آية", "﴿ومن يتوكل على الله فهو حسبه﴾", "الطلاق 3"),
        Nafha("حديث", "الكلمة الطيبة صدقة", "متفق عليه"),
        Nafha("أثر طيب", "اجعل لك خبيئة من عمل صالح لا يعلم بها أحد.", "تذكير يومي"),
        Nafha("آية", "﴿إن مع العسر يسرا﴾", "الشرح 6"),
        Nafha("حديث", "إنما الأعمال بالنيات", "متفق عليه"),
        Nafha("أثر طيب", "دقائق قليلة من الذكر قد تغيّر مزاج يوم كامل.", "تذكير يومي"),
    )

    private lateinit var wm: WindowManager
    private lateinit var bubble: TextView
    private var card: LinearLayout? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var index = 0
    private val handler = Handler(Looper.getMainLooper())
    private val rotate = object : Runnable {
        override fun run() {
            index = (index + 1) % items.size
            updateCard()
            handler.postDelayed(this, 30 * 60_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
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
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        showBubble()
        handler.postDelayed(rotate, 30 * 60_000L)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        runCatching { wm.removeView(bubble) }
        card?.let { runCatching { wm.removeView(it) } }
        card = null
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

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
            setBackgroundResource(R.drawable.nafahat_bubble_bg)
            elevation = 14f
        }
        val size = dp(58)
        val params = WindowManager.LayoutParams(
            size, size, overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(180)
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
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > 6 || abs(dy) > 6) moved = true
                    params.x = startX + dx
                    params.y = startY + dy
                    wm.updateViewLayout(bubble, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) toggleCard()
                    true
                }
                else -> false
            }
        }
        wm.addView(bubble, params)
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
            id = View.generateViewId()
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
            setPadding(0, dp(10), 0, dp(8))
        }
        val source = TextView(this).apply {
            tag = "nafha_source"
            setTextColor(Color.rgb(169, 176, 181))
            textSize = 11f
            gravity = Gravity.END
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }
        val next = Button(this).apply {
            text = "التالي"
            setOnClickListener {
                index = (index + 1) % items.size
                updateCard()
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
        container.addView(actions)

        val bp = bubbleParams ?: return
        val params = WindowManager.LayoutParams(
            dp(310), WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(), WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (bp.x + dp(66)).coerceAtLeast(dp(8))
            y = bp.y.coerceAtLeast(dp(40))
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
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(channelId, "نفحات منيب", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}

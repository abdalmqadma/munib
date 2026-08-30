package com.example.munib

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationManagerCompat
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class AdhanPlaybackService : Service() {
    companion object {
        private const val MAX_AUDIO_BYTES = 15L * 1024L * 1024L
        private const val CONNECT_TIMEOUT_MS = 10_000
        private const val READ_TIMEOUT_MS = 20_000

        private const val MADINAH_URL =
            "https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Adhan_Al_Haram_Al_Madani_-_Al_Madinah_1_(%D8%A3%D8%B0%D8%A7%D9%86_%D8%A7%D9%84%D8%AD%D8%B1%D9%85_%D8%A7%D9%84%D9%85%D8%AF%D9%86%D9%8A_-_%D8%A7%D9%84%D9%85%D8%AF%D9%8A%D9%86%D8%A9_%D8%A7%D9%84%D9%85%D9%86%D9%88%D8%B1%D8%A9).mp3"
        private const val MECCAN_URL =
            "https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Ali_Ibn_Ahmad_Mala_1_-_Al_Haram_Al_Maki_(%D8%B9%D9%84%D9%8A_%D8%A8%D9%86_%D8%A3%D8%AD%D9%85%D8%AF_%D9%85%D9%84%D8%A7_-_%D8%A7%D9%84%D8%AD%D8%B1%D9%85_%D8%A7%D9%84%D9%85%D9%83%D9%8A).mp3"

        fun prepareVoice(context: Context, voice: String) {
            if (voice !in setOf("Madinah", "Meccan")) return
            val appContext = context.applicationContext
            Thread {
                runCatching { ensureCached(appContext, voice) }
            }.start()
        }

        private fun sourceUrl(voice: String): String? = when (voice) {
            "Madinah" -> MADINAH_URL
            "Meccan" -> MECCAN_URL
            else -> null
        }

        private fun cacheFile(context: Context, voice: String): File {
            val dir = File(context.filesDir, "adhan_audio")
            if (!dir.exists()) dir.mkdirs()
            return File(dir, if (voice == "Meccan") "meccan.mp3" else "madinah.mp3")
        }

        private fun ensureCached(context: Context, voice: String): File? {
            val destination = cacheFile(context, voice)
            if (destination.isFile && destination.length() in 32_000..MAX_AUDIO_BYTES) {
                return destination
            }

            val source = sourceUrl(voice) ?: return null
            val temp = File(destination.parentFile, "${destination.name}.download")
            temp.delete()

            val connection = (URL(source).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                useCaches = true
                requestMethod = "GET"
                setRequestProperty("User-Agent", "Munib-Android/1.0")
            }

            return try {
                connection.connect()
                if (connection.responseCode !in 200..299) return null
                val declaredLength = connection.contentLengthLong
                if (declaredLength > MAX_AUDIO_BYTES) return null

                connection.inputStream.buffered().use { input ->
                    FileOutputStream(temp).buffered().use { output ->
                        val buffer = ByteArray(16 * 1024)
                        var total = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            total += read
                            if (total > MAX_AUDIO_BYTES) {
                                temp.delete()
                                return null
                            }
                            output.write(buffer, 0, read)
                        }
                    }
                }

                if (temp.length() < 32_000L) {
                    temp.delete()
                    return null
                }
                if (destination.exists()) destination.delete()
                if (!temp.renameTo(destination)) {
                    temp.copyTo(destination, overwrite = true)
                    temp.delete()
                }
                destination.takeIf { it.isFile && it.length() >= 32_000L }
            } catch (_: Exception) {
                temp.delete()
                null
            } finally {
                connection.disconnect()
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var audioManager: AudioManager
    private var mediaPlayer: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var generation = 0
    private var notificationId = -1
    private var prayer = ""
    private var languageCode = "ar"
    private var stopped = false

    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            -> finishPlayback(keepNotification = true)

            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                mediaPlayer?.setVolume(.25f, .25f)

            AudioManager.AUDIOFOCUS_GAIN ->
                mediaPlayer?.setVolume(1f, 1f)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_ON) {
                finishPlayback(keepNotification = true)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val filter = IntentFilter(Intent.ACTION_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getIntExtra(PrayerAlarmReceiver.EXTRA_NOTIFICATION_ID, -1) ?: -1
        val requestedPrayer = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER)
        val requestedLanguage = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_LANGUAGE) ?: "ar"
        val voice = intent?.getStringExtra(PrayerAlarmReceiver.EXTRA_VOICE) ?: "Madinah"

        if (id < 0 || requestedPrayer !in setOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha") ||
            voice !in setOf("Madinah", "Meccan")
        ) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        stopped = false
        notificationId = id
        prayer = requestedPrayer
        languageCode = if (requestedLanguage == "en") "en" else "ar"

        startForeground(
            notificationId,
            PrayerAlarmReceiver.notification(
                context = this,
                notificationId = notificationId,
                prayer = prayer,
                languageCode = languageCode,
                playing = true,
                silent = true,
            ),
        )
        prepareAndPlay(voice)
        return START_NOT_STICKY
    }

    private fun prepareAndPlay(voice: String) {
        releasePlayer()
        val currentGeneration = ++generation
        Thread {
            val file = runCatching { ensureCached(applicationContext, voice) }.getOrNull()
            mainHandler.post {
                if (stopped || generation != currentGeneration) return@post
                if (file == null) {
                    finishPlayback(keepNotification = true)
                } else {
                    playFile(file)
                }
            }
        }.start()
    }

    private fun playFile(file: File) {
        if (!requestAudioFocus()) {
            finishPlayback(keepNotification = true)
            return
        }

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        mediaPlayer = MediaPlayer().apply {
            setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            setAudioAttributes(attributes)
            setDataSource(file.absolutePath)
            setOnPreparedListener { player ->
                if (!stopped) player.start()
            }
            setOnCompletionListener { finishPlayback(keepNotification = true) }
            setOnErrorListener { _, _, _ ->
                finishPlayback(keepNotification = true)
                true
            }
            prepareAsync()
        }
    }

    private fun requestAudioFocus(): Boolean {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(audioFocusListener)
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusListener)
        }
        focusRequest = null
    }

    private fun finishPlayback(keepNotification: Boolean) {
        if (stopped) return
        stopped = true
        ++generation
        releasePlayer()
        abandonAudioFocus()

        if (notificationId >= 0 && keepNotification) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(false)
            }
            NotificationManagerCompat.from(this).notify(
                notificationId,
                PrayerAlarmReceiver.notification(
                    context = this,
                    notificationId = notificationId,
                    prayer = prayer,
                    languageCode = languageCode,
                    playing = false,
                    silent = true,
                ),
            )
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
        stopSelf()
    }

    private fun releasePlayer() {
        mediaPlayer?.let { player ->
            runCatching {
                if (player.isPlaying) player.stop()
            }
            runCatching { player.reset() }
            runCatching { player.release() }
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopped = true
        ++generation
        releasePlayer()
        abandonAudioFocus()
        runCatching { unregisterReceiver(screenReceiver) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

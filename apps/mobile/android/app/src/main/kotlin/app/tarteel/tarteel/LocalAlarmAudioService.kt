package app.tarteel.tarteel

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import org.json.JSONObject
import java.io.File

/** Independent local alarm playback; never fetches remote audio or changes system volume. */
class LocalAlarmAudioService : Service() {
    private var player: ExoPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var pausedForFocus = false
    private var currentRecord: JSONObject? = null
    private var prepareWakeLock: android.os.PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") { stopSelf(); return START_NOT_STICKY }
        val record = try { JSONObject(intent?.getStringExtra("record") ?: "{}") }
            catch (_: Exception) { fail("INVALID_ALARM_RECORD"); return START_NOT_STICKY }
        currentRecord = record
        val notification = OfflineNotifications.build(this, OfflineNotifications.ALARM_CHANNEL,
            record.optString("title", "ترتيل"), record.optString("body"),
            stopIntent = Intent(this, LocalAlarmAudioService::class.java).setAction("stop"),
            payload = record.optString("payload"))
        try {
            // Android 15+ also requires an active foreground service before requesting focus.
            if (Build.VERSION.SDK_INT >= 29) startForeground(8102, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(8102, notification)
            handler.removeCallbacksAndMessages(null)
            // AlarmManager's receiver wake lock ends when onReceive returns. Bridge local
            // player preparation until Media3 takes its own playback wake lock.
            if (prepareWakeLock?.isHeld == true) prepareWakeLock?.release()
            prepareWakeLock = getSystemService(android.os.PowerManager::class.java)
                .newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "tarteel:alarm-prepare")
                .apply { setReferenceCounted(false); acquire(30_000L) }
            player?.release(); player = null; pausedForFocus = false
            val path = record.optString("path")
            val uri = audioUri(path, record.optString("channel", "adhan"))
            val manager = getSystemService(AudioManager::class.java)
            focus?.let { manager.abandonAudioFocusRequest(it) }
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_ALARM)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setOnAudioFocusChangeListener({ change ->
                    when (change) {
                        AudioManager.AUDIOFOCUS_LOSS -> stopSelf()
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                            pausedForFocus = player?.isPlaying == true
                            player?.pause()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> if (pausedForFocus) { pausedForFocus = false; player?.play() }
                    }
                }, handler).build()
            if (manager.requestAudioFocus(focus!!) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                fail("AUDIO_FOCUS_DENIED"); return START_NOT_STICKY
            }
            player = ExoPlayer.Builder(this).build().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_ALARM).setContentType(C.AUDIO_CONTENT_TYPE_SPEECH).build(), false)
                setWakeMode(C.WAKE_MODE_LOCAL)
                volume = record.optDouble("volume", 1.0).takeIf { it.isFinite() }?.coerceIn(0.0, 1.0)?.toFloat() ?: 1f
                addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(state: Int) {
                        if (state == Player.STATE_READY) {
                            getSharedPreferences("alarm_diagnostics", MODE_PRIVATE).edit()
                                .putString("lastPath", path).putLong("lastReadyAt", System.currentTimeMillis())
                                .putString("lastFailure", "").apply()
                            if (prepareWakeLock?.isHeld == true) prepareWakeLock?.release()
                        }
                        if (state == Player.STATE_ENDED) stopSelf()
                    }
                    override fun onPlayerError(error: androidx.media3.common.PlaybackException) { fail("PLAYBACK_${error.errorCodeName}") }
                })
                setMediaItem(MediaItem.fromUri(uri)); prepare(); play()
            }
            handler.postDelayed({ stopSelf() }, 15 * 60 * 1000L)
        } catch (error: Exception) { fail("ALARM_${error.javaClass.simpleName}") }
        return START_NOT_STICKY
    }
    private fun audioUri(path: String, channel: String): Uri {
        if (path.isNotEmpty() && !path.startsWith("assets/")) {
            val file = File(if (path.startsWith("file://")) Uri.parse(path).path ?: "" else path)
            require(file.isFile && file.canonicalPath.startsWith(filesDir.canonicalPath + "/")) { "LOCAL_AUDIO_MISSING" }
            return Uri.fromFile(file)
        }
        // Flutter assets are packaged locally; only our audited catalog is accepted.
        if (path == "assets/audio/reminder.wav") return Uri.parse("asset:///flutter_assets/$path")
        if (channel != "adhan" && path.isEmpty()) {
            return Uri.parse("asset:///flutter_assets/assets/audio/reminder.wav")
        }
        return Uri.parse("android.resource://$packageName/${R.raw.adhan}")
    }
    private fun fail(code: String) {
        getSharedPreferences("alarm_diagnostics", MODE_PRIVATE).edit().putString("lastFailure", code).apply()
        currentRecord?.let { record ->
            try {
                val notification = OfflineNotifications.build(this, OfflineNotifications.ALARM_FALLBACK_CHANNEL,
                    record.optString("title", "ترتيل"), record.optString("body") + " — تعذر تشغيل الصوت؛ راجع حالة التنبيهات",
                    ongoing = false, payload = record.optString("payload"))
                getSystemService(android.app.NotificationManager::class.java).notify(record.optInt("id", 8103), notification)
            } catch (_: SecurityException) { /* The user can inspect the recorded failure after granting permission. */ }
        }
        stopSelf()
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null); player?.release(); player = null
        if (prepareWakeLock?.isHeld == true) prepareWakeLock?.release()
        prepareWakeLock = null
        focus?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }; focus = null
        stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy()
    }
}

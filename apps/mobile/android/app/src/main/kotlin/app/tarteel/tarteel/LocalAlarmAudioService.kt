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

/** Independent prayer/personal alarm subsystem; never fetches remote audio. */
class LocalAlarmAudioService : Service() {
    private var player: ExoPlayer? = null
    private var focus: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") { stopSelf(); return START_NOT_STICKY }
        val record = try { JSONObject(intent?.getStringExtra("record") ?: "{}") } catch (_: Exception) { stopSelf(); return START_NOT_STICKY }
        val notification = OfflineNotifications.build(this, OfflineNotifications.ALARM_CHANNEL,
            record.optString("title", "ترتيل"), record.optString("body"),
            stopIntent = Intent(this, LocalAlarmAudioService::class.java).setAction("stop"))
        if (Build.VERSION.SDK_INT >= 29) startForeground(8102, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        else startForeground(8102, notification)
        player?.release()
        try {
            val path = record.optString("path")
            val file = File(path)
            val uri = if (file.isFile && file.canonicalPath.startsWith(filesDir.canonicalPath + "/")) Uri.fromFile(file)
                else Uri.parse("android.resource://$packageName/${R.raw.adhan}")
            val manager = getSystemService(AudioManager::class.java)
            focus?.let { manager.abandonAudioFocusRequest(it) }
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_ALARM)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setOnAudioFocusChangeListener { change -> if (change == AudioManager.AUDIOFOCUS_LOSS) stopSelf() }.build()
            if (manager.requestAudioFocus(focus!!) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { stopSelf(); return START_NOT_STICKY }
            player = ExoPlayer.Builder(this).build().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_ALARM).setContentType(C.AUDIO_CONTENT_TYPE_SPEECH).build(), false)
                setWakeMode(C.WAKE_MODE_LOCAL)
                addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(state: Int) {
                        if (state == Player.STATE_READY) getSharedPreferences("alarm_diagnostics", MODE_PRIVATE).edit()
                            .putString("lastPath", path).putLong("lastReadyAt", System.currentTimeMillis()).apply()
                        if (state == Player.STATE_ENDED) stopSelf()
                    }
                    override fun onPlayerError(error: androidx.media3.common.PlaybackException) { stopSelf() }
                })
                setMediaItem(MediaItem.fromUri(uri)); prepare(); play()
            }
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({ stopSelf() }, 15 * 60 * 1000L)
        } catch (_: Exception) { stopSelf() }
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null); player?.release(); player = null
        focus?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }; focus = null
        stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy()
    }
}

package app.tarteel.tarteel

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class RecitationRecorderService : Service() {
    companion object {
        @Volatile var active = false
            private set
        @Volatile var lastError: String? = null
            private set
        @Volatile var elapsedStart = 0L
            private set
        fun completed(context: android.content.Context): String = context
            .getSharedPreferences("recitation_recordings", MODE_PRIVATE).getString("completed", "[]") ?: "[]"
    }
    private var recorder: MediaRecorder? = null
    private var partial: File? = null
    private var title = "تسجيل تلاوتي"
    private var startedAt = 0L
    private val handler = Handler(Looper.getMainLooper())
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") { finish(); stopSelf(); return START_NOT_STICKY }
        if (active) return START_NOT_STICKY
        lastError = null
        title = intent?.getStringExtra("title") ?: title
        val notification = OfflineNotifications.build(this, OfflineNotifications.TASK_CHANNEL,
            "تسجيل التلاوة", title,
            stopIntent = Intent(this, RecitationRecorderService::class.java).setAction("stop"))
        if (Build.VERSION.SDK_INT >= 30) startForeground(8103, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        else startForeground(8103, notification)
        try {
            val directory = File(filesDir, "recordings").apply { mkdirs() }
            startedAt = System.currentTimeMillis()
            partial = File(directory, "$startedAt.m4a.part")
            @Suppress("DEPRECATION")
            val recording = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else MediaRecorder()
            recorder = recording
            recording.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000); setAudioSamplingRate(44100)
                setOutputFile(partial!!.absolutePath)
                setOnErrorListener { _, _, _ -> finish(); stopSelf() }
                prepare(); start()
            }
            active = true; elapsedStart = SystemClock.elapsedRealtime()
            val limit = intent?.getLongExtra("limitMs", 0L) ?: 0L
            handler.postDelayed({ finish(); stopSelf() }, if (limit > 0L) limit else 2 * 60 * 60 * 1000L)
        } catch (_: Exception) { lastError = "MICROPHONE_START_FAILED"; recorder?.release(); recorder = null; partial?.delete(); active = false; stopSelf() }
        return START_NOT_STICKY
    }
    private fun finish() {
        if (recorder == null) return
        val duration = (SystemClock.elapsedRealtime() - elapsedStart).coerceAtLeast(0L)
        var valid = active
        try { recorder?.stop() } catch (_: Exception) { valid = false }
        recorder?.release(); recorder = null; active = false
        handler.removeCallbacksAndMessages(null)
        val part = partial ?: return
        val target = File(part.absolutePath.removeSuffix(".part"))
        if (valid && part.length() > 1024 && part.renameTo(target)) {
            val prefs = getSharedPreferences("recitation_recordings", MODE_PRIVATE)
            val rows = JSONArray(prefs.getString("completed", "[]"))
            rows.put(JSONObject().put("id", "mic-$startedAt").put("title", title)
                .put("path", target.absolutePath).put("startedAt", startedAt)
                .put("durationMs", duration).put("size", target.length()))
            prefs.edit().putString("completed", rows.toString()).commit()
        } else { lastError = "RECORDING_NOT_SAVED"; part.delete() }
        partial = null
    }
    override fun onDestroy() { finish(); stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy() }
}

package app.tarteel.tarteel

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.os.SystemClock
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private var pickerResult: MethodChannel.Result? = null
    private var microphoneResult: MethodChannel.Result? = null
    private var microphoneArguments: Map<*, *>? = null
    private val fileExecutor = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.tarteel.tarteel/offline").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pickAudio" -> {
                        if (pickerResult != null) result.error("BUSY", "File picker is open", null)
                        else {
                            pickerResult = result
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                type = "audio/*"; addCategory(Intent.CATEGORY_OPENABLE)
                            }, 9301)
                        }
                    }
                    "task" -> {
                        startForegroundService(Intent(this, OfflineTaskService::class.java)
                            .putExtra("id", if (call.argument<Boolean>("recording") == true) "stream" else call.argument<String>("id") ?: "download")
                            .putExtra("title", call.argument<String>("title"))
                            .putExtra("progress", call.argument<Int>("progress") ?: -1))
                        result.success(null)
                    }
                    "finishTask" -> {
                        startService(Intent(this, OfflineTaskService::class.java).setAction("finish")
                            .putExtra("id", if (call.argument<Boolean>("recording") == true) "stream" else call.argument<String>("id") ?: "download"))
                        result.success(null)
                    }
                    "scheduleAlarm" -> {
                        LocalAlarmScheduler.schedule(this, JSONObject(call.arguments as Map<*, *>))
                        result.success(true)
                    }
                    "cancelAlarm" -> { LocalAlarmScheduler.cancel(this, call.argument<Int>("id")!!); result.success(null) }
                    "recordStart" -> {
                        if (RecitationRecorderService.active || microphoneResult != null) result.error("RECORDING", "Recording already active", null)
                        else {
                            microphoneArguments = call.arguments as? Map<*, *>
                            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                                startRecording(); result.success(true)
                            } else {
                                microphoneResult = result
                                requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 9302)
                            }
                        }
                    }
                    "recordStop" -> { startService(Intent(this, RecitationRecorderService::class.java).setAction("stop")); result.success(null) }
                    "recordAcknowledge" -> {
                        val ids = call.argument<List<String>>("ids")?.toSet() ?: emptySet()
                        val rows = org.json.JSONArray(RecitationRecorderService.completed(this))
                        val remaining = org.json.JSONArray()
                        for (index in 0 until rows.length()) {
                            val row = rows.getJSONObject(index)
                            if (!ids.contains(row.getString("id"))) remaining.put(row)
                        }
                        getSharedPreferences("recitation_recordings", MODE_PRIVATE).edit().putString("completed", remaining.toString()).commit()
                        result.success(null)
                    }
                    "recordStatus" -> result.success(mapOf("active" to RecitationRecorderService.active,
                        "elapsedMs" to if (RecitationRecorderService.active) SystemClock.elapsedRealtime() - RecitationRecorderService.elapsedStart else 0L,
                        "completed" to RecitationRecorderService.completed(this)))
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("OFFLINE_AUDIO_ERROR", error.message, null) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.tarteel.tarteel/settings").setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") { result.notImplemented(); return@setMethodCallHandler }
            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            })
            result.success(true)
        }
    }
    private fun startRecording() {
        val args = microphoneArguments
        startForegroundService(Intent(this, RecitationRecorderService::class.java)
            .putExtra("title", args?.get("title") as? String ?: "تسجيل تلاوتي")
            .putExtra("limitMs", (args?.get("limitMs") as? Number)?.toLong() ?: 0L))
        microphoneArguments = null
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 9302) return
        val result = microphoneResult; microphoneResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            try { startRecording(); result?.success(true) } catch (error: Exception) { result?.error("RECORD_START_FAILED", error.message, null) }
        } else result?.success(false)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 9301) return
        val result = pickerResult ?: return; pickerResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        // A private copy keeps alerts usable after the user moves the source.
        fileExecutor.execute {
            val directory = File(filesDir, "alert_audio").apply { mkdirs() }
            val target = File(directory, "${System.currentTimeMillis()}.audio")
            try {
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output ->
                        val buffer = ByteArray(32768); var bytes = 0L
                        while (true) {
                            val count = input.read(buffer); if (count < 0) break
                            bytes += count; require(bytes <= 100 * 1024 * 1024L) { "AUDIO_FILE_TOO_LARGE" }
                            output.write(buffer, 0, count)
                        }
                    }
                } ?: error("AUDIO_FILE_UNREADABLE")
                val metadata = MediaMetadataRetriever()
                try {
                    metadata.setDataSource(target.absolutePath)
                    require((metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) > 0L) { "INVALID_AUDIO_FILE" }
                } finally { metadata.release() }
                runOnUiThread { result.success(target.absolutePath) }
            } catch (error: Exception) {
                target.delete(); runOnUiThread { result.error("AUDIO_IMPORT_FAILED", error.message, null) }
            }
        }
    }
}

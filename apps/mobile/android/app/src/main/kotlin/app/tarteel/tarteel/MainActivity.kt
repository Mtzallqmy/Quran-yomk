package app.tarteel.tarteel

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.os.SystemClock
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.net.Uri
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private var offlineChannel: MethodChannel? = null
    private var pendingAlarmPayload: String? = null
    private var pickerResult: MethodChannel.Result? = null
    private var pickingBackup = false
    private var microphoneResult: MethodChannel.Result? = null
    private var microphoneArguments: Map<*, *>? = null
    private var locationResult: MethodChannel.Result? = null
    private var locationListener: LocationListener? = null
    private val locationHandler = Handler(Looper.getMainLooper())
    private val fileExecutor = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingAlarmPayload = intent?.getStringExtra("alarmPayload")
        offlineChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.tarteel.tarteel/offline")
        offlineChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "takeAlarmPayload" -> { result.success(pendingAlarmPayload); pendingAlarmPayload = null }
                    "pickAudio", "pickBackup" -> {
                        if (pickerResult != null) result.error("BUSY", "File picker is open", null)
                        else {
                            pickerResult = result
                            pickingBackup = call.method == "pickBackup"
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                type = if (pickingBackup) "*/*" else "audio/*"
                                if (pickingBackup) putExtra(Intent.EXTRA_MIME_TYPES,
                                    arrayOf("application/json", "text/plain", "application/octet-stream"))
                                addCategory(Intent.CATEGORY_OPENABLE)
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
                        "completed" to RecitationRecorderService.completed(this), "error" to RecitationRecorderService.lastError))
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("OFFLINE_AUDIO_ERROR", error.message, null) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.tarteel.tarteel/settings").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openNotificationSettings" -> {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        }); result.success(true)
                    }
                    "alarmDiagnostics" -> result.success(LocalAlarmScheduler.diagnostics(this))
                    "openAlarmSettings" -> {
                        val settings = if (Build.VERSION.SDK_INT >= 31)
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        startActivity(settings); result.success(true)
                    }
                    "openBatterySettings" -> {
                        // Open settings; never silently exempt the app or bypass the user's choice.
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); result.success(true)
                    }
                    "getPrayerLocation" -> {
                        if (locationResult != null) result.error("BUSY", "Location request in progress", null)
                        else {
                            locationResult = result
                            if (hasLocationPermission()) readPrayerLocation()
                            else requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION), 9303)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("SETTINGS_ERROR", error.message, null) }
        }
    }
    private fun hasLocationPermission() =
        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun completePrayerLocation(location: Location?, error: String? = null) {
        val result = locationResult ?: return
        locationResult = null
        locationHandler.removeCallbacksAndMessages(null)
        locationListener?.let {
            try { getSystemService(LocationManager::class.java).removeUpdates(it) }
            catch (_: SecurityException) { /* Permission may have been revoked while requesting. */ }
        }
        locationListener = null
        if (location == null) result.error(error ?: "LOCATION_UNAVAILABLE", "اختر المدينة أو الإحداثيات يدويًا", null)
        else result.success(mapOf("latitude" to location.latitude, "longitude" to location.longitude,
            "timezone" to java.util.TimeZone.getDefault().id, "accuracyMeters" to location.accuracy.toDouble(),
            "capturedAt" to location.time))
    }

    @Suppress("DEPRECATION")
    private fun readPrayerLocation() {
        if (!hasLocationPermission()) { completePrayerLocation(null, "LOCATION_PERMISSION_DENIED"); return }
        try {
            val manager = getSystemService(LocationManager::class.java)
            val providers = manager.getProviders(true).filter {
                it == LocationManager.GPS_PROVIDER || it == LocationManager.NETWORK_PROVIDER
            }
            val last = providers.mapNotNull {
                try { manager.getLastKnownLocation(it) } catch (_: SecurityException) { null }
            }.maxByOrNull { it.elapsedRealtimeNanos }
            // Cached coordinates are acceptable only when recent; never silently use a stale city.
            if (last != null && SystemClock.elapsedRealtimeNanos() - last.elapsedRealtimeNanos < 30L * 60 * 1_000_000_000) {
                completePrayerLocation(last); return
            }
            val provider = providers.firstOrNull { it == LocationManager.NETWORK_PROVIDER } ?: providers.firstOrNull()
            if (provider == null) { completePrayerLocation(null, "LOCATION_DISABLED"); return }
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) { completePrayerLocation(location) }
                override fun onProviderDisabled(provider: String) { completePrayerLocation(null, "LOCATION_DISABLED") }
                override fun onProviderEnabled(provider: String) = Unit
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) = Unit
            }
            locationListener = listener
            manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            locationHandler.postDelayed({ completePrayerLocation(null, "LOCATION_TIMEOUT") }, 20_000L)
        } catch (_: SecurityException) { completePrayerLocation(null, "LOCATION_PERMISSION_DENIED") }
        catch (_: Exception) { completePrayerLocation(null, "LOCATION_UNAVAILABLE") }
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
        if (requestCode == 9303) {
            if (hasLocationPermission()) readPrayerLocation()
            else completePrayerLocation(null, "LOCATION_PERMISSION_DENIED")
            return
        }
        if (requestCode != 9302) return
        val result = microphoneResult; microphoneResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            try { startRecording(); result?.success(true) } catch (error: Exception) { result?.error("RECORD_START_FAILED", error.message, null) }
        } else result?.success(false)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("alarmPayload")?.takeIf { it.isNotBlank() }?.let {
            offlineChannel?.invokeMethod("alarmTapped", it)
        }
    }
    override fun onDestroy() {
        if (locationResult != null) completePrayerLocation(null, "LOCATION_CANCELLED")
        super.onDestroy()
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 9301) return
        val result = pickerResult ?: return; pickerResult = null
        val backup = pickingBackup; pickingBackup = false
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        if (backup) {
            fileExecutor.execute {
                try {
                    val bytes = contentResolver.openInputStream(uri)?.use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer); if (count < 0) break
                            require(output.size() + count <= 256 * 1024) { "BACKUP_TOO_LARGE" }
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    } ?: error("BACKUP_UNREADABLE")
                    runOnUiThread { result.success(String(bytes, Charsets.UTF_8)) }
                } catch (error: Exception) {
                    runOnUiThread { result.error("BACKUP_IMPORT_FAILED", error.message, null) }
                }
            }
            return
        }
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

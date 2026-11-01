package app.tarteel.tarteel

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

/** The existing preference file is retained across upgrades. No network or Dart isolate is required. */
internal object LocalAlarmScheduler {
    private fun prefs(context: Context) = context.getSharedPreferences("local_audio_alarms_v2", Context.MODE_PRIVATE)
    private fun pending(context: Context, record: JSONObject) = PendingIntent.getBroadcast(context, record.getInt("id"),
        Intent(context, LocalAudioAlarmReceiver::class.java).putExtra("id", record.getInt("id"))
            .putExtra("scheduledTime", record.getLong("time")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun exactAvailable(context: Context): Boolean = Build.VERSION.SDK_INT < 31 ||
        context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    @Synchronized fun schedule(context: Context, record: JSONObject) {
        val id = record.getInt("id")
        val time = record.getLong("time")
        require(id >= 0 && time > System.currentTimeMillis()) { "ALARM_TIME_PASSED_OR_INVALID_ID" }
        ZoneId.of(record.optString("timezone", "Asia/Aden"))
        record.put("generationVersion", 1)
        val manager = context.getSystemService(AlarmManager::class.java)
        val alarm = pending(context, record)
        // Save first so a broadcast can never observe an alarm without its local audio/settings.
        check(prefs(context).edit().putString(id.toString(), record.toString()).commit()) { "ALARM_STORAGE_FAILED" }
        try {
            if (record.optBoolean("preferExact", true) && exactAvailable(context)) {
                try { manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarm) }
                catch (_: SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarm) }
            } else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarm)
        } catch (error: Exception) {
            prefs(context).edit().remove(id.toString()).commit()
            throw error
        }
    }
    @Synchronized fun cancel(context: Context, id: Int) {
        val record = JSONObject().put("id", id).put("time", 0L)
        context.getSystemService(AlarmManager::class.java).cancel(pending(context, record))
        prefs(context).edit().remove(id.toString()).commit()
    }
    @Synchronized fun read(context: Context, id: Int): JSONObject? = prefs(context).getString(id.toString(), null)?.let(::JSONObject)

    internal fun nextDaily(record: JSONObject, now: Long): Long {
        val zone = ZoneId.of(record.optString("timezone", "Asia/Aden"))
        var next = Instant.ofEpochMilli(record.getLong("time")).atZone(zone)
        do { next = next.plusDays(1) } while (next.toInstant().toEpochMilli() <= now)
        return next.toInstant().toEpochMilli()
    }

    /** Consume before launching: duplicate broadcasts and stale PendingIntents cannot play twice. */
    @Synchronized fun consume(context: Context, id: Int, expectedTime: Long): JSONObject? {
        val record = read(context, id) ?: return null
        val time = record.getLong("time")
        // Version 2074 PendingIntents did not include scheduledTime. Accept only an
        // unmigrated record; restoring/replacing stamps version 1 and requires a match.
        val legacy = expectedTime == -1L && record.optInt("generationVersion", 0) == 0
        if ((!legacy && expectedTime != time) || System.currentTimeMillis() < time - 1000L) return null
        cancel(context, id)
        if (record.optBoolean("repeatDaily")) {
            val next = JSONObject(record.toString()).put("time", nextDaily(record, System.currentTimeMillis()))
            try { schedule(context, next) }
            catch (error: Exception) {
                // A failure scheduling tomorrow must not discard today's audible reminder.
                context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit()
                    .putString("lastRescheduleFailure", error.javaClass.simpleName).apply()
            }
        }
        return record
    }

    /**
     * Solar prayer instants were calculated by adhan_dart for the explicitly selected
     * location/timezone. A device timezone edit must not shift those instants or silently
     * relocate the user. Fixed daily adhkar retain their selected zone and DST wall time.
     * Flutter refreshes the finite prayer horizon after settings edits and on resume.
     */
    @Synchronized fun restore(context: Context) {
        for ((key, value) in prefs(context).all) {
            try {
                val record = JSONObject(value as String)
                if (record.getLong("time") <= System.currentTimeMillis()) {
                    if (!record.optBoolean("repeatDaily")) { cancel(context, key.toInt()); continue }
                    record.put("time", nextDaily(record, System.currentTimeMillis()))
                }
                schedule(context, record)
            } catch (_: Exception) { prefs(context).edit().remove(key).apply() }
        }
    }

    fun diagnostics(context: Context): Map<String, Any> {
        val diagnostics = context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE)
        val power = context.getSystemService(android.os.PowerManager::class.java)
        val manager = context.getSystemService(NotificationManager::class.java)
        val audio = context.getSystemService(android.media.AudioManager::class.java)
        val records = prefs(context).all.values.mapNotNull {
            try { JSONObject(it as String) } catch (_: Exception) { null }
        }.filter { it.optLong("time") > System.currentTimeMillis() }
        val next = records.minByOrNull { it.optLong("time") }
        val times = records.map { it.optLong("time") }
        return mapOf("exactAlarms" to exactAvailable(context), "notifications" to manager.areNotificationsEnabled(),
            "alarmChannelEnabled" to (manager.getNotificationChannel(OfflineNotifications.ALARM_CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE),
            "batteryUnrestricted" to power.isIgnoringBatteryOptimizations(context.packageName),
            "alarmVolume" to audio.getStreamVolume(android.media.AudioManager.STREAM_ALARM),
            "alarmVolumeMax" to audio.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM),
            "scheduledCount" to times.size, "nextAlarmAt" to (times.minOrNull() ?: 0L),
            "nextAlarmTitle" to (next?.optString("title") ?: ""),
            "nextAlarmPath" to (next?.optString("path")?.substringAfterLast('/') ?: ""),
            "nextAlarmSilent" to (next?.optBoolean("playSound", true) == false),
            "manufacturer" to Build.MANUFACTURER, "dndFilter" to manager.currentInterruptionFilter,
            "eventsJson" to (diagnostics.getString("events", "[]") ?: "[]"),
            "lastReadyAt" to diagnostics.getLong("lastReadyAt", 0L),
            "lastFailure" to (diagnostics.getString("lastFailure", "") ?: ""),
            "lastRescheduleFailure" to (diagnostics.getString("lastRescheduleFailure", "") ?: ""),
            "lastRestoreAt" to diagnostics.getLong("lastRestoreAt", 0L), "sdk" to Build.VERSION.SDK_INT)
    }
}

class LocalAudioAlarmReceiver : BroadcastReceiver() {
    companion object { private val restoreExecutor = java.util.concurrent.Executors.newSingleThreadExecutor() }
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != null) {
            val completion = goAsync()
            restoreExecutor.execute {
                try {
                    LocalAlarmScheduler.restore(context)
                    context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit()
                        .putLong("lastRestoreAt", System.currentTimeMillis()).apply()
                } finally { completion.finish() }
            }
            return
        }
        val id = intent.getIntExtra("id", -1)
        val record = LocalAlarmScheduler.consume(context, id, intent.getLongExtra("scheduledTime", -1L)) ?: return
        val age = System.currentTimeMillis() - record.getLong("time")
        // Never replay an old prayer when the phone wakes hours later.
        if (age > 15 * 60 * 1000L) { AlarmDiagnostics.record(context, record, "SKIPPED_STALE"); return }
        AlarmDiagnostics.record(context, record, "RECEIVED")
        if (!record.optBoolean("playSound", true)) { AlarmDiagnostics.record(context, record, "SILENT_NOTIFICATION"); showFallback(context, record); return }
        try {
            context.startForegroundService(Intent(context, LocalAlarmAudioService::class.java)
                .putExtra("record", record.toString()))
        } catch (error: Exception) {
            AlarmDiagnostics.record(context, record, "BACKGROUND_START_FAILED")
            context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit()
                .putString("lastFailure", "BACKGROUND_START_${error.javaClass.simpleName}").apply()
            // Inexact alarms cannot always start an FGS on Android 12+. Keep the visible reminder.
            showFallback(context, record)
        }
    }
    private fun showFallback(context: Context, record: JSONObject) {
        try {
            val notification = OfflineNotifications.build(context,
                if (record.optBoolean("playSound", true)) OfflineNotifications.ALARM_FALLBACK_CHANNEL else OfflineNotifications.ALARM_CHANNEL,
                record.optString("title", "ترتيل"), record.optString("body"), ongoing = false,
                payload = record.optString("payload"))
            context.getSystemService(NotificationManager::class.java).notify(record.getInt("id"), notification)
        } catch (_: SecurityException) { /* Permission status remains available in diagnostics. */ }
    }
}

package app.tarteel.tarteel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

/** Persist only local file paths. Boot restores alarms without starting playback. */
internal object LocalAlarmScheduler {
    private fun prefs(context: Context) = context.getSharedPreferences("local_audio_alarms_v2", Context.MODE_PRIVATE)
    private fun pending(context: Context, id: Int) = PendingIntent.getBroadcast(context, id,
        Intent(context, LocalAudioAlarmReceiver::class.java).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun exactAvailable(context: Context): Boolean = Build.VERSION.SDK_INT < 31 ||
        context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun schedule(context: Context, record: JSONObject) {
        val id = record.getInt("id")
        val time = record.getLong("time")
        require(time > System.currentTimeMillis()) { "ALARM_TIME_PASSED" }
        prefs(context).edit().putString(id.toString(), record.toString()).commit()
        val manager = context.getSystemService(AlarmManager::class.java)
        if (exactAvailable(context)) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending(context, id))
        else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending(context, id))
    }
    fun cancel(context: Context, id: Int) {
        context.getSystemService(AlarmManager::class.java).cancel(pending(context, id))
        prefs(context).edit().remove(id.toString()).commit()
    }
    fun read(context: Context, id: Int): JSONObject? = prefs(context).getString(id.toString(), null)?.let(::JSONObject)
    private fun nextDaily(record: JSONObject, now: Long): Long {
        val zone = ZoneId.of(record.optString("timezone", "Asia/Aden"))
        var next = Instant.ofEpochMilli(record.getLong("time")).atZone(zone)
        do { next = next.plusDays(1) } while (next.toInstant().toEpochMilli() <= now)
        return next.toInstant().toEpochMilli()
    }
    fun fired(context: Context, record: JSONObject) {
        cancel(context, record.getInt("id"))
        if (record.optBoolean("repeatDaily")) {
            record.put("time", nextDaily(record, System.currentTimeMillis()))
            schedule(context, record)
        }
    }
    fun restore(context: Context) {
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
}

class LocalAudioAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != null) { LocalAlarmScheduler.restore(context); return }
        val record = LocalAlarmScheduler.read(context, intent.getIntExtra("id", -1)) ?: return
        // A stale alarm cannot sound after a user cancels or changes its time.
        val age = System.currentTimeMillis() - record.getLong("time")
        if (age < -1000L) return
        val launch = Intent(context, LocalAlarmAudioService::class.java).putExtra("record", record.toString())
        try {
            if (age <= 15 * 60 * 1000L) context.startForegroundService(launch)
        } catch (_: Exception) {
            // Inexact alarms on newer Android cannot always start an FGS.
            val notification = OfflineNotifications.build(context, OfflineNotifications.ALARM_CHANNEL,
                record.optString("title", "ترتيل"), record.optString("body"), ongoing = false)
            context.getSystemService(android.app.NotificationManager::class.java).notify(record.getInt("id"), notification)
        }
        LocalAlarmScheduler.fired(context, record)
    }
}

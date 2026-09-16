package app.tarteel.tarteel

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import com.batoulapps.adhan2.CalculationMethod
import com.batoulapps.adhan2.Coordinates
import com.batoulapps.adhan2.Madhab
import com.batoulapps.adhan2.PrayerAdjustments
import com.batoulapps.adhan2.PrayerTimes
import com.batoulapps.adhan2.data.DateComponents
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

object PrayerAlarmEngine {
    private const val PREFS = "tarteel_native_prayer_alarms_v1"
    private const val CONFIG = "config"
    private const val IDS = "scheduled_ids"
    private const val REFRESH_ID = 7_990_001
    private const val TEST_ID = 7_990_002
    private const val DAYS_AHEAD = 8

    const val ACTION_PRAYER = "app.tarteel.tarteel.PRAYER_ALARM"
    const val ACTION_REFRESH = "app.tarteel.tarteel.PRAYER_REFRESH"
    const val ACTION_STOP = "app.tarteel.tarteel.STOP_ADHAN"

    private val prayerNames = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    fun configure(context: Context, raw: Map<*, *>): Map<String, Any> {
        val config = mapToJson(raw)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(CONFIG, config.toString())
            .apply()
        val count = reschedule(context)
        return mapOf(
            "scheduled" to count,
            "exact" to canScheduleExact(context),
        )
    }

    fun disable(context: Context) {
        cancelAll(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(CONFIG)
            .apply()
    }

    fun status(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "configured" to prefs.contains(CONFIG),
            "scheduled" to (prefs.getStringSet(IDS, emptySet())?.size ?: 0),
            "exact" to canScheduleExact(context),
        )
    }

    fun scheduleTest(context: Context, playAdhan: Boolean): Map<String, Any> {
        val whenMillis = System.currentTimeMillis() + 10_000L
        val pending = prayerPendingIntent(
            context = context,
            id = TEST_ID,
            title = "اختبار منبه الصلاة",
            body = if (playAdhan) "سيعمل صوت الأذان التجريبي الآن" else "منبه الصلاة المحلي يعمل على هذا الجهاز",
            prayer = "test",
            mode = if (playAdhan) "adhan" else "notificationOnly",
            soundPath = null,
        )
        scheduleAlarm(context, TEST_ID, whenMillis, pending, showAsAlarmClock = true)
        return mapOf("scheduled" to true, "exact" to canScheduleExact(context))
    }

    fun reschedule(context: Context): Int {
        cancelScheduledPrayerAlarms(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(CONFIG, null) ?: return 0
        val config = try {
            JSONObject(raw)
        } catch (_: Throwable) {
            return 0
        }

        val timezone = config.optString("timezone", "Asia/Aden")
        val zone = try {
            ZoneId.of(timezone)
        } catch (_: Throwable) {
            ZoneId.systemDefault()
        }
        val latitude = config.optDouble("latitude", Double.NaN)
        val longitude = config.optDouble("longitude", Double.NaN)
        if (!latitude.isFinite() || !longitude.isFinite()) return 0

        val modes = config.optJSONObject("modes") ?: JSONObject()
        val manual = config.optJSONObject("manualTimes") ?: JSONObject()
        val rawSoundPath = config.optString("soundPath", "")
        val soundPath = rawSoundPath.takeIf { it.isNotBlank() }
        val now = Instant.now()
        val today = LocalDate.now(zone)
        val ids = mutableSetOf<String>()
        var scheduled = 0

        for (dayOffset in 0 until DAYS_AHEAD) {
            val date = today.plusDays(dayOffset.toLong())
            val calculated = calculatedTimes(config, date, latitude, longitude)
            prayerNames.forEachIndexed { index, prayer ->
                val mode = modes.optString(prayer, "disabled")
                if (mode == "disabled") return@forEachIndexed
                val trigger = if (manual.has(prayer)) {
                    val minutes = manual.optInt(prayer, -1)
                    if (minutes !in 0 until 1440) return@forEachIndexed
                    date.atTime(LocalTime.of(minutes / 60, minutes % 60))
                        .atZone(zone)
                        .toInstant()
                        .toEpochMilli()
                } else {
                    calculated[prayer] ?: return@forEachIndexed
                }
                if (trigger <= now.toEpochMilli() + 2_000L) return@forEachIndexed

                val id = requestCode(date, index)
                val title = "ترتيل"
                val body = if (mode == "adhan") {
                    "حان موعد أذان صلاة ${prayerArabic(prayer)}"
                } else {
                    "حان موعد صلاة ${prayerArabic(prayer)}"
                }
                val pending = prayerPendingIntent(
                    context = context,
                    id = id,
                    title = title,
                    body = body,
                    prayer = prayer,
                    mode = mode,
                    soundPath = soundPath,
                )
                scheduleAlarm(context, id, trigger, pending, showAsAlarmClock = true)
                ids.add(id.toString())
                scheduled++
            }
        }

        prefs.edit().putStringSet(IDS, ids).apply()
        scheduleRefresh(context, zone)
        return scheduled
    }

    private fun calculatedTimes(
        config: JSONObject,
        date: LocalDate,
        latitude: Double,
        longitude: Double,
    ): Map<String, Long> {
        val method = calculationMethod(config.optString("method", "muslimWorldLeague"))
        val madhab = if (config.optString("madhab", "shafi") == "hanafi") Madhab.HANAFI else Madhab.SHAFI
        val offsets = config.optJSONObject("offsets") ?: JSONObject()
        fun adjustment(name: String): Int = offsets.optInt(name, 0).coerceIn(-60, 60)
        val parameters = method.parameters.copy(
            madhab = madhab,
            prayerAdjustments = PrayerAdjustments(
                fajr = adjustment("fajr"),
                sunrise = adjustment("sunrise"),
                dhuhr = adjustment("dhuhr"),
                asr = adjustment("asr"),
                maghrib = adjustment("maghrib"),
                isha = adjustment("isha"),
            ),
        )
        val times = PrayerTimes(
            Coordinates(latitude, longitude),
            DateComponents(date.year, date.monthValue, date.dayOfMonth),
            parameters,
        )
        return mapOf(
            "fajr" to times.fajr.toEpochMilliseconds(),
            "dhuhr" to times.dhuhr.toEpochMilliseconds(),
            "asr" to times.asr.toEpochMilliseconds(),
            "maghrib" to times.maghrib.toEpochMilliseconds(),
            "isha" to times.isha.toEpochMilliseconds(),
        )
    }

    private fun scheduleRefresh(context: Context, zone: ZoneId) {
        val tomorrow = LocalDate.now(zone).plusDays(1)
            .atTime(0, 10)
            .atZone(zone)
            .toInstant()
            .toEpochMilli()
        val intent = Intent(context, PrayerScheduleReceiver::class.java).apply {
            action = ACTION_REFRESH
        }
        val pending = PendingIntent.getBroadcast(
            context,
            REFRESH_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        scheduleAlarm(context, REFRESH_ID, tomorrow, pending, showAsAlarmClock = false)
    }

    private fun scheduleAlarm(
        context: Context,
        id: Int,
        triggerAtMillis: Long,
        operation: PendingIntent,
        showAsAlarmClock: Boolean,
    ) {
        val manager = context.getSystemService(AlarmManager::class.java)
        if (canScheduleExact(context)) {
            if (showAsAlarmClock) {
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
                val showIntent = PendingIntent.getActivity(
                    context,
                    id,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent), operation)
            } else {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            }
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
        }
    }

    private fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    }

    private fun cancelScheduledPrayerAlarms(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(IDS, emptySet())?.toSet() ?: emptySet()
        val manager = context.getSystemService(AlarmManager::class.java)
        for (value in ids) {
            val id = value.toIntOrNull() ?: continue
            val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                action = ACTION_PRAYER
            }
            val pending = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pending != null) manager.cancel(pending)
        }
        prefs.edit().remove(IDS).apply()
    }

    private fun cancelAll(context: Context) {
        cancelScheduledPrayerAlarms(context)
        val manager = context.getSystemService(AlarmManager::class.java)
        val refresh = PendingIntent.getBroadcast(
            context,
            REFRESH_ID,
            Intent(context, PrayerScheduleReceiver::class.java).apply { action = ACTION_REFRESH },
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (refresh != null) manager.cancel(refresh)
    }

    private fun prayerPendingIntent(
        context: Context,
        id: Int,
        title: String,
        body: String,
        prayer: String,
        mode: String,
        soundPath: String?,
    ): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_PRAYER
            putExtra("alarm_id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("prayer", prayer)
            putExtra("mode", mode)
            putExtra("sound_path", soundPath)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun requestCode(date: LocalDate, prayerIndex: Int): Int {
        val day = (date.toEpochDay() % 100_000L).toInt()
        return 2_000_000 + day * 10 + prayerIndex
    }

    private fun prayerArabic(name: String): String = when (name) {
        "fajr" -> "الفجر"
        "dhuhr" -> "الظهر"
        "asr" -> "العصر"
        "maghrib" -> "المغرب"
        "isha" -> "العشاء"
        else -> "الصلاة"
    }

    private fun calculationMethod(name: String): CalculationMethod = when (name) {
        "egyptian" -> CalculationMethod.EGYPTIAN
        "karachi" -> CalculationMethod.KARACHI
        "ummAlQura" -> CalculationMethod.UMM_AL_QURA
        "dubai" -> CalculationMethod.DUBAI
        "qatar" -> CalculationMethod.QATAR
        "kuwait" -> CalculationMethod.KUWAIT
        "moonSightingCommittee" -> CalculationMethod.MOON_SIGHTING_COMMITTEE
        "singapore" -> CalculationMethod.SINGAPORE
        "northAmerica" -> CalculationMethod.NORTH_AMERICA
        "turkey" -> CalculationMethod.TURKEY
        else -> CalculationMethod.MUSLIM_WORLD_LEAGUE
    }

    private fun mapToJson(map: Map<*, *>): JSONObject {
        val result = JSONObject()
        for ((key, value) in map) {
            if (key !is String) continue
            result.put(
                key,
                when (value) {
                    is Map<*, *> -> mapToJson(value)
                    null -> JSONObject.NULL
                    else -> value
                },
            )
        }
        return result
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PrayerAlarmEngine.ACTION_PRAYER) return
        val mode = intent.getStringExtra("mode") ?: "notificationOnly"
        if (mode == "adhan") {
            val service = Intent(context, PrayerAlarmService::class.java).apply {
                putExtras(intent)
            }
            context.startForegroundService(service)
        } else {
            PrayerAlarmNotifications.show(context, intent, silent = mode == "silent")
        }
    }
}

class PrayerScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Thread {
            try {
                PrayerAlarmEngine.reschedule(context.applicationContext)
            } finally {
                pending.finish()
            }
        }.start()
    }
}

class PrayerAlarmStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.stopService(Intent(context, PrayerAlarmService::class.java))
    }
}

private object PrayerAlarmNotifications {
    private const val NORMAL_CHANNEL = "tarteel_prayer_alarm_v2"
    private const val SILENT_CHANNEL = "tarteel_prayer_silent_v2"
    private const val ADHAN_CHANNEL = "tarteel_adhan_playback_v2"

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val alarmAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val normal = NotificationChannel(
            NORMAL_CHANNEL,
            "منبهات الصلاة",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "تنبيهات مواقيت الصلاة اليومية"
            enableVibration(true)
            setSound(Settings.System.DEFAULT_NOTIFICATION_URI, alarmAttributes)
        }
        val silent = NotificationChannel(
            SILENT_CHANNEL,
            "منبهات الصلاة الصامتة",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "تنبيهات الصلاة الصامتة"
            enableVibration(false)
            setSound(null, null)
        }
        val adhan = NotificationChannel(
            ADHAN_CHANNEL,
            "الأذان الجاري",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "تشغيل الأذان في موعد الصلاة"
            enableVibration(true)
            setSound(null, null)
        }
        manager.createNotificationChannel(normal)
        manager.createNotificationChannel(silent)
        manager.createNotificationChannel(adhan)
    }

    fun show(context: Context, intent: Intent, silent: Boolean) {
        ensureChannels(context)
        val id = intent.getIntExtra("alarm_id", 4_100)
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = PendingIntent.getActivity(
            context,
            id,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(context, if (silent) SILENT_CHANNEL else NORMAL_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_tarteel)
            .setContentTitle(intent.getStringExtra("title") ?: "ترتيل")
            .setContentText(intent.getStringExtra("body") ?: "حان موعد الصلاة")
            .setContentIntent(openPending)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(id, notification)
    }

    fun adhanNotification(context: Context, intent: Intent): Notification {
        ensureChannels(context)
        val id = intent.getIntExtra("alarm_id", 4_100)
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = PendingIntent.getActivity(
            context,
            id,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopPending = PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, PrayerAlarmStopReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(context, ADHAN_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_tarteel)
            .setContentTitle(intent.getStringExtra("title") ?: "ترتيل")
            .setContentText(intent.getStringExtra("body") ?: "حان موعد الصلاة")
            .setContentIntent(openPending)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(android.R.drawable.ic_media_pause, "إيقاف الأذان", stopPending)
            .build()
    }
}

class PrayerAlarmService : Service() {
    private var player: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        if (intent.action == PrayerAlarmEngine.ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val notificationId = intent.getIntExtra("alarm_id", 4_100)
        startForeground(notificationId, PrayerAlarmNotifications.adhanNotification(this, intent))
        play(intent.getStringExtra("sound_path"))
        return START_NOT_STICKY
    }

    private fun play(soundPath: String?) {
        stopPlayback()
        try {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            audioManager = getSystemService(AudioManager::class.java)
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener { }
                .build()
            audioManager?.requestAudioFocus(focusRequest!!)

            val media = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                if (!soundPath.isNullOrBlank() && File(soundPath).isFile) {
                    setDataSource(soundPath)
                } else {
                    val descriptor = resources.openRawResourceFd(R.raw.adhan)
                    setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                    descriptor.close()
                }
                setOnCompletionListener { stopSelf() }
                setOnErrorListener { _, _, _ ->
                    stopSelf()
                    true
                }
                prepare()
            }
            player = media
            media.start()
        } catch (_: Throwable) {
            stopSelf()
        }
    }

    private fun stopPlayback() {
        try {
            player?.stop()
        } catch (_: Throwable) {
        }
        try {
            player?.release()
        } catch (_: Throwable) {
        }
        player = null
        val request = focusRequest
        if (request != null) {
            try {
                audioManager?.abandonAudioFocusRequest(request)
            } catch (_: Throwable) {
            }
        }
        focusRequest = null
    }

    override fun onDestroy() {
        stopPlayback()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}

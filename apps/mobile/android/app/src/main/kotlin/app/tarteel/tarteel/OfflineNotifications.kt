package app.tarteel.tarteel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

internal object OfflineNotifications {
    const val TASK_CHANNEL = "tarteel_offline_tasks_v2"
    const val ALARM_CHANNEL = "tarteel_local_alarm_v2"
    const val ALARM_FALLBACK_CHANNEL = "tarteel_local_alarm_fallback_v1"

    fun build(context: Context, channel: String, title: String, text: String,
              ongoing: Boolean = true, progress: Int = -1,
              stopIntent: Intent? = null, payload: String? = null): Notification {
        val manager = context.getSystemService(NotificationManager::class.java)
        val alarmChannel = channel == ALARM_CHANNEL || channel == ALARM_FALLBACK_CHANNEL
        manager.createNotificationChannel(NotificationChannel(channel,
            if (channel == ALARM_FALLBACK_CHANNEL) "تنبيه بديل عند تعذر الصوت"
                else if (alarmChannel) "الأذان والمنبه المحلي" else "التنزيل والتسجيل",
            if (alarmChannel) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_LOW
        ).apply {
            if (channel == ALARM_FALLBACK_CHANNEL) setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION).build())
            else setSound(null, null)
            enableVibration(false)
        })
        val openIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("alarmPayload", payload)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val open = PendingIntent.getActivity(context, payload?.hashCode() ?: 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = Notification.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_stat_tarteel)
            .setContentTitle(title).setContentText(text).setContentIntent(open)
            .setOngoing(ongoing).setOnlyAlertOnce(true)
            .setCategory(if (alarmChannel) Notification.CATEGORY_ALARM else Notification.CATEGORY_PROGRESS)
        if (channel == TASK_CHANNEL) builder.setProgress(100, progress.coerceAtLeast(0), progress < 0)
        if (stopIntent != null) {
            val stop = PendingIntent.getService(context, 0, stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(Notification.Action.Builder(null, "إيقاف", stop).build())
        }
        return builder.build()
    }
}

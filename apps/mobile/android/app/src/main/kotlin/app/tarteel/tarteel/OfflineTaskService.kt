package app.tarteel.tarteel

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Keeps user-initiated Dart transfers visible while the app is backgrounded.
 * Partial transfers remain resumable on the next launch after process death. */
class OfflineTaskService : Service() {
    private val tasks = linkedMapOf<String, Pair<String, Int>>()
    private var lock: PowerManager.WakeLock? = null
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra("id") ?: "download"
        if (intent?.action == "finish") tasks.remove(id)
        else tasks[id] = Pair(intent?.getStringExtra("title") ?: "تنزيل", intent?.getIntExtra("progress", -1) ?: -1)
        if (tasks.isEmpty()) { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return START_NOT_STICKY }
        val task = tasks.values.last()
        val notification = OfflineNotifications.build(this, OfflineNotifications.TASK_CHANNEL,
            "ترتيل", task.first, progress = task.second)
        if (Build.VERSION.SDK_INT >= 29) startForeground(8101, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(8101, notification)
        if (lock == null) {
            lock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tarteel:transfer").apply {
                acquire(2 * 60 * 60 * 1000L)
            }
        }
        return START_NOT_STICKY
    }
    override fun onTimeout(startId: Int, fgsType: Int) { stopSelf() }
    override fun onDestroy() { lock?.takeIf { it.isHeld }?.release(); lock = null; super.onDestroy() }
}

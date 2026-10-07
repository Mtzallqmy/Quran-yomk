package app.tarteel.tarteel

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OfflineAlarmTest {
    private val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
    @Test fun storesLocalSoundAndRestoresAfterRestart() {
        val id = 8_900_001
        val sound = java.io.File(context.filesDir, "test-adhan.ogg")
        context.resources.openRawResource(R.raw.adhan).use { input -> sound.outputStream().use { input.copyTo(it) } }
        val record = JSONObject().put("id", id).put("title", "اختبار محلي").put("body", "دون إنترنت")
            .put("path", sound.absolutePath).put("time", System.currentTimeMillis() + 60000)
            .put("repeatDaily", true).put("timezone", "Asia/Aden")
        LocalAlarmScheduler.schedule(context, record)
        assertEquals(sound.absolutePath, LocalAlarmScheduler.read(context, id)!!.getString("path"))
        LocalAlarmScheduler.restore(context)
        assertNotNull(LocalAlarmScheduler.read(context, id))
        LocalAlarmScheduler.cancel(context, id)
        assertNull(LocalAlarmScheduler.read(context, id))
        sound.delete()
    }
    @Test fun exactAlarmStartsSelectedLocalAudioWhileAppBackgrounded() {
        assertTrue(LocalAlarmScheduler.exactAvailable(context))
        val id = 8_900_003
        val sound = java.io.File(context.filesDir, "selected-test.ogg")
        context.resources.openRawResource(R.raw.adhan).use { input -> sound.outputStream().use { input.copyTo(it) } }
        val before = System.currentTimeMillis()
        context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit().clear().commit()
        val record = JSONObject().put("id", id).put("title", "تجربة الأذان")
            .put("path", sound.absolutePath).put("time", before + 2000).put("timezone", "Asia/Aden")
        LocalAlarmScheduler.schedule(context, record)
        InstrumentationRegistry.getInstrumentation().uiAutomation.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
        val prefs = context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE)
        val deadline = System.currentTimeMillis() + 15000
        while (prefs.getLong("lastReadyAt", 0L) < before && System.currentTimeMillis() < deadline) Thread.sleep(100)
        assertEquals(sound.absolutePath, prefs.getString("lastPath", null))
        assertTrue(prefs.getLong("lastReadyAt", 0L) >= before)
        context.stopService(android.content.Intent(context, LocalAlarmAudioService::class.java))
        LocalAlarmScheduler.cancel(context, id); sound.delete()
    }
    @Test fun missedDailyAlarmMovesToFutureWithoutPlayingAtBoot() {
        val id = 8_900_002
        val record = JSONObject().put("id", id).put("title", "منبه")
            .put("time", System.currentTimeMillis() - 1000).put("repeatDaily", true).put("timezone", "Asia/Aden")
        context.getSharedPreferences("local_audio_alarms_v2", Context.MODE_PRIVATE).edit().putString(id.toString(), record.toString()).commit()
        LocalAlarmScheduler.restore(context)
        assertTrue(LocalAlarmScheduler.read(context, id)!!.getLong("time") > System.currentTimeMillis())
        LocalAlarmScheduler.cancel(context, id)
    }
    @Test fun microphoneRecordingSavesPlayableAudioAfterBackgroundStop() {
        context.startActivity(android.content.Intent(context, MainActivity::class.java)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        Thread.sleep(1500)
        context.getSharedPreferences("recitation_recordings", Context.MODE_PRIVATE).edit().clear().commit()
        context.startForegroundService(android.content.Intent(context, RecitationRecorderService::class.java)
            .putExtra("title", "اختبار التسجيل").putExtra("limitMs", 10000L))
        val deadline = System.currentTimeMillis() + 10000
        while (!RecitationRecorderService.active && System.currentTimeMillis() < deadline) Thread.sleep(100)
        assertTrue("Microphone started: ${RecitationRecorderService.lastError}", RecitationRecorderService.active)
        InstrumentationRegistry.getInstrumentation().uiAutomation.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
        Thread.sleep(2500)
        context.startService(android.content.Intent(context, RecitationRecorderService::class.java).setAction("stop"))
        val stopDeadline = System.currentTimeMillis() + 5000
        while (org.json.JSONArray(RecitationRecorderService.completed(context)).length() == 0 && System.currentTimeMillis() < stopDeadline) Thread.sleep(100)
        val rows = org.json.JSONArray(RecitationRecorderService.completed(context))
        assertEquals("Recording saved: ${RecitationRecorderService.lastError}", 1, rows.length())
        val file = java.io.File(rows.getJSONObject(0).getString("path"))
        assertTrue(file.isFile && file.length() > 1024)
        val reader = android.media.MediaMetadataRetriever()
        try {
            reader.setDataSource(file.absolutePath)
            assertTrue(reader.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)!!.toLong() > 1000)
        } finally { reader.release(); file.delete() }
        context.getSharedPreferences("recitation_recordings", Context.MODE_PRIVATE).edit().clear().commit()
    }
}

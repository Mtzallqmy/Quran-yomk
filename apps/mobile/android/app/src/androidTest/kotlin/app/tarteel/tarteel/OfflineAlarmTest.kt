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
}

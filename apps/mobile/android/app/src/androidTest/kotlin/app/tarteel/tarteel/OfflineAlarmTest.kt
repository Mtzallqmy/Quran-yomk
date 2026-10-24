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
    @Test fun diagnosticsKeepBoundedHistoryWithoutPrivatePaths() {
        val alarm = JSONObject().put("id", 8900009).put("title", "تجربة").put("time", System.currentTimeMillis()+60000).put("path", "/private/sound.mp3")
        repeat(30) { AlarmDiagnostics.record(context, alarm, "AUDIO_READY") }
        val raw = LocalAlarmScheduler.diagnostics(context)["eventsJson"] as String
        assertEquals(24, org.json.JSONArray(raw).length())
        assertFalse(raw.contains("/private/"))
    }
    @Test fun allNewBundledAdhanFilesAreDecodableOffline() {
        for (name in listOf("makkah", "madinah", "kazakhstan", "sweden_fajr")) {
            val file = java.io.File(context.cacheDir, "test-$name.ogg")
            val retriever = android.media.MediaMetadataRetriever()
            try {
                context.assets.open("flutter_assets/assets/audio/adhan_$name.ogg").use { input ->
                    file.outputStream().use { input.copyTo(it) }
                }
                retriever.setDataSource(file.absolutePath)
                assertTrue("$name contains a long local recording", (retriever.extractMetadata(
                    android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) > 140_000L)
                assertEquals("yes", retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO))
            } finally { retriever.release(); file.delete() }
        }
    }
    @Test fun allUserSuppliedMp3FilesAreReadableOffline() {
        for (name in listOf("makkah", "madinah", "egypt", "abdul_basit", "minshawi")) {
            val file = java.io.File(context.cacheDir, "test-user-$name.mp3")
            val retriever = android.media.MediaMetadataRetriever()
            try {
                context.assets.open("flutter_assets/assets/audio/user_$name.mp3").use { input -> file.outputStream().use { input.copyTo(it) } }
                retriever.setDataSource(file.absolutePath)
                assertTrue((retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) > 60_000L)
            } finally { retriever.release(); file.delete() }
        }
    }
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
    @Test fun exactAlarmStartsSelectedLocalAudioWithScreenOff() {
        assertTrue(LocalAlarmScheduler.exactAvailable(context))
        val id = 8_900_003
        val sound = java.io.File(context.filesDir, "selected-test.ogg")
        context.resources.openRawResource(R.raw.adhan).use { input -> sound.outputStream().use { input.copyTo(it) } }
        val before = System.currentTimeMillis()
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit().clear().commit()
        try {
            val record = JSONObject().put("id", id).put("title", "تجربة الأذان")
                .put("path", sound.absolutePath).put("time", before + 3000).put("timezone", "Asia/Aden")
            LocalAlarmScheduler.schedule(context, record)
            automation.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
            automation.executeShellCommand("input keyevent 223").use { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            val power = context.getSystemService(android.os.PowerManager::class.java)
            val screenDeadline = System.currentTimeMillis() + 2000L
            while (power.isInteractive && System.currentTimeMillis() < screenDeadline) Thread.sleep(100)
            assertFalse("The local alarm must be tested while the screen is off", power.isInteractive)
            val prefs = context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE)
            val deadline = System.currentTimeMillis() + 20000L
            while (prefs.getLong("lastReadyAt", 0L) < before && System.currentTimeMillis() < deadline) Thread.sleep(100)
            assertEquals(sound.absolutePath, prefs.getString("lastPath", null))
            assertTrue("Media3 prepared the imported local sound with screen off", prefs.getLong("lastReadyAt", 0L) >= before)
        } finally {
            context.stopService(android.content.Intent(context, LocalAlarmAudioService::class.java))
            LocalAlarmScheduler.cancel(context, id)
            automation.executeShellCommand("input keyevent 224").use { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            automation.executeShellCommand("wm dismiss-keyguard").close()
            sound.delete()
        }
    }
    @Test fun bundledMadinahAdhanStartsWithScreenOff() {
        assertTrue(LocalAlarmScheduler.exactAvailable(context))
        val id = 8_900_005
        val path = "assets/audio/adhan_madinah.ogg"
        val before = System.currentTimeMillis()
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit().clear().commit()
        try {
            val record = JSONObject().put("id", id).put("title", "تجربة الأذان")
                .put("path", path).put("time", before + 3000).put("timezone", "Asia/Aden")
            LocalAlarmScheduler.schedule(context, record)
            automation.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
            automation.executeShellCommand("input keyevent 223").use { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            val power = context.getSystemService(android.os.PowerManager::class.java)
            val screenDeadline = System.currentTimeMillis() + 2000L
            while (power.isInteractive && System.currentTimeMillis() < screenDeadline) Thread.sleep(100)
            assertFalse("The local alarm must be tested while the screen is off", power.isInteractive)
            val prefs = context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE)
            val deadline = System.currentTimeMillis() + 20000L
            while (prefs.getLong("lastReadyAt", 0L) < before && System.currentTimeMillis() < deadline) Thread.sleep(100)
            assertEquals(path, prefs.getString("lastPath", null))
            assertTrue("Media3 prepared the bundled Madinah recording with screen off", prefs.getLong("lastReadyAt", 0L) >= before)
        } finally {
            context.stopService(android.content.Intent(context, LocalAlarmAudioService::class.java))
            LocalAlarmScheduler.cancel(context, id)
            automation.executeShellCommand("input keyevent 224").use { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            automation.executeShellCommand("wm dismiss-keyguard").close()
        }
    }
    @Test fun userSuppliedMakkahMp3StartsWithScreenOff() {
        assertTrue(LocalAlarmScheduler.exactAvailable(context))
        val id = 8_900_006
        val path = "assets/audio/user_makkah.mp3"
        val before = System.currentTimeMillis()
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE).edit().clear().commit()
        try {
            val record = JSONObject().put("id", id).put("title", "تجربة الأذان")
                .put("path", path).put("time", before + 3000).put("timezone", "Asia/Aden")
            LocalAlarmScheduler.schedule(context, record)
            automation.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
            automation.executeShellCommand("input keyevent 223").use { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            val power = context.getSystemService(android.os.PowerManager::class.java)
            val screenDeadline = System.currentTimeMillis() + 2000L
            while (power.isInteractive && System.currentTimeMillis() < screenDeadline) Thread.sleep(100)
            assertFalse("The local alarm must be tested while the screen is off", power.isInteractive)
            val prefs = context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE)
            val deadline = System.currentTimeMillis() + 20000L
            while (prefs.getLong("lastReadyAt", 0L) < before && System.currentTimeMillis() < deadline) Thread.sleep(100)
            assertEquals(path, prefs.getString("lastPath", null))
            assertTrue("Media3 prepared the user supplied Makkah MP3 with screen off", prefs.getLong("lastReadyAt", 0L) >= before)
        } finally {
            context.stopService(android.content.Intent(context, LocalAlarmAudioService::class.java))
            LocalAlarmScheduler.cancel(context, id)
            automation.executeShellCommand("input keyevent 224").use { descriptor ->
                android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            }
            automation.executeShellCommand("wm dismiss-keyguard").close()
        }
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
    @Test fun duplicateAndStaleBroadcastsCannotConsumeReplacementAlarm() {
        val id = 8_900_004
        val firstTime = System.currentTimeMillis() + 60_000L
        val record = JSONObject().put("id", id).put("time", firstTime).put("timezone", "Asia/Aden")
        LocalAlarmScheduler.schedule(context, record)
        // An already queued broadcast from the old schedule must not trigger the changed prayer time.
        val replacementTime = firstTime + 60_000L
        LocalAlarmScheduler.schedule(context, JSONObject(record.toString()).put("time", replacementTime))
        assertNull(LocalAlarmScheduler.consume(context, id, firstTime))
        assertEquals(replacementTime, LocalAlarmScheduler.read(context, id)!!.getLong("time"))
        LocalAlarmScheduler.cancel(context, id)
        assertNull(LocalAlarmScheduler.consume(context, id, replacementTime))
    }
    @Test fun version2074PendingIntentMigratesWithoutAllowingNewStaleBroadcasts() {
        val id = 8_900_006
        val time = System.currentTimeMillis() - 100L
        val record = JSONObject().put("id", id).put("time", time).put("timezone", "Asia/Aden")
        val prefs = context.getSharedPreferences("local_audio_alarms_v2", Context.MODE_PRIVATE)
        prefs.edit().putString(id.toString(), record.toString()).commit()
        assertNotNull("A 2074 alarm still delivers before restoration", LocalAlarmScheduler.consume(context, id, -1L))
        assertNull(LocalAlarmScheduler.consume(context, id, -1L))
        prefs.edit().putString(id.toString(), record.put("generationVersion", 1).toString()).commit()
        assertNull("A migrated alarm always requires its exact generation", LocalAlarmScheduler.consume(context, id, -1L))
        LocalAlarmScheduler.cancel(context, id)
    }
    @Test fun dailyWallTimeFollowsDaylightSavingInsteadOfAdding24Hours() {
        val zone = java.time.ZoneId.of("Europe/Berlin")
        val before = java.time.ZonedDateTime.of(2026, 3, 28, 8, 0, 0, 0, zone)
        val record = JSONObject().put("time", before.toInstant().toEpochMilli()).put("timezone", zone.id)
        val next = java.time.Instant.ofEpochMilli(LocalAlarmScheduler.nextDaily(record,
            before.toInstant().toEpochMilli())).atZone(zone)
        assertEquals(8, next.hour)
        assertEquals(29, next.dayOfMonth)
        assertEquals(23L * 60 * 60 * 1000, next.toInstant().toEpochMilli() - before.toInstant().toEpochMilli())
    }
    @Test fun deliveredAlarmIsConsumedOnceAndDailyAlarmAdvances() {
        val id = 8_900_005
        val time = System.currentTimeMillis() - 100L
        val record = JSONObject().put("id", id).put("time", time).put("repeatDaily", true).put("timezone", "Asia/Aden")
        context.getSharedPreferences("local_audio_alarms_v2", Context.MODE_PRIVATE).edit()
            .putString(id.toString(), record.toString()).commit()
        assertNotNull(LocalAlarmScheduler.consume(context, id, time))
        assertNull(LocalAlarmScheduler.consume(context, id, time))
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

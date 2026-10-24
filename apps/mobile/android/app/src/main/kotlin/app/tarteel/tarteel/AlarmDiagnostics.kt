package app.tarteel.tarteel

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Bounded device-only diagnostics, never a guarantee of audible output. */
object AlarmDiagnostics {
    @Synchronized fun record(context: Context, alarm: JSONObject?, state: String) {
        val prefs = context.getSharedPreferences("alarm_diagnostics", Context.MODE_PRIVATE)
        val old = try { JSONArray(prefs.getString("events", "[]")) } catch (_: Exception) { JSONArray() }
        val events = JSONArray()
        for (i in maxOf(0, old.length() - 23) until old.length()) events.put(old.getJSONObject(i))
        events.put(JSONObject().put("at", System.currentTimeMillis()).put("state", state)
            .put("id", alarm?.optInt("id", -1) ?: -1).put("title", alarm?.optString("title", "ترتيل") ?: "ترتيل")
            .put("scheduledAt", alarm?.optLong("time", 0L) ?: 0L))
        prefs.edit().putString("events", events.toString()).apply()
    }
}

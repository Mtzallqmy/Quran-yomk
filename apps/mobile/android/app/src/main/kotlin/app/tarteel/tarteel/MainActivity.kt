package app.tarteel.tarteel

import android.content.Intent
import android.provider.Settings
import com.batoulapps.adhan2.CalculationMethod
import com.batoulapps.adhan2.Coordinates
import com.batoulapps.adhan2.Madhab
import com.batoulapps.adhan2.PrayerAdjustments
import com.batoulapps.adhan2.PrayerTimes
import com.batoulapps.adhan2.Qibla
import com.batoulapps.adhan2.data.DateComponents
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "app.tarteel.tarteel/settings").setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            startActivity(intent)
            result.success(true)
        }

        MethodChannel(messenger, "app.tarteel.tarteel/adhan").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "calculatePrayerTimes" -> result.success(calculatePrayerTimes(call.arguments as? Map<*, *>))
                    "qiblaDirection" -> {
                        val args = call.arguments as? Map<*, *> ?: error("INVALID_ARGUMENTS")
                        val latitude = (args["latitude"] as Number).toDouble()
                        val longitude = (args["longitude"] as Number).toDouble()
                        result.success(Qibla(Coordinates(latitude, longitude)).direction)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("ADHAN_KOTLIN_ERROR", error.message ?: error.javaClass.simpleName, null)
            }
        }
    }

    private fun calculatePrayerTimes(raw: Map<*, *>?): Map<String, Long> {
        val args = raw ?: error("INVALID_ARGUMENTS")
        val latitude = (args["latitude"] as Number).toDouble()
        val longitude = (args["longitude"] as Number).toDouble()
        val year = (args["year"] as Number).toInt()
        val month = (args["month"] as Number).toInt()
        val day = (args["day"] as Number).toInt()
        val method = calculationMethod(args["method"] as? String)
        val madhab = if (args["madhab"] == "hanafi") Madhab.HANAFI else Madhab.SHAFI
        val adjustments = args["adjustments"] as? Map<*, *> ?: emptyMap<Any, Any>()
        fun adjustment(name: String): Int = (adjustments[name] as? Number)?.toInt()?.coerceIn(-60, 60) ?: 0
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
            DateComponents(year, month, day),
            parameters,
        )
        return mapOf(
            "fajr" to times.fajr.toEpochMilliseconds(),
            "sunrise" to times.sunrise.toEpochMilliseconds(),
            "dhuhr" to times.dhuhr.toEpochMilliseconds(),
            "asr" to times.asr.toEpochMilliseconds(),
            "maghrib" to times.maghrib.toEpochMilliseconds(),
            "isha" to times.isha.toEpochMilliseconds(),
        )
    }

    private fun calculationMethod(name: String?): CalculationMethod = when (name) {
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
}

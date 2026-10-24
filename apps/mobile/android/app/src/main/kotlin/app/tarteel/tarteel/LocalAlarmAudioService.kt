package app.tarteel.tarteel

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import org.json.JSONObject
import java.io.File

/** Independent local alarm playback; never fetches remote audio or changes system volume. */
class LocalAlarmAudioService : Service() {
    private var player: ExoPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var pausedForFocus = false
    private var currentRecord: JSONObject? = null
    private var prepareWakeLock: android.os.PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") { stopSelf(); return START_NOT_STICKY }
        val record = try { JSONObject(intent?.getStringExtra("record") ?: "{}") }
            catch (_: Exception) { fail("INVALID_ALARM_RECORD"); return START_NOT_STICKY }
        currentRecord = record
        AlarmDiagnostics.record(this, record, "SERVICE_STARTED")
        val notification = OfflineNotifications.build(this, OfflineNotifications.ALARM_CHANNEL,
            record.optString("title", "ترتيل"), record.optString("body"),
            stopIntent = Intent(this, LocalAlarmAudioService::class.java).setAction("stop"),
            payload = record.optString("payload"))
        try {
            // Android 15+ also requires an active foreground service before requesting focus.
            if (Build.VERSION.SDK_INT >= 29) startForeground(8102, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(8102, notification)
            handler.removeCallbacksAndMessages(null)
            // AlarmManager's receiver wake lock ends when onReceive returns. Bridge local
            // player preparation until Media3 takes its own playback wake lock.
            if (prepareWakeLock?.isHeld == true) prepareWakeLock?.release()
            prepareWakeLock = getSystemService(android.os.PowerManager::class.java)
                .newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "tarteel:alarm-prepare")
                .apply { setReferenceCounted(false); acquire(30_000L) }
            player?.release(); player = null; pausedForFocus = false
            val path = record.optString("path")
            val uri = audioUri(path, record.optString("channel", "adhan"))
            val manager = getSystemService(AudioManager::class.java)
            focus?.let { manager.abandonAudioFocusRequest(it) }
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_ALARM)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setOnAudioFocusChangeListener({ change ->
                    when (change) {
                        AudioManager.AUDIOFOCUS_LOSS -> stopSelf()
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                            pausedForFocus = player?.isPlaying == true
                            player?.pause()
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> if (pausedForFocus) { pausedForFocus = false; player?.play() }
                    }
                }, handler).build()
            if (manager.requestAudioFocus(focus!!) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                fail("AUDIO_FOCUS_DENIED"); return START_NOT_STICKY
            }
            player = ExoPlayer.Builder(this).build().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_ALARM).setContentType(C.AUDIO_CONTENT_TYPE_SPEECH).build(), false)
                setWakeMode(C.WAKE_MODE_LOCAL)
                volume = record.optDouble("volume", 1.0).takeIf { it.isFinite() }?.coerceIn(0.0, 1.0)?.toFloat() ?: 1f
                addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(state: Int) {
                        if (state == Player.STATE_READY) {
                            AlarmDiagnostics.record(this@LocalAlarmAudioService, currentRecord, "AUDIO_READY")
                            getSharedPreferences("alarm_diagnostics", MODE_PRIVATE).edit()
                                .putString("lastPath", path).putLong("lastReadyAt", System.currentTimeMillis())
                                .putString("lastFailure", "").apply()
                            if (prepareWakeLock?.isHeld == true) prepareWakeLock?.release()
                        }
                        if (state == Player.STATE_ENDED) { AlarmDiagnostics.record(this@LocalAlarmAudioService, currentRecord, "COMPLETED"); stopSelf() }
                    }
                    override fun onPlayerError(error: androidx.media3.common.PlaybackException) { fail("PLAYBACK_${error.errorCodeName}") }
                })
                setMediaItem(MediaItem.fromUri(uri)); prepare(); play()
            }
            handler.postDelayed({ stopSelf() }, 15 * 60 * 1000L)
        } catch (error: Exception) { fail("ALARM_${error.javaClass.simpleName}") }
        return START_NOT_STICKY
    }
    private fun audioUri(path: String, channel: String): Uri {
        if (path.isNotEmpty() && !path.startsWith("assets/")) {
            val file = File(if (path.startsWith("file://")) Uri.parse(path).path ?: "" else path)
            require(file.isFile && file.canonicalPath.startsWith(filesDir.canonicalPath + "/")) { "LOCAL_AUDIO_MISSING" }
            return Uri.fromFile(file)
        }
        // Flutter assets are packaged locally; only our audited catalog is accepted.
        if (path in setOf("assets/audio/reminder.wav", "assets/audio/adhan.ogg",
                "assets/audio/adhan_makkah.ogg", "assets/audio/adhan_madinah.ogg",
                "assets/audio/adhan_kazakhstan.ogg", "assets/audio/adhan_sweden_fajr.ogg",
                "assets/audio/user_makkah.mp3", "assets/audio/user_madinah.mp3", "assets/audio/user_egypt.mp3", "assets/audio/user_abdul_basit.mp3", "assets/audio/user_minshawi.mp3")) {
            return Uri.parse("asset:///flutter_assets/$path")
        }
        if (channel != "adhan" && path.isEmpty()) {
            return Uri.parse("asset:///flutter_assets/assets/audio/reminder.wav")
        }
        return Uri.parse("android.resource://$packageName/${R.raw.adhan}")
    }
    private fun fail(code: String) {
        AlarmDiagnostics.record(this, currentRecord, code)
        getSharedPreferences("alarm_diagnostics", MODE_PRIVATE).edit().putString("lastFailure", code).apply()
        currentRecord?.let { record ->
            try {
                val notification = OfflineNotifications.build(this, OfflineNotifications.ALARM_FALLBACK_CHANNEL,
                    record.optString("title", "ترتيل"), record.optString("body") + " — تعذر تشغيل الصوت؛ راجع حالة التنبيهات",
                    ongoing = false, payload = record.optString("payload"))
                getSystemService(android.app.NotificationManager::class.java).notify(record.optInt("id", 8103), notification)
            } catch (_: SecurityException) { /* The user can inspect the recorded failure after granting permission. */ }
        }
        stopSelf()
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null); player?.release(); player = null
        i…13122 tokens truncated…             context: context,
                              initialTime: TimeOfDay(
                                hour: minutes ~/ 60,
                                minute: minutes % 60,
                              ),
                            );
                            if (chosen != null) {
                              await store.setManualTime(
                                prayer,
                                chosen.hour * 60 + chosen.minute,
                              );
                            }
                          },
                        ),
                      DropdownButtonFormField<PrayerReminderMode>(
                        isExpanded: true,
                        key: ValueKey<String>('prayer-mode-${prayer.name}'),
                        initialValue: settings.reminderModeFor(prayer),
                        decoration: const InputDecoration(
                          labelText: 'نوع التذكير',
                        ),
                        items: <DropdownMenuItem<PrayerReminderMode>>[
                          for (final mode in PrayerReminderMode.values)
                            DropdownMenuItem<PrayerReminderMode>(
                              value: mode,
                              child: Text(
                                mode.nameAr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _changingPrayer == null
                            ? (mode) {
                                if (mode != null) _setMode(prayer, mode);
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      if (settings.reminderModeFor(prayer) ==
                              PrayerReminderMode.adhan ||
                          settings.reminderModeFor(prayer) ==
                              PrayerReminderMode.shortAlert) ...[
                        _prayerSoundPicker(context, prayer, settings),
                        Text(
                          'مستوى الصوت: ${(settings.volumeFor(prayer) * 100).round()}٪',
                        ),
                        _PrayerVolumeSlider(
                          value: settings.volumeFor(prayer),
                          onSaved: (value) =>
                              store.setPrayerVolume(prayer, value),
                        ),
                        const Text(
                          'يُطبّق على صوت ترتيل دون تغيير صوت النظام أو تجاوز وضع عدم الإزعاج.',
                        ),
                      ],
                      for (final before in [true, false])
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          key: ValueKey(
                            'prayer-${before ? 'before' : 'after'}-${prayer.name}-${before ? settings.beforeMinutesFor(prayer) : settings.afterMinutesFor(prayer)}',
                          ),
                          initialValue: before
                              ? settings.beforeMinutesFor(prayer)
                              : settings.afterMinutesFor(prayer),
                          decoration: InputDecoration(
                            labelText: before
                                ? 'تذكير قبل الصلاة'
                                : 'تذكير وأذكار بعد الصلاة',
                          ),
                          items: [
                            for (var minutes = 0; minutes <= 120; minutes++)
                              DropdownMenuItem(
                                value: minutes,
                                child: Text(
                                  minutes == 0 ? 'متوقف' : '$minutes دقيقة',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              store.setReminderMinutes(
                                prayer,
                                before: before ? value : null,
                                after: before ? null : value,
                              );
                          },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey<String>('prayer-offset-${prayer.name}'),
                        initialValue: settings.offsetFor(prayer),
                        decoration: const InputDecoration(
                          labelText: 'تعديل الوقت',
                        ),
                        items: <DropdownMenuItem<int>>[
                          for (final value in _offsetValues(
                            settings.offsetFor(prayer),
                          ))
                            DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                _offsetLabel(value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: settings.manualTimes.containsKey(prayer)
                            ? null
                            : (value) {
                                if (value != null)
                                  store.setOffset(prayer, value);
                              },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerCity {
  const _PrayerCity(this.name, this.latitude, this.longitude, this.timezone);
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;
}

const _prayerCities = <_PrayerCity>[
  _PrayerCity('تعز', 13.5795, 44.0209, 'Asia/Aden'),
  _PrayerCity('صنعاء', 15.3694, 44.1910, 'Asia/Aden'),
  _PrayerCity('عدن', 12.7855, 45.0187, 'Asia/Aden'),
  _PrayerCity('إب', 13.9667, 44.1833, 'Asia/Aden'),
  _PrayerCity('الحديدة', 14.7978, 42.9545, 'Asia/Aden'),
  _PrayerCity('المكلا', 14.5425, 49.1242, 'Asia/Aden'),
  _PrayerCity('سيئون', 15.9433, 48.7873, 'Asia/Aden'),
  _PrayerCity('مأرب', 15.4625, 45.3258, 'Asia/Aden'),
  _PrayerCity('مكة المكرمة', 21.4225, 39.8262, 'Asia/Riyadh'),
  _PrayerCity('القاهرة', 30.0444, 31.2357, 'Africa/Cairo'),
  _PrayerCity('لندن', 51.5074, -0.1278, 'Europe/London'),
  _PrayerCity('نيويورك', 40.7128, -74.006, 'America/New_York'),
];

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _remaining(Duration value) {
  final safe = value.isNegative ? Duration.zero : value;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  return hours > 0 ? '$hours ساعة و$minutes دقيقة' : '$minutes دقيقة';
}

String _methodName(PrayerCalculationMethod value) => switch (value) {
  PrayerCalculationMethod.muslimWorldLeague => 'رابطة العالم الإسلامي',
  PrayerCalculationMethod.egyptian => 'الهيئة المصرية',
  PrayerCalculationMethod.ummAlQura => 'أم القرى',
  PrayerCalculationMethod.karachi => 'جامعة العلوم الإسلامية — كراتشي',
  PrayerCalculationMethod.northAmerica => 'الجمعية الإسلامية لأمريكا الشمالية',
};

String _asrName(PrayerAsrMethod value) => switch (value) {
  PrayerAsrMethod.shafi => 'العصر: شافعي',
  PrayerAsrMethod.hanafi => 'العصر: حنفي',
};

String _offsetLabel(int value) => value == 0
    ? 'بدون تعديل'
    : value > 0
    ? '+$value دقيقة'
    : '$value دقيقة';

List<int> _offsetValues(int current) {
  final values = <int>{current};
  for (var value = -60; value <= 60; value++) {
    values.add(value);
  }
  final sorted = values.toList()..sort();
  return sorted;
}

String? _coordinateError(String? text, double limit) {
  final value = double.tryParse(text?.trim() ?? '');
  return value == null || !value.isFinite || value < -limit || value > limit
      ? 'أدخل قيمة بين ${-limit} و$limit'
      : null;
}

PrayerKind? _currentPrayer(PrayerDay day, DateTime now) {
  PrayerKind? current;
  for (final item in day.requiredPrayers) {
    if (!item.time.isAfter(now)) current = item.prayer;
  }
  return current;
}

/// Civil tabular Hijri date, explicitly labelled approximate; moon-sighting
/// calendars may differ by one or two days.
String _hijriDate(DateTime date) {
  final hijri = civilHijriForDate(date);
  const names = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
  return '${hijri.day} ${names[hijri.month - 1]} ${hijri.year} هـ — هجري حسابي؛ قد يختلف عن الرؤية';
}

class PrayerCalendarPage extends ConsumerStatefulWidget {
  const PrayerCalendarPage({super.key});
  @override
  ConsumerState<PrayerCalendarPage> createState() => _PrayerCalendarPageState();
}

class _PrayerCalendarPageState extends ConsumerState<PrayerCalendarPage> {
  int _days = 7;
  late Future<List<PrayerDay>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final services = ref.read(servicesProvider);
    _future = services.prayerTimes
        .snapshot(settings: services.prayerSettings.value)
        .then(
          (snapshot) => services.prayerTimes.calendar(
            from: snapshot.today.date,
            days: _days,
            settings: services.prayerSettings.value,
          ),
        );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جدول مواقيت الصلاة')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('أسبوعي')),
              ButtonSegment(value: 30, label: Text('شهري — ٣٠ يومًا')),
            ],
            selected: {_days},
            onSelectionChanged: (selection) => setState(() {
              _days = selection.first;
              _reload();
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'المواقيت حسب الموقع والمنطقة الزمنية المحفوظين، وتُحسب على جهازك دون إنترنت. اسحب الجدول أفقيًا لعرض جميع الصلوات.',
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PrayerDay>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return ErrorPane(
                  error: snapshot.error!,
                  onRetry: () => setState(_reload),
                );
              if (!snapshot.hasData) return const LoadingPane();
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('التاريخ')),
                      for (final prayer in PrayerKind.values)
                        DataColumn(label: Text(prayer.nameAr)),
                    ],
                    rows: [
                      for (final day in snapshot.data!)
                        DataRow(
                          cells: [
                            DataCell(Text(_civilDate(day.date, compact: true))),
                            for (final prayer in PrayerKind.values)
                              DataCell(
                                Text(
                                  _time(day.timeFor(prayer)),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class PrayerAlarmStatusPage extends ConsumerStatefulWidget {
  const PrayerAlarmStatusPage({super.key});
  @override
  ConsumerState<PrayerAlarmStatusPage> createState() =>
      _PrayerAlarmStatusPageState();
}

class _PrayerAlarmStatusPageState extends ConsumerState<PrayerAlarmStatusPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() => _future = ref
      .read(servicesProvider)
      .localNotifications
      .alarmDiagnostics();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _testAlarm() async {
    final services = ref.read(servicesProvider);
    if (!await services.localNotifications.requestPermission()) return;
    await services.localNotifications.schedule(
      LocalNotificationRequest(
        id: 8_999_001,
        title: 'ترتيل — اختبار التنبيه',
        body:
            'إذا سمعت هذا الصوت فالتنبيه المحلي يعمل حاليًا. اختبره أيضًا مع إغلاق الشاشة.',
        scheduledAt: DateTime.now().add(const Duration(minutes: 1)),
        timezone: services.prayerSettings.value.timezone,
        payload: '/prayer-times',
        audioPath:
            services.adhanLibrary.selectedPath ?? 'assets/audio/adhan.ogg',
        channel: LocalNotificationChannel.adhan,
      ),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت جدولة اختبار بعد دقيقة. أغلق الشاشة للتحقق من تشغيله في الخلفية.',
          ),
        ),
      );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.read(servicesProvider).localNotifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة التنبيهات والصلاحيات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          if (!snapshot.hasData) return const LoadingPane();
          final status = snapshot.data!;
          Widget row(
            String title,
            bool active,
            String explanation,
            VoidCallback action,
          ) => ListTile(
            leading: Icon(
              active ? Icons.check_circle_outline : Icons.warning_amber,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(title),
            subtitle: Text(
              '${active ? 'مفعّل' : 'يحتاج إلى مراجعة'} • $explanation',
            ),
            onTap: action,
            trailing: const Icon(Icons.open_in_new),
          );
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PrayerReliabilityDetails(status: status),
              row(
                'إذن الإشعارات',
                status['notifications'] == true,
                'يُسمح بإظهار تنبيهات الصلاة.',
                () => notifications.openSystemSettings(),
              ),
              row(
                'المنبهات والتذكيرات الدقيقة',
                status['exactAlarms'] == true,
                'دون هذا الإذن قد يتأخر التنبيه.',
                () => notifications.openAlarmSettings(),
              ),
              row(
                'قناة الأذان',
                status['alarmChannelEnabled'] == true,
                'تحقق أن قناة الأذان مفعّلة في Android.',
                () => notifications.openSystemSettings(),
              ),
              row(
                'التشغيل في الخلفية',
                status['batteryUnrestricted'] == true,
                'سياسة البطارية قد توقف الأذان على بعض الأجهزة.',
                () => notifications.openBatterySettings(),
              ),
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('صوت منبهات النظام'),
                subtitle: Text(
                  '${status['alarmVolume'] ?? '—'} / ${status['alarmVolumeMax'] ?? '—'} • راجع مستوى الصوت وعدم الإزعاج من إعدادات الهاتف.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('التنبيهات المحلية المجدولة'),
                subtitle: Text(
                  '${status['scheduledCount'] ?? 0} تنبيه. تجدد المواقيت عند فتح التطبيق؛ عند إضافة تذكيرات قبل/بعد الصلاة تكفي النافذة ٢٨ يومًا، وإلا ٤٥ يومًا.',
                ),
              ),
              if (status['lastReadyAt'] is num &&
                  (status['lastReadyAt'] as num) > 0)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('آخر تجهيز للصوت في Android'),
                  subtitle: Text(
                    '${DateTime.fromMillisecondsSinceEpoch((status['lastReadyAt'] as num).toInt()).toLocal()}\nتجهيز الملف لا يؤكد سماعه؛ راجع مستوى الصوت وجرّب مع إغلاق الشاشة.',
                  ),
                ),
              if (status['lastFailure'] is String &&
                  (status['lastFailure'] as String).isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('آخر مشكلة مسجلة'),
                  subtitle: Text(status['lastFailure'] as String),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'لا يمكن ضمان التنبيه إذا أوقفت التطبيق إجباريًا أو منع نظام الهاتف العمل في الخلفية. بعد إعادة التشغيل أو تحديث التطبيق تُستعاد التنبيهات المحفوظة. بعد تغيير الموقع أو إعدادات التوقيت افتح ترتيل لتحديث حساب المواقيت.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: _testAlarm,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('اختبار الأذان بعد دقيقة'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _civilDate(DateTime date, {bool compact = false}) {
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  final label = '${weekdays[date.weekday - 1]} ${date.day}/${date.month}';
  return compact ? label : '$label/${date.year}';
}

class _PrayerVolumeSlider extends StatefulWidget {
  const _PrayerVolumeSlider({required this.value, required this.onSaved});
  final double value;
  final ValueChanged<double> onSaved;
  @override
  State<_PrayerVolumeSlider> createState() => _PrayerVolumeSliderState();
}

class _PrayerVolumeSliderState extends State<_PrayerVolumeSlider> {
  late double _volume = widget.value;
  @override
  void didUpdateWidget(covariant _PrayerVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _volume = widget.value;
  }

  @override
  Widget build(BuildContext context) => Slider(
    value: _volume,
    divisions: 10,
    label: '${(_volume * 100).round()}٪',
    onChanged: (value) => setState(() => _volume = value),
    onChangeEnd: widget.onSaved,
  );
}

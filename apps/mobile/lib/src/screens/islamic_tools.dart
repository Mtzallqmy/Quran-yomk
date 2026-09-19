import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_core/hijri_core.dart' as hijri_core;

import '../prayer_settings.dart';
import '../services.dart';

class IslamicToolsPage extends ConsumerWidget {
  const IslamicToolsPage({super.key});

  static const _settingsChannel = MethodChannel('app.tarteel.tarteel/settings');

  Future<void> _useCurrentLocation(BuildContext context, WidgetRef ref) async {
    final services = ref.read(servicesProvider);
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فعّل خدمة الموقع في الهاتف أولًا.')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('إذن الموقع مرفوض نهائيًا من Android.'),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      }
      return;
    }
    if (permission == LocationPermission.denied) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      String timezone = services.prayerSettings.value.timezone;
      try {
        timezone =
            await _settingsChannel.invokeMethod<String>('getSystemTimezone') ??
                timezone;
      } on PlatformException {
        // Keep the saved timezone if the native lookup is unavailable.
      }
      final current = services.prayerSettings.value;
      final method = timezone == 'Asia/Riyadh'
          ? PrayerCalculationMethod.ummAlQura
          : current.calculationMethod;
      await services.prayerSettings.updateLocation(
        current.copyWith(
          locationName: 'موقعي الحالي',
          latitude: position.latitude,
          longitude: position.longitude,
          timezone: timezone,
          calculationMethod: method,
        ),
      );
      await services.prayerReminders.reconcile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث موقع الصلاة والقبلة وإعادة جدولة المنبهات.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحصول على موقع دقيق من الجهاز.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = services.prayerSettings.value;
    return Scaffold(
      appBar: AppBar(title: const Text('أدوات إسلامية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.my_location_outlined),
              title: const Text('استخدام موقعي الحالي'),
              subtitle: const Text(
                'يستخدم GPS عند اختيارك فقط ثم يحفظ الإحداثيات للعمل دون إنترنت.',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _useCurrentLocation(context, ref),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('اتجاه القبلة بالبوصلة'),
              subtitle: Text(
                '${settings.locationName} • اتجاه حي من حساس الهاتف',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QiblaPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('التقويم الهجري'),
              subtitle: const Text('أم القرى مدمج محليًا ويعمل دون اتصال'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HijriCalendarPage(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QiblaPage extends ConsumerWidget {
  const QiblaPage({super.key});

  double _normalized(double value) {
    var result = value % 360;
    if (result < 0) result += 360;
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = services.prayerSettings.value;
    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: FutureBuilder<double>(
        future: services.prayerTimes.qiblaDirection(settings),
        builder: (context, qiblaSnapshot) {
          if (!qiblaSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final qiblaBearing = qiblaSnapshot.data!;
          return StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, compassSnapshot) {
              final heading = compassSnapshot.data?.heading;
              final sensorReady = heading != null;
              final relative = sensorReady
                  ? _normalized(qiblaBearing - heading)
                  : qiblaBearing;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  const SizedBox(height: 18),
                  Center(
                    child: SizedBox.square(
                      dimension: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                                width: 3,
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                          Positioned(
                            top: 14,
                            child: Text(
                              'N',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (sensorReady)
                            Transform.rotate(
                              angle: relative * math.pi / 180,
                              child: Icon(
                                Icons.navigation,
                                size: 130,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          else
                            Icon(
                              Icons.sensors_off_outlined,
                              size: 92,
                              color: Theme.of(context).colorScheme.error,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (sensorReady) ...<Widget>[
                    Text(
                      'حرّك الهاتف حتى يشير السهم إلى أعلى الشاشة',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اتجاه القبلة ${qiblaBearing.toStringAsFixed(1)}° • اتجاه الهاتف ${heading.toStringAsFixed(1)}°',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إذا لاحظت انحرافًا، حرّك الهاتف على شكل رقم 8 لمعايرة البوصلة ثم أبعده عن المعادن والمغناطيس.',
                      textAlign: TextAlign.center,
                    ),
                  ] else ...<Widget>[
                    Text(
                      'هذا الجهاز لا يوفّر قراءة بوصلة صالحة حاليًا',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اتجاه القبلة المحسوب من الشمال: ${qiblaBearing.toStringAsFixed(1)}°',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'لن يعرض ترتيل سهمًا متحركًا وهميًا عندما لا يوجد حساس بوصلة. يمكنك استخدام اتجاه الشمال من نظام الهاتف ثم تطبيق الزاوية أعلاه.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(settings.locationName),
                      subtitle: Text(
                        '${settings.latitude.toStringAsFixed(5)}, ${settings.longitude.toStringAsFixed(5)}',
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class HijriCalendarPage extends StatefulWidget {
  const HijriCalendarPage({super.key});

  @override
  State<HijriCalendarPage> createState() => _HijriCalendarPageState();
}

class _HijriCalendarPageState extends State<HijriCalendarPage> {
  int _adjustment = 0;

  static const _months = <String>[
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final civilUtc = DateTime.utc(today.year, today.month, today.day);
    final adjusted = civilUtc.add(Duration(days: _adjustment));
    final hijri = hijri_core.toHijri(adjusted);
    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الهجري')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  if (hijri != null)
                    Text(
                      '${hijri.hd} ${_months[(hijri.hm - 1).clamp(0, 11).toInt()]} ${hijri.hy} هـ',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    )
                  else
                    const Text('التاريخ خارج نطاق بيانات أم القرى المدمجة'),
                  const SizedBox(height: 8),
                  Text(
                    '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('المصدر: أم القرى'),
              subtitle: Text(
                'التحويل يستخدم جدول أم القرى المدمج في التطبيق ويعمل بالكامل دون إنترنت.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'قد يعلن بلدك بداية الشهر وفق الرؤية الشرعية بشكل مختلف بيوم. يمكنك تعديل العرض محليًا دون تغيير مواقيت الصلاة.',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlinedButton(
                onPressed: _adjustment > -2
                    ? () => setState(() => _adjustment--)
                    : null,
                child: const Text('- يوم'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('التعديل: $_adjustment'),
              ),
              OutlinedButton(
                onPressed: _adjustment < 2
                    ? () => setState(() => _adjustment++)
                    : null,
                child: const Text('+ يوم'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

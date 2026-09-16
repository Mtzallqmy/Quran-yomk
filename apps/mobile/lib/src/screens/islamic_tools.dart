import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services.dart';

class IslamicToolsPage extends ConsumerWidget {
  const IslamicToolsPage({super.key});

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
              leading: const Icon(Icons.explore_outlined),
              title: const Text('اتجاه القبلة'),
              subtitle: Text('${settings.locationName} • يعمل دون إنترنت'),
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
              subtitle: const Text('تحويل حسابي محلي دون اتصال'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = services.prayerSettings.value;
    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: FutureBuilder<double>(
        future: services.prayerTimes.qiblaDirection(settings),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final direction = snapshot.data!;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox.square(
                    dimension: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              width: 3,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                        const Positioned(top: 12, child: Text('N')),
                        Transform.rotate(
                          angle: direction * math.pi / 180,
                          child: Icon(
                            Icons.navigation,
                            size: 120,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${direction.toStringAsFixed(1)}° من الشمال الحقيقي',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${settings.locationName} • ${settings.latitude.toStringAsFixed(4)}, ${settings.longitude.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'وجّه أعلى الهاتف نحو الشمال الحقيقي ثم اتبع السهم. حساب الاتجاه يتم محليًا عبر Adhan ولا يحتاج إلى الإنترنت.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    final gregorian = DateTime.now().add(Duration(days: _adjustment));
    final hijri = HijriDate.fromGregorian(gregorian);
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
                  Text(
                    '${hijri.day} ${hijri.monthNameAr} ${hijri.year} هـ',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${gregorian.year}-${gregorian.month.toString().padLeft(2, '0')}-${gregorian.day.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'هذا تحويل هجري حسابي محلي. قد تختلف بداية الشهر يومًا بحسب الرؤية الشرعية أو التقويم الرسمي في بلدك.',
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

class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

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

  String get monthNameAr => _months[(month - 1).clamp(0, 11).toInt()];

  factory HijriDate.fromGregorian(DateTime date) {
    final jd = _gregorianToJulian(date.year, date.month, date.day);
    final z = (jd + 0.5).floor();
    final year = ((30 * (z - 1948439) + 10646) / 10631).floor();
    final firstDay = _islamicToJulian(year, 1, 1).floor();
    var month = (((z - 29 - firstDay) / 29.5).ceil() + 1)
        .clamp(1, 12)
        .toInt();
    final monthStart = _islamicToJulian(year, month, 1).floor();
    var day = z - monthStart + 1;
    if (day < 1) {
      month = (month - 1).clamp(1, 12).toInt();
      day = z - _islamicToJulian(year, month, 1).floor() + 1;
    }
    return HijriDate(year, month, day.clamp(1, 30).toInt());
  }

  static double _gregorianToJulian(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static double _islamicToJulian(int year, int month, int day) =>
      day +
      (29.5 * (month - 1)).ceil() +
      (year - 1) * 354 +
      ((3 + 11 * year) / 30).floor() +
      1948439.5 -
      1;
}

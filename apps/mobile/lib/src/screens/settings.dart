import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'content_sources.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = services.settings;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          children: <Widget>[
            const SectionHeader('المظهر'),
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) settings.setThemeMode(value);
              },
              child: const Column(
                children: <Widget>[
                  RadioListTile(
                    value: ThemeMode.system,
                    title: Text('حسب النظام'),
                  ),
                  RadioListTile(value: ThemeMode.light, title: Text('فاتح')),
                  RadioListTile(value: ThemeMode.dark, title: Text('داكن')),
                ],
              ),
            ),
            const SectionHeader('اللغة'),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('اللغة'),
              trailing: DropdownButton<String>(
                value: settings.locale.languageCode,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) settings.setLocale(Locale(value));
                },
              ),
            ),
            const SectionHeader('التشغيل'),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('سرعة التلاوة الافتراضية'),
              subtitle: const Text(
                'تُطبق على التلاوات عند الطلب فقط، ولا تُطبق على البث المباشر.',
              ),
              trailing: DropdownButton<double>(
                value: settings.playbackSpeed,
                items: const <DropdownMenuItem<double>>[
                  DropdownMenuItem(value: 0.75, child: Text('0.75×')),
                  DropdownMenuItem(value: 1.0, child: Text('1×')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25×')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5×')),
                  DropdownMenuItem(value: 2.0, child: Text('2×')),
                ],
                onChanged: (value) {
                  if (value != null) settings.setPlaybackSpeed(value);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('إلغاء مؤقت النوم'),
              onTap: services.playback.cancelSleepTimer,
            ),
            const SectionHeader('حول التطبيق'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('ترتيل — Tarteel'),
              subtitle: Text(
                'الإصدار 0.1.0 (1)\nالمطور: معتز العلقمي\nتعز، اليمن',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copyright_outlined),
              title: const Text('مصادر المحتوى وحقوق النشر'),
              subtitle: const Text(
                'المصادر، attribution، الشروط وحالة الحقوق',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ContentSourcesPage(),
                ),
              ),
            ),
            FutureBuilder<JsonMap>(
              future: services.repository.appConfig(),
              builder: (context, snapshot) {
                final config = snapshot.data ?? const <String, dynamic>{};
                return Column(
                  children: <Widget>[
                    _LegalTile(
                      title: 'سياسة الخصوصية',
                      value: config['privacy_url'],
                    ),
                    _LegalTile(title: 'الشروط', value: config['terms_url']),
                    _LegalTile(title: 'الدعم', value: config['support_url']),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final url = value is String && (value as String).isNotEmpty
        ? value as String
        : null;
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title),
      subtitle: Text(url ?? 'غير متوفر حاليًا'),
      enabled: false,
    );
  }
}

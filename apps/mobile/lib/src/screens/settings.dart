import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../feature_manager.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../quran_download_contract.dart';
import 'content_sources.dart';
import '../services.dart';
import 'about.dart';
import 'notification_settings.dart';
import 'prayer_times.dart';
import 'saved_clips.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = services.settings;
    final l10n = context.l10n;
    final english = settings.locale.languageCode == 'en';
    return AnimatedBuilder(
      animation: Listenable.merge([
        settings,
        services.features,
        services.quranDownloads,
      ]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.settings)),
        body: ListView(
          children: <Widget>[
            SectionHeader(l10n.appearance),
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) settings.setThemeMode(value);
              },
              child: Column(
                children: <Widget>[
                  RadioListTile(
                    value: ThemeMode.system,
                    title: Text(l10n.followSystem),
                  ),
                  RadioListTile(
                    value: ThemeMode.light,
                    title: Text(l10n.light),
                  ),
                  RadioListTile(value: ThemeMode.dark, title: Text(l10n.dark)),
                ],
              ),
            ),
            SectionHeader(l10n.language),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              trailing: DropdownButton<String>(
                value: settings.locale.languageCode,
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'ar', child: Text(l10n.arabic)),
                  DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                ],
                onChanged: (value) {
                  if (value != null) settings.setLocale(Locale(value));
                },
              ),
            ),
            SectionHeader(l10n.playback),
            ListTile(
              leading: const Icon(Icons.speed),
              title: Text(l10n.defaultRecitationSpeed),
              subtitle: Text(l10n.defaultRecitationSpeedHelp),
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
              title: Text(l10n.cancelSleepTimer),
              onTap: services.playback.cancelSleepTimer,
            ),
            if (services.features.enabled(TarteelFeature.offlineDownloads)) ...[
              SectionHeader(english ? 'Downloads' : 'التنزيلات'),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(
                  english
                      ? 'Downloads and storage'
                      : 'التنزيلات ومساحة التخزين',
                ),
                subtitle: Text(
                  english
                      ? 'Manage downloaded recitations and offline listening'
                      : 'إدارة التلاوات المحملة والاستماع دون اتصال',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () =>
                    Navigator.pushNamed(context, MobileRoutes.downloads),
              ),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(
                  english
                      ? 'Downloaded audio storage'
                      : 'مساحة التلاوات المحملة',
                ),
                subtitle: Text(
                  '${(services.quranDownloads.tasks.where((task) => task.state == QuranDownloadState.completed).fold<int>(0, (sum, task) => sum + (task.totalBytes ?? task.downloadedBytes)) / (1024 * 1024)).toStringAsFixed(1)} MB',
                ),
              ),
            ],
            SectionHeader(english ? 'Notifications' : 'الإشعارات'),
            ListTile(leading: const Icon(Icons.alarm_add), title: const Text('المنبه الشخصي بصوت من الهاتف'),
              subtitle: const Text('أوقات تختارها وصوت محلي دون إنترنت'),
              onTap: () => Navigator.pushNamed(context, MobileRoutes.personalAlarms)),
            if (services.features.enabled(TarteelFeature.prayer)) ...<Widget>[
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('مواقيت الصلاة'),
                subtitle: Text(
                  '${services.prayerSettings.value.locationName} • حساب محلي وتنبيهات دون إنترنت',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrayerTimesPage(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('إعدادات تنبيهات الصلاة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrayerSettingsPage(),
                  ),
                ),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: const Text('إشعارات ترتيل'),
              subtitle: const Text('تفضيلات الإشعارات عن بُعد'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PushNotificationSettingsPage(),
                ),
              ),
            ),
            SectionHeader(english ? 'Saved recordings' : 'التسجيلات المحفوظة'),
            ListTile(
              leading: const Icon(Icons.offline_pin_outlined),
              title: Text(l10n.savedClips),
              subtitle: Text(l10n.savedClipsSubtitle),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SavedClipsPage()),
              ),
            ),
            SectionHeader(english ? 'Privacy' : 'الخصوصية'),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(
                english
                    ? 'Notification privacy and consent'
                    : 'خصوصية الإشعارات والموافقة',
              ),
              onTap: () => showNotificationPrivacyDetails(context),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(
                english ? 'Notification permissions' : 'صلاحيات الإشعارات',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PushNotificationSettingsPage(),
                ),
              ),
            ),
            SectionHeader(english ? 'Sources' : 'المصادر'),
            ListTile(
              leading: const Icon(Icons.source_outlined),
              title: Text(l10n.thirdPartyRights),
              subtitle: Text(l10n.contentSourcesSubtitle),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ContentSourcesPage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(
                english ? 'Open source licenses' : 'تراخيص البرمجيات',
              ),
              onTap: () => showLicensePage(
                context: context,
                applicationName: english ? 'Tarteel' : 'ترتيل',
              ),
            ),
            SectionHeader(l10n.aboutSection),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.aboutTarteel),
              subtitle: Text(l10n.aboutSubtitle),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

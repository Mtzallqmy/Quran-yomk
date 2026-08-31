import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../l10n.dart';
import '../services.dart';
import 'about.dart';
import 'saved_clips.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = services.settings;
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: settings,
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
            ListTile(
              leading: const Icon(Icons.offline_pin_outlined),
              title: Text(l10n.savedClips),
              subtitle: Text(l10n.savedClipsSubtitle),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SavedClipsPage()),
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

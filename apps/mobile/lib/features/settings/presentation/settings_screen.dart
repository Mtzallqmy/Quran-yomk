import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/brand_config.dart';
import '../../../core/config/features_manager.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../playlists/presentation/playlists_screen.dart';
import '../../offline/presentation/downloads_screen.dart';
import '../../learning/presentation/learning_screen.dart';
import 'about_and_sources_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsConsent = true;
  bool _prayerAlerts = true;

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresManagerProvider);
    final featuresNotifier = ref.read(featuresManagerProvider.notifier);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: const [
                QuranYutlaBrandMark(size: 64),
                SizedBox(height: 12),
                Text(
                  BrandConfig.nameAr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF243B6B)),
                ),
                SizedBox(height: 4),
                Text(
                  'الإصدار 1.0.0 (النسخة المستقلة)',
                  style: TextStyle(color: Color(0xFF5B677A), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tools and Features
          const Text('المميزات والإدارة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E9E9E))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.playlist_play, color: Color(0xFF2E9E9E)),
            title: const Text('قوائم التشغيل القرآنية'),
            subtitle: const Text('إنشاء وإدارة ورد الاستماع وقوائم السور'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const PlaylistsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF2E9E9E)),
            title: const Text('التنزيلات والاستماع دون اتصال'),
            subtitle: const Text('الملفات الصوتية المحملة وفحص التحقق SHA-256'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const DownloadsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined, color: Color(0xFF2E9E9E)),
            title: const Text('مركز الحفظ والأذكار'),
            subtitle: const Text('خطط الحفظ والمراجعة والأذكار اليومية'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const LearningScreen()),
              );
            },
          ),
          const Divider(),

          // Remote Config Feature Flags
          const Text('التحكم في الميزات (Feature Flags)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E9E9E))),
          SwitchListTile(
            title: const Text('إذاعة القرآن المدارة (Radio Feature)'),
            subtitle: const Text('التحكم في ظهور تبويب الإذاعة بالكامل'),
            value: features.radioEnabled,
            activeColor: const Color(0xFF2E9E9E),
            onChanged: (val) {
              featuresNotifier.toggleRadio(val);
            },
          ),
          const Divider(),

          // Notifications & Privacy
          const Text('الإشعارات والخصوصية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E9E9E))),
          SwitchListTile(
            title: const Text('تنبيهات مواقيت الصلاة'),
            subtitle: const Text('تنبيهات محلية بدون مشاركة الموقع'),
            value: _prayerAlerts,
            activeColor: const Color(0xFF2E9E9E),
            onChanged: (val) => setState(() => _prayerAlerts = val),
          ),
          SwitchListTile(
            title: const Text('الموافقة على الإشعارات العامة'),
            subtitle: const Text('موافقة صريحة قبل التسجيل في خدمة الإشعارات'),
            value: _notificationsConsent,
            activeColor: const Color(0xFF2E9E9E),
            onChanged: (val) => setState(() => _notificationsConsent = val),
          ),
          const Divider(),

          // About & Sources
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF2E9E9E)),
            title: const Text('المصادر وعن التطبيق'),
            subtitle: const Text('المصادر المعتمدة، معايير الصوت، وحقوق المصحف'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AboutAndSourcesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

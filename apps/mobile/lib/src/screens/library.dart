import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feature_manager.dart';
import '../navigation.dart';
import '../services.dart';
import 'islamic_library.dart';
import 'learning.dart';
import 'saved_clips.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(servicesProvider).features;
    return AnimatedBuilder(
      animation: features,
      builder: (_, _) => ListView(
        key: const PageStorageKey('my-library'),
        padding: const EdgeInsets.all(16),
        children: [
          _entry(
            context,
            'المفضلة',
            Icons.favorite_border,
            MobileRoutes.favorites,
          ),
          if (features.enabled(TarteelFeature.offlineDownloads))
            _entry(
              context,
              'التنزيلات',
              Icons.download_outlined,
              MobileRoutes.downloads,
            ),
          _entry(
            context,
            'قوائم التشغيل',
            Icons.queue_music,
            MobileRoutes.playlists,
          ),
          _entry(
            context,
            'العلامات المرجعية',
            Icons.bookmark_border,
            MobileRoutes.quran,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mic_none),
            title: const Text('التسجيلات المحفوظة'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SavedClipsPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('الحفظ والمراجعة'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LearningCenterPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_library_outlined),
            title: const Text('المكتبة الإسلامية'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const IslamicLibraryPage(),
              ),
            ),
          ),
          _entry(
            context,
            'الإعدادات',
            Icons.settings_outlined,
            MobileRoutes.settings,
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => Navigator.pushNamed(context, route),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/features_manager.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../quran/presentation/quran_home_screen.dart';
import '../../radio/presentation/radio_screen.dart';
import '../../recitations/presentation/recitations_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../playlists/presentation/playlists_screen.dart';
import '../../offline/presentation/downloads_screen.dart';
import '../../learning/presentation/learning_screen.dart';
import '../../settings/presentation/about_and_sources_screen.dart';
import 'mini_audio_player_bar.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresManagerProvider);

    // Dynamic destinations based on Feature Flag (Radio)
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'الرئيسية',
      ),
      if (features.radioEnabled)
        const NavigationDestination(
          icon: Icon(Icons.radio_outlined),
          selectedIcon: Icon(Icons.radio),
          label: 'الإذاعة',
        ),
      const NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: 'المصحف',
      ),
      const NavigationDestination(
        icon: Icon(Icons.record_voice_over_outlined),
        selectedIcon: Icon(Icons.record_voice_over),
        label: 'القراء',
      ),
      const NavigationDestination(
        icon: Icon(Icons.star_outline),
        selectedIcon: Icon(Icons.star),
        label: 'المفضلة',
      ),
    ];

    // Build the screens list matching the dynamic destinations
    final screens = <Widget>[
      const QuranHomeScreen(), // 1. Home
      if (features.radioEnabled) const RadioScreen(), // 2. Radio (if enabled)
      const QuranHomeScreen(), // 3. Mushaf / Quran
      const RecitationsScreen(), // 4. Reciters
      const FavoritesScreen(), // 5. Favorites
    ];

    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: QuranYutlaBrandMark(size: 32, isRadio: true),
        ),
        title: const Text(
          'قرآن يتلى',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SearchScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              switch (val) {
                case 'playlists':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const PlaylistsScreen()),
                  );
                  break;
                case 'downloads':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const DownloadsScreen()),
                  );
                  break;
                case 'learning':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const LearningScreen()),
                  );
                  break;
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                  );
                  break;
                case 'about':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const AboutAndSourcesScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'playlists',
                child: Row(
                  children: [
                    Icon(Icons.playlist_play, color: Color(0xFF2E9E9E), size: 20),
                    SizedBox(width: 8),
                    Text('قوائم التشغيل'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'downloads',
                child: Row(
                  children: [
                    Icon(Icons.download_done, color: Color(0xFF2E9E9E), size: 20),
                    SizedBox(width: 8),
                    Text('التنزيلات دون اتصال'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'learning',
                child: Row(
                  children: [
                    Icon(Icons.school, color: Color(0xFF2E9E9E), size: 20),
                    SizedBox(width: 8),
                    Text('مركز الحفظ والأذكار'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Color(0xFF2E9E9E), size: 20),
                    SizedBox(width: 8),
                    Text('الإعدادات العامة'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF2E9E9E), size: 20),
                    SizedBox(width: 8),
                    Text('المصادر وعن التطبيق'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent Mini Audio Player Bar
          const MiniAudioPlayerBar(),
          NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: destinations,
          ),
        ],
      ),
    );
  }
}

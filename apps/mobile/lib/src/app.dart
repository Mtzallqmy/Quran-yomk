import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branding.dart';
import 'l10n.dart';
import 'screens/favorites.dart';
import 'screens/home.dart';
import 'screens/islamic_library.dart';
import 'screens/mushaf.dart';
import 'screens/player.dart';
import 'screens/quran_offline.dart';
import 'screens/quran_playlists.dart';
import 'screens/radio.dart';
import 'screens/reciters.dart';
import 'screens/search.dart';
import 'screens/settings.dart';
import 'services.dart';
import 'theme.dart';

class TarteelApp extends ConsumerWidget {
  const TarteelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(servicesProvider).settings;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => context.l10n.appName,
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: TarteelTheme.light(),
        darkTheme: TarteelTheme.dark(),
        themeMode: settings.themeMode,
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;
  bool _mushafImmersive = false;

  void _setMushafImmersive(bool value) {
    if (_mushafImmersive != value) setState(() => _mushafImmersive = value);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final titles = <String>[s.home, s.radio, s.mushaf, s.reciters, s.favorites];
    final immersive = index == 2 && _mushafImmersive;
    final pages = <Widget>[
      const HomePage(),
      const RadioPage(),
      MushafPage(onImmersiveChanged: _setMushafImmersive),
      const RecitersPage(),
      const FavoritesPage(),
    ];
    return Scaffold(
      appBar: immersive
          ? null
          : AppBar(
              titleSpacing: 12,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const TarteelBrandMark(size: 34),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      '${s.appName} — ${titles[index]}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: english ? 'Quran playlists' : 'قوائم تشغيل القرآن',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QuranPlaylistsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.queue_music),
                ),
                IconButton(
                  tooltip: english ? 'Offline Quran' : 'الاستماع بدون إنترنت',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QuranOfflinePage(),
                    ),
                  ),
                  icon: const Icon(Icons.download_for_offline_outlined),
                ),
                IconButton(
                  tooltip: english ? 'Islamic library' : 'المكتبة الإسلامية',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const IslamicLibraryPage(),
                    ),
                  ),
                  icon: const Icon(Icons.local_library_outlined),
                ),
                IconButton(
                  tooltip: s.search,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SearchPage()),
                  ),
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: s.settings,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: immersive
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const MiniPlayerBar(),
                NavigationBar(
                  selectedIndex: index,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  destinations: <NavigationDestination>[
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: s.home,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.radio_outlined),
                      selectedIcon: const Icon(Icons.radio),
                      label: s.radio,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.auto_stories_outlined),
                      selectedIcon: const Icon(Icons.auto_stories),
                      label: s.mushaf,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.record_voice_over_outlined),
                      selectedIcon: const Icon(Icons.record_voice_over),
                      label: s.reciters,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.favorite_border),
                      selectedIcon: const Icon(Icons.favorite),
                      label: s.favorites,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

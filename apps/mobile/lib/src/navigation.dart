import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_manager.dart';
import 'services.dart';
import 'quran_audio.dart';
import 'screens/listening_history.dart';
import 'screens/favorites.dart';
import 'screens/library.dart';
import 'screens/listen.dart';
import 'screens/mushaf.dart';
import 'screens/player.dart';
import 'screens/quran_index.dart';
import 'screens/quran_offline.dart';
import 'screens/quran_playlists.dart';
import 'screens/radio.dart';
import 'screens/reciters.dart';
import 'screens/search.dart';
import 'screens/settings.dart';

/// Stable identities: hiding radio must never reinterpret a selected index.
enum MobileDestination { home, quran, listen, radio, library }

List<MobileDestination> mobileDestinations({required bool radioEnabled}) => [
  MobileDestination.home,
  MobileDestination.quran,
  MobileDestination.listen,
  if (radioEnabled) MobileDestination.radio,
  MobileDestination.library,
];

abstract final class MobileRoutes {
  static const quran = '/quran';
  static const reader = '/quran/reader';
  static const listen = '/listen';
  static const reciters = '/reciters';
  static const reciter = '/reciter';
  static const history = '/listening-history';
  static const bookmarks = '/quran/bookmarks';
  static const radio = '/radio';
  static const library = '/my-library';
  static const downloads = '/downloads';
  static const favorites = '/favorites';
  static const playlists = '/playlists';
  static const settings = '/settings';
  static const search = '/search';
  static const player = '/player';

  static Route<void>? generate(RouteSettings routeSettings) {
    final page = switch (routeSettings.name) {
      quran => const _Secondary(title: 'المصحف', child: QuranIndexPage()),
      reader => _ReaderRoute(page: routeSettings.arguments as int?),
      bookmarks => const _Secondary(
        title: 'العلامات المرجعية',
        child: QuranIndexPage(initialSection: 3),
      ),
      history => const ListeningHistoryPage(),
      reciter =>
        routeSettings.arguments is QuranAudioCatalogReciter
            ? QuranAudioReciterDetailPage(
                reciter: routeSettings.arguments! as QuranAudioCatalogReciter,
              )
            : null,
      listen => const _Secondary(title: 'الاستماع', child: ListenPage()),
      reciters => _Secondary(
        title: 'القراء',
        child: RecitersPage(surahNumber: routeSettings.arguments as int?),
      ),
      radio => const _FeatureRoute(
        feature: TarteelFeature.radio,
        child: _Secondary(title: 'الإذاعات', child: RadioPage()),
      ),
      library => const _Secondary(title: 'مكتبتي', child: LibraryPage()),
      downloads => const _FeatureRoute(
        feature: TarteelFeature.offlineDownloads,
        child: QuranOfflinePage(),
      ),
      favorites => const _Secondary(title: 'المفضلة', child: FavoritesPage()),
      playlists => const QuranPlaylistsPage(),
      settings => const SettingsPage(),
      search => const SearchPage(),
      player => const FullPlayerPage(),
      _ => null,
    };
    if (page == null) return null;
    return PageRouteBuilder<void>(
      settings: routeSettings,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondary, child) =>
          MediaQuery.disableAnimationsOf(context)
          ? child
          : FadeTransition(opacity: animation, child: child),
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: child,
  );
}

class _ReaderRoute extends StatefulWidget {
  const _ReaderRoute({this.page});
  final int? page;
  @override
  State<_ReaderRoute> createState() => _ReaderRouteState();
}

class _ReaderRouteState extends State<_ReaderRoute> {
  bool immersive = false;
  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: immersive ? null : AppBar(title: const Text('المصحف')),
    body: MushafPage(
      initialPage: widget.page,
      onImmersiveChanged: (value) {
        if (mounted && immersive != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => immersive = value);
            unawaited(
              SystemChrome.setEnabledSystemUIMode(
                value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
              ),
            );
          });
        }
      },
    ),
  );
}

class _FeatureRoute extends ConsumerWidget {
  const _FeatureRoute({required this.feature, required this.child});
  final TarteelFeature feature;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(servicesProvider).features;
    return AnimatedBuilder(
      animation: features,
      builder: (_, _) => features.enabled(feature)
          ? child
          : Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('هذا القسم غير متاح حاليًا')),
            ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branding.dart';
import 'l10n.dart';
import 'screens/favorites.dart';
import 'screens/home.dart';
import 'screens/islamic_library.dart';
import 'screens/learning.dart';
import 'screens/mushaf.dart';
import 'screens/player.dart';
import 'screens/prayer_times.dart';
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

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  int index = 0;
  bool _mushafImmersive = false;
  bool _openingRoute = false;
  StreamSubscription<String>? _notificationSubscription;
  StreamSubscription<String>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationSubscription = ref
        .read(servicesProvider)
        .localNotifications
        .payloads
        .listen(_handleNotificationPayload);
    _pushSubscription = ref
        .read(servicesProvider)
        .pushNotifications
        .routes
        .listen(_handlePushRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPushConsent());
  }

  Future<void> _showPushConsent() async {
    final push = ref.read(servicesProvider).pushNotifications;
    if (!mounted) return;
    if (!push.needsConsent) {
      await push.refreshPermissionState();
      return;
    }
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('ابقَ على اتصال مع ترتيل'),
        content: const Text(
          'يستخدم ترتيل الإشعارات لتذكيرك بمواقيت الصلاة، والأذكار، '
          'وخطط الحفظ والمراجعة، والتذكيرات التي تختارها، ورسائل مهمة من التطبيق.\n\n'
          'لن نستخدم الإشعارات لإرسال رسائل مزعجة، ويمكنك التحكم في أنواعها '
          'أو إيقافها لاحقًا من الإعدادات. هل تسمح لتطبيق ترتيل بإرسال الإشعارات؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ليس الآن'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('السماح بالإشعارات'),
          ),
        ],
      ),
    );
    if (allowed != true) {
      await push.deferConsent();
      return;
    }
    final success = await push.setEnabled(true);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(push.errorMessage),
          action: push.lastErrorCode == 'PERMISSION_DENIED'
              ? SnackBarAction(
                  label: 'فتح الإعدادات',
                  onPressed: ref
                      .read(servicesProvider)
                      .localNotifications
                      .openSystemSettings,
                )
              : null,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(servicesProvider).pushNotifications.refreshPermissionState(),
      );
    }
  }

  void _handleNotificationPayload(String payload) {
    if (!mounted) return;
    _handlePushRoute(payload);
  }

  void _handlePushRoute(String route) {
    if (!mounted) return;
    switch (route) {
      case '/home':
        setState(() => index = 0);
      case '/radio':
        setState(() => index = 1);
      case '/quran':
        setState(() => index = 2);
      case '/reciters':
        setState(() => index = 3);
      case '/prayer-times':
        unawaited(_open(const PrayerTimesPage()));
      case '/library':
        unawaited(_open(const IslamicLibraryPage()));
      case '/adhkar':
        unawaited(_open(const AdhkarPage()));
      case '/custom-reminders':
        unawaited(_open(const SettingsPage()));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notificationSubscription?.cancel());
    unawaited(_pushSubscription?.cancel());
    super.dispose();
  }

  void _setMushafImmersive(bool value) {
    if (_mushafImmersive != value) setState(() => _mushafImmersive = value);
  }

  Future<void> _open(Widget page) async {
    if (_openingRoute) return;
    _openingRoute = true;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
    } finally {
      _openingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = ref.watch(servicesProvider).remoteConfig;
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
                    child: Text(titles[index], overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: s.search,
                  onPressed: () => _open(const SearchPage()),
                  icon: const Icon(Icons.search),
                ),
                PopupMenuButton<_RootAction>(
                  tooltip: english ? 'More' : 'المزيد',
                  onSelected: (action) => switch (action) {
                    _RootAction.playlists => _open(const QuranPlaylistsPage()),
                    _RootAction.offline => _open(const QuranOfflinePage()),
                    _RootAction.library => _open(const IslamicLibraryPage()),
                    _RootAction.learning => _open(const LearningCenterPage()),
                    _RootAction.settings => _open(const SettingsPage()),
                  },
                  itemBuilder: (_) => <PopupMenuEntry<_RootAction>>[
                    PopupMenuItem<_RootAction>(
                      value: _RootAction.learning,
                      child: ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: Text(
                          english ? 'Memorization and review' : 'الحفظ والمراجعة',
                        ),
                      ),
                    ),
                    PopupMenuItem<_RootAction>(
                      value: _RootAction.playlists,
                      child: ListTile(
                        leading: const Icon(Icons.queue_music_outlined),
                        title: Text(
                          english ? 'Quran playlists' : 'قوائم تشغيل القرآن',
                        ),
                      ),
                    ),
                    PopupMenuItem<_RootAction>(
                      value: _RootAction.offline,
                      child: ListTile(
                        leading: const Icon(
                          Icons.download_for_offline_outlined,
                        ),
                        title: Text(
                          english ? 'Offline Quran' : 'الاستماع بدون إنترنت',
                        ),
                      ),
                    ),
                    PopupMenuItem<_RootAction>(
                      value: _RootAction.library,
                      child: ListTile(
                        leading: const Icon(Icons.local_library_outlined),
                        title: Text(
                          english ? 'Islamic library' : 'المكتبة الإسلامية',
                        ),
                      ),
                    ),
                    PopupMenuItem<_RootAction>(
                      value: _RootAction.settings,
                      child: ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: Text(s.settings),
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
      body: AnimatedBuilder(
        animation: remoteConfig,
        builder: (context, _) => Column(
          children: <Widget>[
            if (remoteConfig.maintenanceMode ||
                remoteConfig.announcementBanner.isNotEmpty)
              MaterialBanner(
                content: Text(
                  remoteConfig.maintenanceMode
                      ? remoteConfig.maintenanceMessage
                      : remoteConfig.announcementBanner,
                ),
                leading: Icon(
                  remoteConfig.maintenanceMode
                      ? Icons.build_outlined
                      : Icons.campaign_outlined,
                ),
                actions: const <Widget>[SizedBox.shrink()],
              ),
            Expanded(
              child: IndexedStack(index: index, children: pages),
            ),
          ],
        ),
      ),
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

enum _RootAction { learning, playlists, offline, library, settings }

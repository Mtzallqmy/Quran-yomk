import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branding.dart';
import 'feature_manager.dart';
import 'l10n.dart';
import 'push_notifications.dart';
import 'screens/favorites.dart';
import 'screens/home.dart';
import 'screens/islamic_library.dart';
import 'screens/learning.dart';
import 'screens/mushaf.dart';
import 'screens/notification_settings.dart';
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
          'بعد موافقتك فقط، نحفظ معرّف تثبيت عشوائي ورمز Firebase وإصدار التطبيق '
          'وتفضيلات أنواع الإشعارات. لا نقرأ جهات الاتصال أو الرسائل أو الملفات أو الموقع.\n\n'
          'يمكنك التحكم في الأنواع أو سحب الموافقة وإلغاء تسجيل الجهاز لاحقًا من '
          'الإعدادات. هل تسمح لتطبيق ترتيل بإرسال الإشعارات؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => showNotificationPrivacyDetails(context),
            child: const Text('تفاصيل الخصوصية'),
          ),
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
      unawaited(_refreshRuntimeState());
    }
  }

  Future<void> _refreshRuntimeState() async {
    final services = ref.read(servicesProvider);
    await Future.wait<void>(<Future<void>>[
      services.pushNotifications.refreshPermissionState(),
      services.remoteConfig.refresh(),
      services.announcements.refresh(),
    ]);
    if (services.features.enabled(TarteelFeature.prayer)) {
      await services.prayerReminders.start();
      await services.prayerReminders.reconcile();
    } else {
      await services.prayerReminders.suspend();
    }
    if (services.features.enabled(TarteelFeature.adhkar)) {
      await services.adhkarReminders.start();
    } else {
      await services.adhkarReminders.suspend();
    }
  }

  void _handleNotificationPayload(String payload) {
    if (!mounted) return;
    _handlePushRoute(payload);
  }

  void _handlePushRoute(String route) {
    if (!mounted) return;
    final normalized = notificationRoutePath(route);
    final features = ref.read(servicesProvider).features;
    if (normalized == null || !features.routeAllowed(normalized)) return;
    switch (normalized) {
      case '/':
      case '/home':
        setState(() => index = 0);
      case '/radio':
        setState(() => index = features.enabled(TarteelFeature.radio) ? 1 : 0);
      case '/quran':
        setState(() => index = features.enabled(TarteelFeature.radio) ? 2 : 1);
      case '/reciters':
        setState(() => index = features.enabled(TarteelFeature.radio) ? 3 : 2);
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
    final features = ref.watch(servicesProvider).features;
    final announcements = ref.watch(servicesProvider).announcements;
    final s = context.l10n;
    final english = Localizations.localeOf(context).languageCode == 'en';
    if (features.maintenanceMode) {
      return _MaintenanceScreen(
        message: features.maintenanceMessage,
        onRefresh: remoteConfig.refresh,
      );
    }
    if (features.updateRequirement == UpdateRequirement.required) {
      return _ForcedUpdateScreen(onRefresh: remoteConfig.refresh);
    }
    final radioEnabled = features.enabled(TarteelFeature.radio);
    final titles = <String>[
      s.home,
      if (radioEnabled) s.radio,
      s.mushaf,
      s.reciters,
      s.favorites,
    ];
    final mushafIndex = radioEnabled ? 2 : 1;
    if (index >= titles.length) index = 0;
    final immersive = index == mushafIndex && _mushafImmersive;
    final pages = <Widget>[
      const HomePage(),
      if (radioEnabled) const RadioPage(),
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
                          english
                              ? 'Memorization and review'
                              : 'الحفظ والمراجعة',
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
                    if (features.enabled(TarteelFeature.offlineDownloads))
                      PopupMenuItem<_RootAction>(
                        value: _RootAction.offline,
                        child: ListTile(
                          leading: const Icon(
                            Icons.download_for_offline_outlined,
                          ),
                          title: Text(
                            english
                                ? 'Offline Quran'
                                : 'الاستماع بدون إنترنت',
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
        animation: Listenable.merge(<Listenable>[
          remoteConfig,
          features,
          announcements,
        ]),
        builder: (context, _) => Column(
          children: <Widget>[
            if (announcements.current case final announcement?)
              MaterialBanner(
                leading: const Icon(Icons.campaign_outlined),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      announcement.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(announcement.body),
                  ],
                ),
                actions: <Widget>[
                  if (announcement.deepLink != null)
                    TextButton(
                      onPressed: () =>
                          _handlePushRoute(announcement.deepLink!),
                      child: const Text('فتح'),
                    ),
                  if (announcement.dismissible)
                    TextButton(
                      onPressed: () =>
                          announcements.dismiss(announcement.id),
                      child: const Text('إخفاء'),
                    ),
                ],
              ),
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
                    if (radioEnabled)
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

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message, required this.onRefresh});
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.build_circle_outlined, size: 64),
            const SizedBox(height: 16),
            Text('وضع الصيانة', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة التحقق'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ForcedUpdateScreen extends StatelessWidget {
  const _ForcedUpdateScreen({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.system_update_alt, size: 64),
            const SizedBox(height: 16),
            Text(
              'يلزم تحديث ترتيل',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'هذه النسخة لم تعد مدعومة. ثبّت النسخة التجريبية الأحدث ثم أعد المحاولة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة التحقق'),
            ),
          ],
        ),
      ),
    ),
  );
}

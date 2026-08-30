import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'screens/favorites.dart';
import 'screens/home.dart';
import 'screens/library.dart';
import 'screens/player.dart';
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
        title: 'Tarteel',
        locale: settings.locale,
        supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: TarteelTheme.light(),
        darkTheme: TarteelTheme.dark(),
        themeMode: settings.themeMode,
        builder: (context, child) => Directionality(
          textDirection: settings.locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
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
  final pages = const <Widget>[
    HomePage(),
    RadioPage(),
    RecitersPage(),
    LibraryPage(),
    FavoritesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = TarteelStrings.of(context);
    final titles = <String>[
      s.home,
      s.radio,
      s.reciters,
      s.library,
      s.favorites,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.appName} — ${titles[index]}'),
        actions: <Widget>[
          IconButton(
            tooltip: s.search,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage())),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: s.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MiniPlayerBar(),
          NavigationBar(
            selectedIndex: index,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: (value) => setState(() => index = value),
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
                icon: const Icon(Icons.record_voice_over_outlined),
                selectedIcon: const Icon(Icons.record_voice_over),
                label: s.reciters,
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: s.library,
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

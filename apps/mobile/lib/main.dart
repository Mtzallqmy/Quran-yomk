import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/brand_config.dart';
import 'core/services/app_services.dart';
import 'core/theme/quran_yutla_theme.dart';
import 'features/shell/presentation/root_shell.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core App Services (Composition Root)
  final appServices = await AppServices.init(
    onNavigateToRoute: (route) {
      debugPrint("Navigating to FCM target route: $route");
      navigatorKey.currentState?.pushNamed(route);
    },
  );

  runApp(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(appServices),
      ],
      child: const QuranYutlaApp(),
    ),
  );
}

class QuranYutlaApp extends StatelessWidget {
  const QuranYutlaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: BrandConfig.nameAr,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: QuranYutlaTheme.light(),
      darkTheme: QuranYutlaTheme.dark(),
      themeMode: ThemeMode.system,
      home: const RootShell(),
    );
  }
}

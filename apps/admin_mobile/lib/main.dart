import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/admin_api.dart';
import 'src/screens/admin.dart';
import 'src/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = MobileAdminSession();
  runApp(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(AdminServices(session)),
      ],
      child: const TarteelAdminApp(),
    ),
  );
  unawaited(session.restore());
}

class TarteelAdminApp extends StatelessWidget {
  const TarteelAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'إدارة ترتيل',
    locale: const Locale('ar'),
    supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
      useMaterial3: true,
    ),
    home: const AdminEntryPage(),
  );
}

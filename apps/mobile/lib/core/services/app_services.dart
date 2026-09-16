import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AppServices Container & Composition Root
class AppServices {
  final bool isInitialized;
  final String activeEnvironment;

  AppServices({
    required this.isInitialized,
    required this.activeEnvironment,
  });

  static Future<AppServices> init() async {
    // Composition Root: Initialize local DB, preferences, and remote configs
    return AppServices(
      isInitialized: true,
      activeEnvironment: 'development',
    );
  }
}

final appServicesProvider = Provider<AppServices>((ref) {
  throw UnimplementedError('AppServices must be initialized at bootstrap');
});

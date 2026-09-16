import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_notification_service.dart';

/// AppServices Container & Composition Root
class AppServices {
  final bool isInitialized;
  final String activeEnvironment;
  final PushNotificationService pushService;

  AppServices({
    required this.isInitialized,
    required this.activeEnvironment,
    required this.pushService,
  });

  static Future<AppServices> init({
    required Function(String route) onNavigateToRoute,
  }) async {
    final pushService = PushNotificationService.instance;

    try {
      await pushService.initialize(onNavigateToRoute: onNavigateToRoute);
    } catch (e) {
      debugPrint("Firebase/FCM init notice: $e");
    }

    return AppServices(
      isInitialized: true,
      activeEnvironment: 'development',
      pushService: pushService,
    );
  }
}

final appServicesProvider = Provider<AppServices>((ref) {
  throw UnimplementedError('AppServices must be initialized at bootstrap');
});

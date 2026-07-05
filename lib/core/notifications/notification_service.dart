/// lib/core/notifications/notification_service.dart
///
/// Stub notification service — Firebase is not configured yet.
/// Push notifications will be enabled once google-services.json is added.
/// All methods are safe no-ops so the app doesn't crash.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once in main() after the router is ready.
  static Future<void> init(GoRouter router) async {
    if (_initialized || kIsWeb) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _plugin.initialize(settings);
      _initialized = true;
      debugPrint('NotificationService: local notifications ready');
    } catch (e) {
      debugPrint('NotificationService: init failed (non-fatal): $e');
    }
  }

  /// Show a local notification (used for order/message alerts).
  static Future<void> showLocal({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'wazibot_high_importance',
        'WaziBot Alerts',
        channelDescription: 'Order and customer notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('NotificationService: showLocal failed: $e');
    }
  }

  /// Returns null — Firebase not configured yet.
  static Future<String?> getToken() async => null;

  /// No-op — will be implemented when Firebase is configured.
  static Future<void> registerToken(
      Future<void> Function(String token) onRegister) async {}
}

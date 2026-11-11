import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';
import 'firebase_service.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with `@pragma('vm:entry-point')` so the Flutter engine
/// can invoke it in an isolated background isolate when the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM Background] Message received: ${message.messageId} | ${message.notification?.title}');
  // Display the message via flutter_local_notifications in this background
  // isolate. This is required for data-only payloads (and payloads whose
  // notification title/body are empty), which produce NO automatic system
  // tray notification when the app is in background/terminated state.
  final hasVisibleNotification = message.notification != null &&
      ((message.notification?.title ?? '').isNotEmpty ||
          (message.notification?.body ?? '').isNotEmpty);
  if (!hasVisibleNotification && message.data.isNotEmpty) {
    await NotificationService.showBackgroundDataNotification(message);
  }
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for real-time shop orders, bay progress, and chat messages.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static bool _initialized = false;

  /// Initializes local notifications, notification channels, foreground listener,
  /// background tap listeners, and initial cold-start message handler.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Initialize local notifications plugin
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payloadString = response.payload;
        if (payloadString != null && payloadString.isNotEmpty) {
          try {
            final map = jsonDecode(payloadString);
            if (map is Map<String, dynamic>) {
              NotificationRouter.handlePayload(map);
            }
          } catch (e) {
            debugPrint('[NotificationService] Error parsing tap payload: $e');
          }
        }
      },
    );

    // 2. Register Android high importance channel
    if (!kIsWeb) {
      final androidImplementation = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(highImportanceChannel);
      }
    }

    // Request runtime permission for push notifications (Android 13+ & iOS)
    await requestNotificationPermission();

    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // 3. Foreground FCM listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Foreground FCM received: ${message.notification?.title}');
      showForegroundNotification(message);
    });

    // 4. Background notification tapped (app in background, brought to foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Background notification opened: ${message.data}');
      NotificationRouter.handleRemoteMessage(message);
    });

    // 5. Cold start notification check (app launched from killed state by tapping notification)
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] App launched from killed state by notification: ${initialMessage.data}');
        _scheduleColdStartRouting(initialMessage.data);
      }
    } catch (e) {
      debugPrint('[NotificationService] Cold start message check warning: $e');
    }

    // 6. Re-register the background/terminated-state handler every app launch.
    // FCM stores this registration in native prefs; re-registering keeps it
    // valid after hot restarts, reinstalls and app updates.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 7. Re-sync the FCM token on every cold start. When the app was killed
    // (swiped away), Google Play services may rotate the token; without this,
    // user_bindings/{user}.fcmTokens keeps a stale token and pushes silently
    // fail while the app is closed.
    unawaited(resyncFcmToken());
  }

  /// Waits (with retries) until the navigator context is mounted, then routes
  /// a cold-start notification payload to its destination screen.
  static void _scheduleColdStartRouting(Map<String, dynamic> payload) {
    var attempts = 0;
    void tryRoute() {
      attempts++;
      if (navigatorKey.currentContext != null) {
        NotificationRouter.handlePayload(payload);
        return;
      }
      if (attempts >= 10) return; // give up after ~6s
      Future.delayed(const Duration(milliseconds: 600), tryRoute);
    }
    Future.delayed(const Duration(milliseconds: 600), tryRoute);
  }

  /// Fetches the current FCM token and merges it into all active user bindings
  /// so devices that were killed still receive push notifications.
  static Future<void> resyncFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      debugPrint('[NotificationService] Resyncing FCM token to user bindings');
      await FirebaseService.instance.updateAllActiveBindingsWithToken(token);
    } catch (e) {
      debugPrint('[NotificationService] FCM token resync warning: $e');
    }
  }

  /// Prompts the user for runtime notification permissions on Android 13+ (API 33) and iOS.
  static Future<bool> requestNotificationPermission() async {
    bool granted = false;
    try {
      if (!kIsWeb) {
        final androidImpl = localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final androidGranted = await androidImpl.requestNotificationsPermission();
          granted = androidGranted ?? false;
        }
      }

      final fcmSettings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (fcmSettings.authorizationStatus == AuthorizationStatus.authorized ||
          fcmSettings.authorizationStatus == AuthorizationStatus.provisional) {
        granted = true;
      }
      debugPrint('[NotificationService] Notification permission granted: $granted');
    } catch (e) {
      debugPrint('[NotificationService] requestNotificationPermission error: $e');
    }
    return granted;
  }

  /// Displays a heads-up local notification when an FCM message arrives in foreground
  static Future<void> showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'Boss Arman MotoHub';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';
    final payloadString = jsonEncode(message.data);

    final androidDetails = AndroidNotificationDetails(
      highImportanceChannel.id,
      highImportanceChannel.name,
      channelDescription: highImportanceChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final notificationId = message.messageId.hashCode;
    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payloadString,
    );
  }

  /// Displays an instant heads-up pop-up banner notification with sound and vibration
  static Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (!kIsWeb) {
        final androidImpl = localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(highImportanceChannel);
        }
      }

      final payloadString = payload != null ? jsonEncode(payload) : null;
      final androidDetails = AndroidNotificationDetails(
        highImportanceChannel.id,
        highImportanceChannel.name,
        channelDescription: highImportanceChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payloadString,
      );
      debugPrint('[NotificationService] Displayed heads-up notification: "$title"');
    } catch (e) {
      debugPrint('[NotificationService] showNotification error: $e');
    }
  }

  /// Displays a notification for data-only messages when app is in background or killed
  static Future<void> showBackgroundDataNotification(RemoteMessage message) async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidSettings, iOS: darwinSettings);
      await localNotifications.initialize(settings: initSettings);

      final androidImplementation = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(highImportanceChannel);
      }
    } catch (_) {}

    final title = message.data['title'] ?? 'Boss Arman MotoHub';
    final body = message.data['body'] ?? message.data['message'] ?? '';
    final payloadString = jsonEncode(message.data);

    final androidDetails = AndroidNotificationDetails(
      highImportanceChannel.id,
      highImportanceChannel.name,
      channelDescription: highImportanceChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payloadString,
    );
    // Force the pending notification/payload to be written to disk immediately.
    // Without this, the OS may kill the short-lived background isolate before
    // it flushes, and the notification never appears (or appears with no payload).
    try {
      await localNotifications.flushNotificationsOnDatabases();
    } catch (_) {}
  }
}

/// Unified notification routing engine across:
/// 1) Cold start (killed app)
/// 2) Background notification tap
/// 3) Local heads-up notification tap
/// 4) In-app notification sheet tap
class NotificationRouter {
  static void handleRemoteMessage(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      handlePayload(message.data);
    }
  }

  static void handlePayload(Map<String, dynamic> payload) {
    final navContext = NotificationService.navigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('[NotificationRouter] Navigator context not ready for routing.');
      return;
    }
    final type = payload['type']?.toString().toLowerCase() ?? '';
    final refId = payload['refId']?.toString() ?? payload['id']?.toString() ?? '';

    route(navContext, type: type, refId: refId, meta: payload);
  }

  static void routeNotification(BuildContext context, AppNotificationItem item) {
    final payload = item.payload ?? {};
    final type = (payload['type'] ?? item.category).toString().toLowerCase();
    final refId = (payload['refId'] ?? item.id).toString();

    route(context, type: type, refId: refId, meta: payload);
  }

  static void route(
    BuildContext context, {
    required String type,
    required String refId,
    Map<String, dynamic>? meta,
  }) {
    debugPrint('[NotificationRouter] Routing to type: $type | refId: $refId');

    switch (type) {
      case 'chat':
        if (refId.isNotEmpty) {
          // Open chat conversation screen
          _openChat(context, threadId: refId, meta: meta);
        }
        break;

      case 'job_order':
      case 'service':
        // For job orders: could show job details dialog or snackbar
        _showJobOrderBanner(context, refId);
        break;

      case 'transfer':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inter-Branch Stock Transfer: $refId'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;

      case 'low_stock':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Low Stock Warning for Part: $refId'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;

      case 'reservation':
      case 'click_collect':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Click & Collect Reservation: $refId'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;

      default:
        debugPrint('[NotificationRouter] Unhandled routing type: $type');
    }
  }

  static void _openChat(
    BuildContext context, {
    required String threadId,
    Map<String, dynamic>? meta,
  }) {
    // Dynamic callback or navigator push to ChatConversationScreen
    final routeName = '/chat/$threadId';
    Navigator.of(context).pushNamed(routeName, arguments: {'threadId': threadId, ...?meta});
  }

  static void _showJobOrderBanner(BuildContext context, String jobId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job Order #$jobId notification received.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:starvy/firebase_options.dart';
import 'package:starvy/data/model/app_notification.dart';
import 'package:starvy/service/shared_preferences_service.dart';

Future<void> _saveNotificationToPrefs(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  try {
    await SharedPreferencesService.init();
    final localNotification = AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? '',
      body: notification.body ?? '',
      timestamp: DateTime.now(),
      isRead: false,
    );
    await SharedPreferencesService().addNotification(localNotification);
  } catch (e) {
    debugPrint("Error saving notification to prefs: $e");
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling a background message: ${message.messageId}");
  await _saveNotificationToPrefs(message);
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'Notifikasi Penting', // title
    description: 'Channel ini digunakan untuk notifikasi penting.', // description
    importance: Importance.high,
  );

  bool _isInitialized = false;

  final StreamController<RemoteMessage> _foregroundMessageStreamController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get foregroundMessageStream =>
      _foregroundMessageStreamController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground alerts
    if (!kIsWeb) {
      // Create android notification channel
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification clicked: ${response.payload}");
        },
      );
    }

    // Configure foreground notification options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("Foreground message received: ${message.notification?.title}");
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && !kIsWeb) {
        // Save to preferences locally
        await _saveNotificationToPrefs(message);

        // Add to stream so active providers can notify listeners in UI
        _foregroundMessageStreamController.add(message);

        // Show heads up banner
        _localNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    // Handle user tapping notification when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("Notification clicked & app opened: ${message.notification?.title}");
    });

    // Handle user tapping notification when app was terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("App launched from terminated state via notification: ${initialMessage.notification?.title}");
    }

    // Subscribe to all_users topic
    try {
      await _messaging.subscribeToTopic('all_users');
      debugPrint("Subscribed to all_users topic successfully.");
    } catch (e) {
      debugPrint("Failed to subscribe to all_users topic: $e");
    }

    _isInitialized = true;
    debugPrint("NotificationService successfully initialized.");
  }

  /// Request permissions for iOS and Android 13+
  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint("User notification permission status: ${settings.authorizationStatus}");
    return settings;
  }

  /// Retrieve the FCM registration token for sending targeting push notifications
  Future<String?> getFcmToken() async {
    try {
      String? token = await _messaging.getToken();
      debugPrint("FCM Registration Token: $token");
      return token;
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
      return null;
    }
  }
}

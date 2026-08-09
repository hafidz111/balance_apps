import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../data/model/app_notification.dart';
import '../service/shared_preferences_service.dart';
import '../service/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  StreamSubscription<RemoteMessage>? _streamSubscription;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    loadNotifications();
    _streamSubscription = NotificationService.instance.foregroundMessageStream.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        final localNotification = AppNotification(
          id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: notification.title ?? '',
          body: notification.body ?? '',
          timestamp: DateTime.now(),
          isRead: false,
        );
        // Note: we don't call addNotification directly because addNotification saves to prefs,
        // but the notification is already saved to prefs in the service onMessage listener.
        // We just need to insert it in memory and notify listeners.
        _notifications.insert(0, localNotification);
        notifyListeners();
      }
    });
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _prefsService.getNotifications();
    } catch (e) {
      debugPrint("Error loading notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNotification(AppNotification n) async {
    _notifications.insert(0, n);
    notifyListeners();
    try {
      await _prefsService.addNotification(n);
    } catch (e) {
      debugPrint("Error saving new notification: $e");
    }
  }

  Future<void> markAllAsRead() async {
    if (_notifications.isEmpty) return;
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    try {
      await _prefsService.saveNotifications(_notifications);
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  Future<void> deleteReadNotifications() async {
    _notifications = _notifications.where((n) => !n.isRead).toList();
    notifyListeners();
    try {
      await _prefsService.saveNotifications(_notifications);
    } catch (e) {
      debugPrint("Error deleting read notifications: $e");
    }
  }

  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
    try {
      await _prefsService.saveNotifications([]);
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

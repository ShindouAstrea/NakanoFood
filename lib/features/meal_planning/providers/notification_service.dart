import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> scheduleMealNotification({
    required int id,
    required String categoryName,
    required String mealTitle,
    required DateTime scheduledTime,
    required int minutesBefore,
  }) async {
    if (kIsWeb) return;

    final notifyTime =
        scheduledTime.subtract(Duration(minutes: minutesBefore));
    if (notifyTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'meal_reminders',
      'Recordatorios de comidas',
      channelDescription: 'Notificaciones para recordatorios de alimentación',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      '🍽️ $categoryName',
      minutesBefore > 0
          ? 'En $minutesBefore min: $mealTitle'
          : mealTitle,
      tz.TZDateTime.from(notifyTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}

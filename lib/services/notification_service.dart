import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../data/models/bill_model.dart';
import '../presentation/state/app_settings_provider.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Request exact alarm permission on Android 12+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// Request POST_NOTIFICATIONS permission (Android 13+) or prompt iOS again.
  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Stable int ID for each bill + offset (0=5d, 1=2d, 2=due)
  static int _notifId(String billId, int offset) =>
      (billId.hashCode & 0x7FFFFFFF) % 100000 * 3 + offset;

  static Future<String> _currencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = (prefs.getInt('currency_index') ?? 0)
        .clamp(0, kCurrencies.length - 1);
    return kCurrencies[idx].symbol;
  }

  static Future<void> scheduleBill(BillModel bill) async {
    if (kIsWeb) return;
    await cancelBill(bill.id);
    if (bill.isPaid) return;

    final now = DateTime.now();
    final symbol = await _currencySymbol();
    final slots = [
      (bill.remind5Days, 0, bill.dueDate.subtract(const Duration(days: 5))),
      (bill.remind2Days, 1, bill.dueDate.subtract(const Duration(days: 2))),
      (bill.remindDueDay, 2,
          DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day, 9)),
    ];

    for (final (enabled, offset, time) in slots) {
      if (!enabled || !time.isAfter(now)) continue;
      final labels = ['in 5 days', 'in 2 days', 'today'];
      final body = bill.amount != null
          ? '$symbol${bill.amount!.toStringAsFixed(0)} due ${labels[offset]}'
          : 'Payment due ${labels[offset]}';
      await _schedule(
        id: _notifId(bill.id, offset),
        title: bill.name,
        body: body,
        scheduledDate: time,
      );
    }
  }

  static Future<void> cancelBill(String billId) async {
    if (kIsWeb) return;
    await Future.wait([
      _plugin.cancel(_notifId(billId, 0)),
      _plugin.cancel(_notifId(billId, 1)),
      _plugin.cancel(_notifId(billId, 2)),
    ]);
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminders',
          'Bill Reminders',
          channelDescription: 'Reminders for upcoming bill due dates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../data/models/bill_model.dart';
import '../data/models/due_model.dart';
import '../presentation/state/app_settings_provider.dart';
import '../presentation/state/user_provider.dart';

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

  // Stable int ID for each due + offset (0=3d, 1=1d, 2=due, 3=overdue)
  static int _dueNotifId(String dueId, int offset) =>
      (dueId.hashCode & 0x7FFFFFFF) % 100000 * 4 + offset + 300000;

  static Future<String> _currencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = (prefs.getInt('currency_index') ?? 0)
        .clamp(0, kCurrencies.length - 1);
    return kCurrencies[idx].symbol;
  }

  static Future<bool> _areDueRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('due_reminders_enabled') ?? true;
  }

  static Future<void> _setDueRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('due_reminders_enabled', enabled);
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

  // ── Due Notifications ─────────────────────────────────────────────────────

  static Future<void> scheduleDue(DueModel due) async {
    if (kIsWeb) return;
    await cancelDue(due.id);
    if (due.isSettled) return;

    // Check if due reminders are enabled
    final remindersEnabled = await _areDueRemindersEnabled();
    if (!remindersEnabled) return;

    final now = DateTime.now();
    final symbol = await _currencySymbol();
    final today = DateTime(now.year, now.month, now.day);
    
    final slots = [
      (true, 0, due.dueDate?.subtract(const Duration(days: 3))), // 3 days before
      (true, 1, due.dueDate?.subtract(const Duration(days: 1))), // 1 day before
      (true, 2, due.dueDate), // Due date
    ];

    // Add overdue notification if due date has passed
    if (due.dueDate != null && due.dueDate!.isBefore(today)) {
      slots.add((true, 3, today.add(const Duration(hours: 9)))); // Overdue today
    }

    for (final (enabled, offset, time) in slots) {
      if (!enabled || time == null || !time.isAfter(now)) continue;
      
      final labels = ['in 3 days', 'tomorrow', 'due today', 'overdue'];
      final isLent = due.type == 'lent';
      final action = isLent ? 'to receive' : 'to pay';
      
      final body = '$symbol${due.amount.toStringAsFixed(0)} $action ${labels[offset]}';
      final title = isLent 
          ? '${due.personName} owes you'
          : 'You owe ${due.personName}';
      
      await _scheduleDue(
        id: _dueNotifId(due.id, offset),
        title: title,
        body: body,
        scheduledDate: time,
        isOverdue: offset == 3,
      );
    }
  }

  static Future<void> cancelDue(String dueId) async {
    if (kIsWeb) return;
    await Future.wait([
      _plugin.cancel(_dueNotifId(dueId, 0)),
      _plugin.cancel(_dueNotifId(dueId, 1)),
      _plugin.cancel(_dueNotifId(dueId, 2)),
      _plugin.cancel(_dueNotifId(dueId, 3)),
    ]);
  }

  static Future<void> _scheduleDue({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isOverdue = false,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'due_reminders',
          'Due Reminders',
          channelDescription: 'Reminders for due dates and overdue dues',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFFF97316),
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

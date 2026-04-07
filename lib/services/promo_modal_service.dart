import 'package:shared_preferences/shared_preferences.dart';

class PromoModalService {
  static const _key = 'promo_last_shown_ms';
  static const _intervalDays = 15;

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_key);
    if (lastMs == null) return true;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
        .inDays;
    return daysSince >= _intervalDays;
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }
}

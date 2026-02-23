import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _enabledKey = 'biometric_enabled';

  /// Whether the device hardware supports biometrics (enrolled or not).
  /// Uses isDeviceSupported() so the offer sheet appears even before
  /// the user has enrolled biometrics — the authenticate() call handles that.
  static Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Whether the user has opted in to biometric login.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Save user preference for biometric login.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Prompt the device biometric / PIN dialog.
  /// Returns true if the user successfully authenticated.
  static Future<bool> authenticate({String reason = 'Unlock Bill Buddy'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN as fallback
          stickyAuth: true,     // keep prompt alive if user switches apps
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/utils/auth_bootstrap.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress known Flutter web engine assertion bugs that are safe to ignore:
  //  • ViewInsets negative  — keyboard dismissal triggers a bad browser resize
  //  • mouse_tracker        — mouse device untracked during widget disposal / navigation
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('mouse_tracker.dart')) return;
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('ViewInsets cannot be negative')) return true;
    return false;
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Clear Firestore's offline cache when the app version changes.
  // Firestore persists a local disk cache that survives OTA updates, which can
  // cause stale data or layout inconsistencies after a Play Store update. This
  // runs silently — no user action needed. Must happen before any Firestore
  // reads (i.e., before providers open their streams via runApp).
  await _clearFirestoreCacheOnVersionChange();

  await AuthBootstrap.ensureSignedIn();
  await NotificationService.init();
  runApp(const SmartBillApp());
}

Future<void> _clearFirestoreCacheOnVersionChange() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final currentVersion = '${info.version}+${info.buildNumber}';
    final storedVersion = prefs.getString('_app_version');
    if (storedVersion != currentVersion) {
      final db = FirebaseFirestore.instance;
      await db.terminate();
      await db.clearPersistence();
      await prefs.setString('_app_version', currentVersion);
    }
  } catch (_) {
    // Non-fatal — if this fails, the app continues normally.
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
  await AuthBootstrap.ensureSignedIn();
  await NotificationService.init();
  runApp(const SmartBillApp());
}

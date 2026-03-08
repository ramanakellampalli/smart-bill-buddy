import 'package:flutter/material.dart';

void showAppToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: duration,
        backgroundColor: const Color(0xFF1C1917),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
}

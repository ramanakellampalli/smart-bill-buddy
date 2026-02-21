import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/bills_provider.dart';
import '../state/user_provider.dart';
import 'login_screen.dart';
import 'home_shell.dart';

// UserProvider and BillsProvider both self-manage via their own auth listeners.
// AuthWrapper only needs to watch loading state — no manual triggers needed.

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (snapshot.hasError) {
          return const _ErrorScreen();
        }

        if (snapshot.hasData) {
          final billsLoading = context.watch<BillsProvider>().isLoading;
          final userLoading  = context.watch<UserProvider>().isLoading;

          if (billsLoading || userLoading) {
            return const _SplashScreen();
          }

          return const HomeShell();
        }

        return const LoginScreen();
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                _LogoBox(),
                SizedBox(width: 14),
                Text(
                  'Bill Buddy',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFF97316),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/icon-512.png',
      width: 52,
      height: 52,
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAF8F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 48),
            SizedBox(height: 16),
            Text(
              'Authentication Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1917),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/bills_provider.dart';
import '../state/user_provider.dart';
import '../../services/biometric_service.dart';
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

          return const _BiometricGate();
        }

        return const LoginScreen();
      },
    );
  }
}

// ── Biometric Gate ─────────────────────────────────────────────────────────────
// Shown when Firebase session is alive. If biometric is enabled, prompt the
// user before revealing HomeShell. Otherwise pass straight through to HomeShell.

class _BiometricGate extends StatefulWidget {
  const _BiometricGate();

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate> {
  // null = still checking, true = unlocked, false = locked (prompt shown)
  bool? _unlocked;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _checkAndPrompt();
  }

  Future<void> _checkAndPrompt() async {
    final enabled = await BiometricService.isEnabled();
    if (!enabled) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    // Biometric is required — show lock screen then prompt
    if (mounted) setState(() => _unlocked = false);
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    if (mounted) setState(() => _authenticating = true);
    final ok = await BiometricService.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _unlocked = true;
    });
  }

  Future<void> _usePasswordInstead() async {
    await FirebaseAuth.instance.signOut();
    // Stream rebuilds → LoginScreen shown
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked == null) return const _SplashScreen();
    if (_unlocked == true) return const HomeShell();
    return _LockScreen(
      authenticating: _authenticating,
      onRetry: _authenticate,
      onUsePassword: _usePasswordInstead,
    );
  }
}

// ── Lock Screen ────────────────────────────────────────────────────────────────

class _LockScreen extends StatelessWidget {
  final bool authenticating;
  final VoidCallback onRetry;
  final VoidCallback onUsePassword;

  const _LockScreen({
    required this.authenticating,
    required this.onRetry,
    required this.onUsePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/icon-512.png', width: 72, height: 72),
                const SizedBox(height: 20),
                const Text(
                  'Bill Buddy',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verify your identity to continue',
                  style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                GestureDetector(
                  onTap: authenticating ? null : onRetry,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha:0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF97316).withValues(alpha:0.30),
                        width: 2,
                      ),
                    ),
                    child: authenticating
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFF97316),
                            ),
                          )
                        : const Icon(
                            Icons.fingerprint_rounded,
                            size: 40,
                            color: Color(0xFFF97316),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  authenticating ? 'Authenticating…' : 'Tap to authenticate',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: onUsePassword,
                  child: const Text(
                    'Use password instead',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF78716C),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          children: const [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

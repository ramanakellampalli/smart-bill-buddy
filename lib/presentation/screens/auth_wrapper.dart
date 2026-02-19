import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/user_provider.dart';
import 'login_screen.dart';
import 'home_shell.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAF8F5),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF97316),
              ),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFFAF8F5),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Authentication Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Authenticated user
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Initialize user provider when user is authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().loadUserProfile(user.uid);
          });
          return const HomeShell();
        }

        // Not authenticated - show login screen
        return const LoginScreen();
      },
    );
  }
}

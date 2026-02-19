import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_screen.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectRoute;

  const AuthGuard({
    super.key,
    required this.child,
    this.redirectRoute,
  });

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

        // Not authenticated - redirect to login
        if (!snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => LoginScreen(redirectRoute: redirectRoute),
              ),
              (route) => false,
            );
          });
          return const Scaffold(
            backgroundColor: Color(0xFFFAF8F5),
          );
        }

        // Authenticated - show child
        return child;
      },
    );
  }
}

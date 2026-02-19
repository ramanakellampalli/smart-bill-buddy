import 'package:firebase_auth/firebase_auth.dart';

class AuthBootstrap {
  static Future<String?> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    
    // Return user ID if already authenticated
    if (current != null) return current.uid;

    // No authenticated user - return null to show login screen
    return null;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();
}

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  UserProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadUserProfile(currentUser.uid);
    }
  }

  Future<void> loadUserProfile(String uid) async {
    try {
      _setLoading(true);
      _error = null;

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('user')
          .get();
      
      if (doc.exists) {
        _profile = UserProfile.fromMap(doc.data()!);
      } else {
        // Create profile if it doesn't exist
        final user = _auth.currentUser;
        if (user != null) {
          _profile = UserProfile.fromFirebaseUser(user);
          try {
            await _saveUserProfile();
          } catch (e) {
            // If saving fails, at least set the profile locally
            if (kDebugMode) {
              print('Failed to save profile: $e');
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user profile: ${e.toString()}';
      if (kDebugMode) {
        print('UserProvider error: $e');
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    if (_profile == null) return;

    try {
      _setLoading(true);
      _error = null;

      // Update Firebase Auth profile
      await _auth.currentUser?.updateDisplayName(displayName);

      // Update Firestore profile
      _profile = _profile!.copyWith(
        displayName: displayName,
        lastActiveAt: DateTime.now(),
      );
      await _saveUserProfile();
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update display name: ${e.toString()}';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateNotificationSettings({
    bool? notificationsEnabled,
    bool? emailNotificationsEnabled,
    bool? pushNotificationsEnabled,
  }) async {
    if (_profile == null) return;

    try {
      _error = null;

      _profile = _profile!.copyWith(
        notificationsEnabled: notificationsEnabled,
        emailNotificationsEnabled: emailNotificationsEnabled,
        pushNotificationsEnabled: pushNotificationsEnabled,
        lastActiveAt: DateTime.now(),
      );
      await _saveUserProfile();
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update notification settings: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> updatePreferences({
    String? timezone,
    String? currency,
  }) async {
    if (_profile == null) return;

    try {
      _error = null;

      _profile = _profile!.copyWith(
        timezone: timezone,
        currency: currency,
        lastActiveAt: DateTime.now(),
      );
      await _saveUserProfile();
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update preferences: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> updateBillStats({
    required int totalBillsCreated,
    required int totalBillsPaid,
    required double totalAmountSpent,
  }) async {
    if (_profile == null) return;

    try {
      _error = null;

      _profile = _profile!.copyWith(
        totalBillsCreated: totalBillsCreated,
        totalBillsPaid: totalBillsPaid,
        totalAmountSpent: totalAmountSpent,
        lastActiveAt: DateTime.now(),
      );
      await _saveUserProfile();
      
      notifyListeners();
    } catch (e) {
      // Don't set error for stats updates to avoid disrupting the UI
      if (kDebugMode) {
        print('Failed to update bill stats: ${e.toString()}');
      }
    }
  }

  Future<void> refreshProfile() async {
    if (_profile != null) {
      await loadUserProfile(_profile!.uid);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _profile = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    try {
      _setLoading(true);
      _error = null;

      final user = _auth.currentUser;
      if (user != null) {
        // Delete user profile from Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('profile')
            .doc('user')
            .delete();
        
        // Delete user's bills
        final billsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('bills')
            .get();
        
        for (final doc in billsSnapshot.docs) {
          await doc.reference.delete();
        }
        
        // Delete Firebase Auth user
        await user.delete();
        
        _profile = null;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to delete account: ${e.toString()}';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveUserProfile() async {
    if (_profile == null) return;

    await _firestore
        .collection('users')
        .doc(_profile!.uid)
        .collection('profile')
        .doc('user')
        .set(_profile!.toMap());
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

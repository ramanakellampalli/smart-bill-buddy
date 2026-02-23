import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/due_model.dart';
import '../../data/repositories/dues_repository.dart';
import '../../services/notification_service.dart';

class DuesProvider extends ChangeNotifier {
  final DuesRepository _repo;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<DueModel>>? _duesSub;

  List<DueModel> dues = [];
  bool saving = false;
  bool isLoading = true;
  String? error;

  String? _currentUid;

  DuesProvider(this._repo) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (_currentUid == null) return;
        _currentUid = null;
        _duesSub?.cancel();
        _duesSub = null;
        dues = [];
        isLoading = false;
        notifyListeners();
      } else if (user.uid != _currentUid) {
        _currentUid = user.uid;
        _duesSub?.cancel();
        _duesSub = null;
        isLoading = true;
        notifyListeners();
        _duesSub = _repo.watchDues(user.uid).listen(
          (items) {
            dues = items;
            isLoading = false;
            error = null;
            // Schedule notifications for all active dues
            scheduleAllDueNotifications();
            notifyListeners();
          },
          onError: (e) {
            isLoading = false;
            error = e.toString();
            notifyListeners();
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _duesSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> add(DueModel due) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.addDue(due);
      // Schedule notifications for the new due
      await NotificationService.scheduleDue(due);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> update(DueModel due) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.updateDue(due);
      // Reschedule notifications for the updated due
      await NotificationService.scheduleDue(due);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> settle(String dueId) async {
    try {
      await _repo.settleDue(dueId);
      // Cancel notifications for settled due
      await NotificationService.cancelDue(dueId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> delete(String dueId) async {
    try {
      // Cancel notifications before deleting
      await NotificationService.cancelDue(dueId);
      await _repo.deleteDue(dueId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  // Schedule notifications for all active dues (called on app startup)
  Future<void> scheduleAllDueNotifications() async {
    for (final due in dues) {
      if (!due.isSettled) {
        try {
          await NotificationService.scheduleDue(due);
        } catch (e) {
          // Continue scheduling other dues even if one fails
          print('Error scheduling notification for due ${due.id}: $e');
        }
      }
    }
  }
}

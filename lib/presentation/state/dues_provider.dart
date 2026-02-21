import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/due_model.dart';
import '../../data/repositories/dues_repository.dart';

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
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> delete(String dueId) async {
    try {
      await _repo.deleteDue(dueId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}

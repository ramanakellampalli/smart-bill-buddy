import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budgets_repository.dart';

class BudgetsProvider extends ChangeNotifier {
  final BudgetsRepository _repo;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<BudgetModel>>? _budgetsSub;
  String? _currentUid;

  List<BudgetModel> budgets = [];
  bool isLoading = true;
  bool saving = false;
  String? error;

  BudgetsProvider(this._repo) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (_currentUid == null) return; // already signed out, no-op
        _currentUid = null;
        _budgetsSub?.cancel();
        _budgetsSub = null;
        budgets = [];
        isLoading = false;
        notifyListeners();
      } else if (user.uid != _currentUid) {
        _currentUid = user.uid;
        _budgetsSub?.cancel();
        isLoading = true;
        notifyListeners();

        _budgetsSub = _repo.watchBudgets(user.uid).listen(
          (items) {
            budgets = items;
            isLoading = false;
            error = null;
            notifyListeners();
          },
          onError: (e) {
            error = e.toString();
            isLoading = false;
            notifyListeners();
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _budgetsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> set(BudgetModel budget) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.setBudget(budget);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> remove(String budgetId) async {
    try {
      await _repo.deleteBudget(budgetId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}

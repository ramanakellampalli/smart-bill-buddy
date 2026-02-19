import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budgets_repository.dart';

class BudgetsProvider extends ChangeNotifier {
  final BudgetsRepository _repo;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<BudgetModel>>? _budgetsSub;

  List<BudgetModel> budgets = [];
  bool saving = false;
  String? error;

  BudgetsProvider(this._repo) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _budgetsSub?.cancel();
      _budgetsSub = null;

      if (user == null) {
        budgets = [];
        notifyListeners();
      } else {
        _budgetsSub = _repo.watchBudgets(user.uid).listen(
          (items) {
            budgets = items;
            error = null;
            notifyListeners();
          },
          onError: (e) {
            error = e.toString();
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

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expenses_repository.dart';

class ExpensesProvider extends ChangeNotifier {
  final ExpensesRepository _repo;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ExpenseModel>>? _expensesSub;
  String? _currentUid;

  List<ExpenseModel> expenses = [];
  bool isLoading = true;
  bool saving = false;
  String? error;

  ExpensesProvider(this._repo) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (_currentUid == null) return;
        _currentUid = null;
        _expensesSub?.cancel();
        _expensesSub = null;
        expenses = [];
        isLoading = false;
        notifyListeners();
      } else if (user.uid != _currentUid) {
        _currentUid = user.uid;
        _expensesSub?.cancel();
        isLoading = true;
        notifyListeners();

        _expensesSub = _repo.watchExpenses(user.uid).listen(
          (items) {
            expenses = items;
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
    _expensesSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> add(ExpenseModel expense) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.addExpense(expense);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> update(ExpenseModel expense) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.updateExpense(expense);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(String expenseId) async {
    try {
      await _repo.deleteExpense(expenseId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// Returns expenses for a given month.
  List<ExpenseModel> forMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return expenses
        .where((e) => !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();
  }

  /// Total spend for a given month.
  double totalForMonth(DateTime month) {
    return forMonth(month).fold(0.0, (acc, e) => acc + e.amount);
  }
}

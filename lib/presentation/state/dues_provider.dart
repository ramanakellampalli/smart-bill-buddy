import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/due_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/dues_repository.dart';
import '../../data/repositories/expenses_repository.dart';
import '../../services/notification_service.dart';

class DuesProvider extends ChangeNotifier {
  final DuesRepository _repo;
  final ExpensesRepository _expensesRepo;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<DueModel>>? _duesSub;

  List<DueModel> dues = [];
  bool saving = false;
  bool isLoading = true;
  String? error;

  String? _currentUid;

  DuesProvider(this._repo, this._expensesRepo) {
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
      final due = dues.firstWhere((d) => d.id == dueId);
      await _repo.settleDue(dueId);
      await NotificationService.cancelDue(dueId);
      if (due.type == 'borrowed' && _currentUid != null) {
        final totalPaid = due.payments.fold(0.0, (s, p) => s + p.amount);
        final remaining = due.amount - totalPaid;
        if (remaining > 0) {
          final expense = ExpenseModel.create(
            amount: remaining,
            category: ExpenseCategory.finance,
            description: 'Paid to ${due.personName}',
            date: DateTime.now(),
            linkedDueId: dueId,
          );
          await _expensesRepo.addExpense(expense);
        }
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> delete(String dueId) async {
    try {
      await NotificationService.cancelDue(dueId);
      await _repo.deleteDue(dueId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// Adds a partial payment to a due.
  /// Returns true if the payment fully covered the due (auto-settled).
  Future<bool> addPayment(String dueId, PaymentEntry payment) async {
    saving = true;
    error = null;
    notifyListeners();
    bool autoSettled = false;
    try {
      final due = dues.firstWhere((d) => d.id == dueId);
      final updatedPayments = [...due.payments, payment];
      final totalPaid = updatedPayments.fold(0.0, (s, p) => s + p.amount);
      autoSettled = totalPaid >= due.amount;
      await _repo.addPayment(dueId, updatedPayments, autoSettle: autoSettled);
      if (autoSettled) {
        await NotificationService.cancelDue(dueId);
      }
      if (due.type == 'borrowed' && _currentUid != null) {
        final expense = ExpenseModel.create(
          amount: payment.amount,
          category: ExpenseCategory.finance,
          description: 'Paid to ${due.personName}',
          date: payment.paidAt,
          linkedDueId: dueId,
        );
        await _expensesRepo.addExpense(expense);
      }
    } catch (e) {
      error = e.toString();
      autoSettled = false;
    } finally {
      saving = false;
      notifyListeners();
    }
    return autoSettled;
  }

  Future<void> scheduleAllDueNotifications() async {
    for (final due in dues) {
      if (!due.isSettled) {
        try {
          await NotificationService.scheduleDue(due);
        } catch (e) {
          print('Error scheduling notification for due ${due.id}: $e');
        }
      }
    }
  }
}

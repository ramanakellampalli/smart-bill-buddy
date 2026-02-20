import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/models/bill_model.dart';
import '../../data/repositories/bills_repository.dart';
import '../../services/notification_service.dart';

class BillsProvider extends ChangeNotifier {
  final BillsRepository _repo;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<BillModel>>? _billsSub;

  List<BillModel> bills = [];
  bool saving = false;
  bool isLoading = true;
  String? error;

  String? _currentUid;

  BillsProvider(this._repo) {
    // Only re-subscribe when the uid actually changes.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (_currentUid == null) return; // already signed out, no-op
        _currentUid = null;
        _billsSub?.cancel();
        _billsSub = null;
        bills = [];
        isLoading = false;
        notifyListeners();
      } else if (user.uid != _currentUid) {
        _currentUid = user.uid;
        _billsSub?.cancel();
        _billsSub = null;
        isLoading = true;
        notifyListeners();
        _billsSub = _repo.watchBills(user.uid).listen(
          (items) {
            bills = items;
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
    _billsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> add(BillModel bill) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.addBill(bill);
      await NotificationService.scheduleBill(bill);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> update(BillModel bill) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.updateBill(bill);
      await NotificationService.scheduleBill(bill);
    } catch (e) {
      error = e.toString();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> setPaid(String billId, bool isPaid) async {
    try {
      await _repo.markPaid(billId: billId, isPaid: isPaid);
      if (isPaid) {
        await NotificationService.cancelBill(billId);
      } else {
        final bill = bills.firstWhere((b) => b.id == billId);
        await NotificationService.scheduleBill(bill.copyWith(isPaid: false));
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> remove(String billId) async {
    try {
      await _repo.deleteBill(billId);
      await NotificationService.cancelBill(billId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}

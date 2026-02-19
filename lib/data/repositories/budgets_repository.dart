import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_model.dart';

class BudgetsRepository {
  final FirebaseFirestore _db;
  BudgetsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('User not signed in');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('budgets');

  Stream<List<BudgetModel>> watchBudgets(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .snapshots()
        .map((s) => s.docs.map((d) => BudgetModel.fromMap(d.data())).toList());
  }

  Future<void> setBudget(BudgetModel budget) async {
    await _col
        .doc(budget.id)
        .set(budget.toMap())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> deleteBudget(String budgetId) async {
    await _col.doc(budgetId).delete();
  }
}

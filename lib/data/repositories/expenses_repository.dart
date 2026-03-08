import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_model.dart';

class ExpensesRepository {
  final FirebaseFirestore _db;
  ExpensesRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('User not signed in.');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('expenses');

  Stream<List<ExpenseModel>> watchExpenses(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ExpenseModel.fromMap(d.data())).toList());
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _col.doc(expense.id).set(expense.toMap());
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _col.doc(expense.id).set(expense.toMap());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _col.doc(expenseId).delete();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/due_model.dart';

class DuesRepository {
  final FirebaseFirestore _db;
  DuesRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('User not signed in.');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _duesCol =>
      _db.collection('users').doc(_uid).collection('dues');

  Stream<List<DueModel>> watchDues(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('dues')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => DueModel.fromMap(d.data())).toList());
  }

  Future<void> addDue(DueModel due) async {
    await _duesCol
        .doc(due.id)
        .set(due.toMap())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> updateDue(DueModel due) async {
    await _duesCol
        .doc(due.id)
        .set(due.toMap())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> settleDue(String dueId) async {
    await _duesCol.doc(dueId).update({
      'isSettled': true,
      'settledAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDue(String dueId) async {
    await _duesCol.doc(dueId).delete();
  }

  /// Adds a payment entry to a due. Pass autoSettle=true to also mark settled.
  Future<void> addPayment(
    String dueId,
    List<PaymentEntry> updatedPayments, {
    bool autoSettle = false,
  }) async {
    final data = <String, dynamic>{
      'payments': updatedPayments.map((p) => p.toMap()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (autoSettle) {
      data['isSettled'] = true;
      data['settledAt'] = DateTime.now().toIso8601String();
    }
    await _duesCol.doc(dueId).update(data);
  }
}

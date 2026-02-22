import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';

// ── Recurrence helpers ────────────────────────────────────────────────────────

/// Advance [from] by one billing cycle, clamping the day to the last valid
/// day of the target month (e.g. Jan 31 + 1 month → Feb 28/29, not Mar 2).
DateTime _nextDueDate(DateTime from, String frequency) {
  int y = from.year, m = from.month, d = from.day;
  switch (frequency) {
    case 'quarterly':
      m += 3;
    case 'yearly':
      y += 1;
    default: // monthly
      m += 1;
  }
  // Dart carries over months > 12 automatically (e.g. month 13 → Jan next year).
  // Clamp day to the last day of the target month.
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.clamp(1, lastDay));
}

/// Keep advancing [date] until it reaches [startOfThisMonth] or later.
DateTime _advanceToCurrent(DateTime date, String frequency, DateTime startOfThisMonth) {
  var d = date;
  while (d.isBefore(startOfThisMonth)) {
    d = _nextDueDate(d, frequency);
  }
  return d;
}

class BillsRepository {
  final FirebaseFirestore _db;
  BillsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('User not signed in. Ensure AuthBootstrap.ensureSignedIn() was called.');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _billsCol =>
      _db.collection('users').doc(_uid).collection('bills');

  Stream<List<BillModel>> watchBills(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('bills')
        .orderBy('dueDate')
        .snapshots()
        .map((s) => s.docs
            .map((d) => BillModel.fromMap(d.data()))
            .toList());
  }

  Future<void> addBill(BillModel bill) async {
    await _billsCol
        .doc(bill.id)
        .set(bill.toMap())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> updateBill(BillModel bill) async {
    await _billsCol
        .doc(bill.id)
        .set(bill.toMap())
        .timeout(const Duration(seconds: 10));
  }

  Future<void> markPaid({required String billId, required bool isPaid}) async {
    await _billsCol.doc(billId).update({
      'isPaid': isPaid,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteBill(String billId) async {
    await _billsCol.doc(billId).delete();
  }

  /// Roll over any paid bills whose due date fell in a past month.
  /// Each bill is a single Firestore record — its dueDate is advanced
  /// to the next applicable cycle and isPaid is reset to false.
  Future<void> rolloverBills() async {
    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1);

    final snapshot = await _billsCol.get();
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    var count = 0;

    for (final doc in snapshot.docs) {
      final bill = BillModel.fromMap(doc.data());

      // Only touch paid bills from a previous month.
      if (!bill.isPaid) continue;
      if (!bill.dueDate.isBefore(startOfThisMonth)) continue;

      final nextDate = _advanceToCurrent(bill.dueDate, bill.frequency, startOfThisMonth);

      batch.update(doc.reference, {
        'dueDate': nextDate.toIso8601String(),
        'isPaid': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      count++;
    }

    if (count > 0) await batch.commit();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill_model.dart';

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

  Future<void> markPaid({required String billId, required bool isPaid}) async {
    await _billsCol.doc(billId).update({
      'isPaid': isPaid,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteBill(String billId) async {
    await _billsCol.doc(billId).delete();
  }
}

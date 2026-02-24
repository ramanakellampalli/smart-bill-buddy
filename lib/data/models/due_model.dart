// ── Payment Entry ──────────────────────────────────────────────────────────────

class PaymentEntry {
  final String id;
  final double amount;
  final String? method; // 'cash' | 'upi' | 'bank_transfer' | 'other'
  final String? note;
  final DateTime paidAt;

  PaymentEntry({
    required this.id,
    required this.amount,
    this.method,
    this.note,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'method': method,
        'note': note,
        'paidAt': paidAt.toIso8601String(),
      };

  factory PaymentEntry.fromMap(Map<String, dynamic> map) => PaymentEntry(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        method: map['method'] as String?,
        note: map['note'] as String?,
        paidAt: DateTime.parse(map['paidAt'] as String),
      );
}

// ── Due Model ──────────────────────────────────────────────────────────────────

class DueModel {
  final String id;
  final String personName;
  final double amount;       // original full amount
  final String type;         // 'lent' | 'borrowed'
  final String? description;
  final DateTime date;
  final DateTime? dueDate;
  final bool isSettled;
  final DateTime? settledAt;
  final DateTime createdAt;
  final List<PaymentEntry> payments;

  DueModel({
    required this.id,
    required this.personName,
    required this.amount,
    required this.type,
    this.description,
    required this.date,
    this.dueDate,
    this.isSettled = false,
    this.settledAt,
    DateTime? createdAt,
    this.payments = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Computed ─────────────────────────────────────────────────────────────────

  double get paidAmount => payments.fold(0.0, (s, p) => s + p.amount);
  double get remaining => (amount - paidAmount).clamp(0.0, double.infinity);
  bool get isPartiallyPaid => paidAmount > 0 && !isSettled;

  // ── copyWith ──────────────────────────────────────────────────────────────────

  DueModel copyWith({
    String? id,
    String? personName,
    double? amount,
    String? type,
    String? description,
    bool clearDescription = false,
    DateTime? date,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isSettled,
    DateTime? settledAt,
    bool clearSettledAt = false,
    DateTime? createdAt,
    List<PaymentEntry>? payments,
  }) {
    return DueModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: clearDescription ? null : (description ?? this.description),
      date: date ?? this.date,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isSettled: isSettled ?? this.isSettled,
      settledAt: clearSettledAt ? null : (settledAt ?? this.settledAt),
      createdAt: createdAt ?? this.createdAt,
      payments: payments ?? this.payments,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isSettled': isSettled,
      'settledAt': settledAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'payments': payments.map((p) => p.toMap()).toList(),
    };
  }

  factory DueModel.fromMap(Map<String, dynamic> map) {
    return DueModel(
      id: map['id'] as String,
      personName: map['personName'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      isSettled: map['isSettled'] as bool? ?? false,
      settledAt: map['settledAt'] != null
          ? DateTime.parse(map['settledAt'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      payments: (map['payments'] as List<dynamic>?)
              ?.map((e) => PaymentEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

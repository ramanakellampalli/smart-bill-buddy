class DueModel {
  final String id;
  final String personName;
  final double amount;       // always set — dues require an amount
  final String type;         // 'lent' | 'borrowed'
  final String? description;
  final DateTime date;
  final DateTime? dueDate;
  final bool isSettled;
  final DateTime? settledAt;
  final DateTime createdAt;

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
  }) : createdAt = createdAt ?? DateTime.now();

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
    );
  }

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
    );
  }
}

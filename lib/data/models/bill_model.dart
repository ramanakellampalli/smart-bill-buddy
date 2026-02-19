class BillModel {
  final String id;
  final String name;
  final double? amount;
  final DateTime dueDate;
  final String frequency; // monthly/quarterly/yearly
  final String category;  // utilities/rent/emi/subscription/etc
  final bool isPaid;
  final DateTime createdAt;

  // reminder settings
  final bool remind5Days;
  final bool remind2Days;
  final bool remindDueDay;

  BillModel({
    required this.id,
    required this.name,
    this.amount,
    required this.dueDate,
    required this.frequency,
    required this.category,
    required this.isPaid,
    required this.remind5Days,
    required this.remind2Days,
    required this.remindDueDay,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  BillModel copyWith({
    String? id,
    String? name,
    double? amount,
    bool clearAmount = false,
    DateTime? dueDate,
    String? frequency,
    String? category,
    bool? isPaid,
    bool? remind5Days,
    bool? remind2Days,
    bool? remindDueDay,
    DateTime? createdAt,
  }) {
    return BillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: clearAmount ? null : (amount ?? this.amount),
      dueDate: dueDate ?? this.dueDate,
      frequency: frequency ?? this.frequency,
      category: category ?? this.category,
      isPaid: isPaid ?? this.isPaid,
      remind5Days: remind5Days ?? this.remind5Days,
      remind2Days: remind2Days ?? this.remind2Days,
      remindDueDay: remindDueDay ?? this.remindDueDay,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'frequency': frequency,
      'category': category,
      'isPaid': isPaid,
      'remind5Days': remind5Days,
      'remind2Days': remind2Days,
      'remindDueDay': remindDueDay,
      'createdAt': createdAt.toIso8601String(), // preserved, not overwritten
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] == null) ? null : (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate'] as String),
      frequency: map['frequency'] as String,
      category: map['category'] as String,
      isPaid: map['isPaid'] as bool? ?? false,
      remind5Days: map['remind5Days'] as bool? ?? true,
      remind2Days: map['remind2Days'] as bool? ?? true,
      remindDueDay: map['remindDueDay'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null, // falls back to DateTime.now() in constructor
    );
  }
}

class BillModel {
  final String id;
  final String name;
  final double? amount;
  final DateTime dueDate;
  final String frequency; // monthly/quarterly/yearly
  final String category;  // utilities/rent/emi/subscription/etc
  final bool isPaid;

  // simple reminder settings for MVP
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
  });

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
      'updatedAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
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
    );
  }
}

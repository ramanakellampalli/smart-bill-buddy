import 'package:uuid/uuid.dart';

/// Expense categories — 8 universal categories covering ~95% of daily spending.
enum ExpenseCategory {
  food,
  transport,
  housing,
  shopping,
  health,
  entertainment,
  finance,
  other;

  String get value => name;

  String get label => switch (this) {
        ExpenseCategory.food => 'Food',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.housing => 'Housing',
        ExpenseCategory.shopping => 'Shopping',
        ExpenseCategory.health => 'Health',
        ExpenseCategory.entertainment => 'Entertainment',
        ExpenseCategory.finance => 'Finance',
        ExpenseCategory.other => 'Other',
      };

  static ExpenseCategory fromValue(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class ExpenseModel {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  /// Reserved for future: link this expense to a settled due.
  final String? linkedDueId;

  const ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    this.description,
    required this.date,
    required this.createdAt,
    this.linkedDueId,
  });

  factory ExpenseModel.create({
    required double amount,
    required ExpenseCategory category,
    String? description,
    required DateTime date,
    String? linkedDueId,
  }) {
    final now = DateTime.now();
    return ExpenseModel(
      id: const Uuid().v4(),
      amount: amount,
      category: category,
      description: description,
      date: date,
      createdAt: now,
      linkedDueId: linkedDueId,
    );
  }

  ExpenseModel copyWith({
    double? amount,
    ExpenseCategory? category,
    String? description,
    DateTime? date,
    String? linkedDueId,
  }) {
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt,
      linkedDueId: linkedDueId ?? this.linkedDueId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'category': category.value,
        'description': description,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'linkedDueId': linkedDueId,
      };

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: ExpenseCategory.fromValue(map['category'] as String),
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      linkedDueId: map['linkedDueId'] as String?,
    );
  }
}

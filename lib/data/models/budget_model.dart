import 'package:uuid/uuid.dart';

class BudgetModel {
  final String id;
  final String category;
  final double limit;

  const BudgetModel({
    required this.id,
    required this.category,
    required this.limit,
  });

  factory BudgetModel.create({
    required String category,
    required double limit,
  }) {
    return BudgetModel(
      id: const Uuid().v4(),
      category: category,
      limit: limit,
    );
  }

  BudgetModel copyWith({String? category, double? limit}) {
    return BudgetModel(
      id: id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'limit': limit,
      };

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      category: map['category'] as String,
      limit: (map['limit'] as num).toDouble(),
    );
  }
}

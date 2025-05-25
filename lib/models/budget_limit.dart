class BudgetLimit {
  final String? id;
  final String period;
  final double limit;
  final DateTime createdAt;

  BudgetLimit({
    this.id,
    required this.period,
    required this.limit,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'limit': limit,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BudgetLimit.fromMap(String id, Map<String, dynamic> map) {
    return BudgetLimit(
      id: id,
      period: map['period'] as String,
      limit: map['limit'] as double,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
} 
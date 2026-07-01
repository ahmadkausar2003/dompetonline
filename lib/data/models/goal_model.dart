class GoalModel {
  final int? id;
  final String title;
  final double targetAmount;
  final double savedAmount;

  const GoalModel({
    this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
  });

  GoalModel copyWith({int? id, String? title, double? targetAmount, double? savedAmount}) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
  };

  factory GoalModel.fromMap(Map<String, dynamic> map) => GoalModel(
    id: map['id'] as int?,
    title: map['title'] as String,
    targetAmount: map['targetAmount'] as double,
    savedAmount: map['savedAmount'] as double,
  );
}

class GoalLogModel {
  final int? id;
  final int goalId;
  final double amount;
  final String type; // 'in' (Masuk) atau 'out' (Keluar)
  final String note; // Detail dari mana sumber dananya
  final DateTime date;

  const GoalLogModel({
    this.id,
    required this.goalId,
    required this.amount,
    required this.type,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'goalId': goalId,
    'amount': amount,
    'type': type,
    'note': note,
    'date': date.toIso8601String(),
  };

  factory GoalLogModel.fromMap(Map<String, dynamic> map) => GoalLogModel(
    id: map['id'] as int?,
    goalId: map['goalId'] as int,
    amount: map['amount'] as double,
    type: map['type'] as String,
    note: map['note'] as String,
    date: DateTime.parse(map['date'] as String),
  );
}
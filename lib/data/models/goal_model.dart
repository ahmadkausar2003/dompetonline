class GoalModel {
  final String? id; // DIUBAH: Menjadi String
  final String uid; // BARU: ID Pemilik Target
  final String title;
  final double targetAmount;
  final double savedAmount;

  const GoalModel({
    this.id,
    required this.uid,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
  });

  GoalModel copyWith({
    String? id, 
    String? uid, 
    String? title, 
    double? targetAmount, 
    double? savedAmount
  }) {
    return GoalModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'title': title,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
      };

  factory GoalModel.fromMap(Map<String, dynamic> map, String documentId) => GoalModel(
        id: documentId,
        uid: map['uid'] as String? ?? '',
        title: map['title'] as String,
        targetAmount: map['targetAmount'] as double,
        savedAmount: map['savedAmount'] as double,
      );
}

class GoalLogModel {
  final String? id; // DIUBAH: Menjadi String
  final String goalId; // DIUBAH: Menjadi String agar cocok dengan ID GoalModel
  final String uid; // BARU: ID Pemilik Log
  final double amount;
  final String type; // 'in' (Masuk) atau 'out' (Keluar)
  final String note; // Detail dari mana sumber dananya
  final DateTime date;

  const GoalLogModel({
    this.id,
    required this.goalId,
    required this.uid,
    required this.amount,
    required this.type,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'goalId': goalId,
        'uid': uid,
        'amount': amount,
        'type': type,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory GoalLogModel.fromMap(Map<String, dynamic> map, String documentId) => GoalLogModel(
        id: documentId,
        goalId: map['goalId'] as String,
        uid: map['uid'] as String? ?? '',
        amount: map['amount'] as double,
        type: map['type'] as String,
        note: map['note'] as String,
        date: DateTime.parse(map['date'] as String),
      );
}
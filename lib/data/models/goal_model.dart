class GoalModel {
	final String? id; 
	final String uid; 
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
		// PERBAIKAN BUG SILUMAN FIREBASE DI SINI 👇
		targetAmount: (map['targetAmount'] as num).toDouble(),
		savedAmount: (map['savedAmount'] as num).toDouble(),
	);
}

class GoalLogModel {
	final String? id; 
	final String goalId; 
	final String uid; 
	final double amount;
	final String type; 
	final String note; 
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
		// PERBAIKAN BUG SILUMAN FIREBASE DI SINI 👇
		amount: (map['amount'] as num).toDouble(),
		type: map['type'] as String,
		note: map['note'] as String,
		date: DateTime.parse(map['date'] as String),
	);
}
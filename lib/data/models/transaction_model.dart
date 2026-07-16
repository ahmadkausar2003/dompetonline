class TransactionModel {
	final String? id; 
	final String uid; 
	final String title;
	final double amount;
	final String type; 
	final String category;
	final DateTime date;
	final String? note;
	final String? imagePath; 
	final String? location;  
	
	const TransactionModel({
		this.id,
		required this.uid, 
		required this.title,
		required this.amount,
		required this.type,
		required this.category,
		required this.date,
		this.note,
		this.imagePath,
		this.location,
	});
	
	TransactionModel copyWith({
		String? id,
		String? uid,
		String? title,
		double? amount,
		String? type,
		String? category,
		DateTime? date,
		String? note,
		String? imagePath,
		String? location,
	}) {
		return TransactionModel(
			id: id ?? this.id,
			uid: uid ?? this.uid,
			title: title ?? this.title,
			amount: amount ?? this.amount,
			type: type ?? this.type,
			category: category ?? this.category,
			date: date ?? this.date,
			note: note ?? this.note,
			imagePath: imagePath ?? this.imagePath,
			location: location ?? this.location,
		);
	}
	
	Map<String, dynamic> toMap() {
		return {
			'uid': uid,
			'title': title,
			'amount': amount,
			'type': type,
			'category': category,
			'date': date.toIso8601String(),
			'note': note,
			'imagePath': imagePath,
			'location': location,
		};
	}
	
	factory TransactionModel.fromMap(Map<String, dynamic> map, String documentId) {
		return TransactionModel(
			id: documentId, 
			uid: map['uid'] as String? ?? '',
			title: map['title'] as String,
			// PERBAIKAN BUG SILUMAN FIREBASE DI SINI 👇
			amount: (map['amount'] as num).toDouble(),
			type: map['type'] as String,
			category: map['category'] as String,
			date: DateTime.parse(map['date'] as String),
			note: map['note'] != null ? map['note'] as String : null,
			imagePath: map['imagePath'] != null ? map['imagePath'] as String : null,
			location: map['location'] != null ? map['location'] as String : null,
		);
	}
	
	@override
	String toString() {
		return 'TransactionModel(id: $id, uid: $uid, title: $title, amount: $amount, type: $type, category: $category, date: $date, note: $note, imagePath: $imagePath, location: $location)';
	}
}
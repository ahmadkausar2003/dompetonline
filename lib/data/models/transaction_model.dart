class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'income' atau 'expense'
  final String category;
  final DateTime date;
  final String? note;
  final String? imagePath; // Path lokal gambar struk dari kamera/galeri
  final String? location;  // Lokasi transaksi

  const TransactionModel({
    this.id,
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
    int? id,
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
      'id': id,
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

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] != null ? map['id'] as int : null,
      title: map['title'] as String,
      amount: map['amount'] as double,
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
    return 'TransactionModel(id: $id, title: $title, amount: $amount, type: $type, category: $category, date: $date, note: $note, imagePath: $imagePath, location: $location)';
  }
}
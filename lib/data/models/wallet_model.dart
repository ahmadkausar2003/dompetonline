class WalletModel {
  final String? id;
  final String uid; // KTP Pemilik
  final String name; // Nama: Uang Cash, Rekening Utama, DANA, GoPay, dll.
  final String type; // Tipe: 'bank', 'cash', 'ewallet'
  final String? accountNumber; // Nomor Rekening/HP (Bisa disalin nantinya)
  final double balance; // Saldo spesifik di dompet ini
  final bool isDefault; // Apakah dompet bawaan sistem (tidak bisa dihapus)

  const WalletModel({
    this.id,
    required this.uid,
    required this.name,
    required this.type,
    this.accountNumber,
    this.balance = 0.0,
    this.isDefault = false,
  });

  WalletModel copyWith({
    String? id,
    String? uid,
    String? name,
    String? type,
    String? accountNumber,
    double? balance,
    bool? isDefault,
  }) {
    return WalletModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      type: type ?? this.type,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'type': type,
      'accountNumber': accountNumber,
      'balance': balance,
      'isDefault': isDefault,
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WalletModel(
      id: documentId,
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String,
      type: map['type'] as String,
      accountNumber: map['accountNumber'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}
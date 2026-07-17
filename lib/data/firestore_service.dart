import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models/transaction_model.dart';
import 'models/goal_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // --- TRANSAKSI ---
  // REVISI: Menggunakan "Mode Detektif" dengan print debug untuk melacak UID dan data Firebase
  Stream<List<TransactionModel>> getTransactionsStream({String? uid}) {
    if (kDebugMode) {
      print("DEBUG: Mencari data untuk UID: $uid");
    } // Kita akan lihat ini di terminal
    Query query = _db.collection('transactions');
    
    if (uid != null) {
      query = query.where('uid', isEqualTo: uid);
    }
    
    return query.snapshots().map((snapshot) {
      if (kDebugMode) {
        print("DEBUG: Jumlah data ditemukan: ${snapshot.docs.length}");
      } // Lihat apakah Firebase mengirim data
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Lakukan pengurutan (Sorting) tanggal secara manual di memori HP (Dart)
      list.sort((a, b) => b.date.compareTo(a.date));
      
      return list;
    });
  }
  
  Future<void> addTransaction(TransactionModel transaction) async {
    await _db.collection('transactions').add(transaction.toMap());
  }
  
  Future<void> updateTransaction(TransactionModel transaction) async {
    await _db.collection('transactions').doc(transaction.id).update(transaction.toMap());
  }
  
  Future<void> deleteTransaction(String id) async {
    await _db.collection('transactions').doc(id).delete();
  }
  
  // --- TARGET TABUNGAN ---
  Stream<List<GoalModel>> getGoalsStream({String? uid}) {
    Query query = _db.collection('goals');
    if (uid != null) {
      query = query.where('uid', isEqualTo: uid);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => GoalModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }
  
  Future<void> addGoal(GoalModel goal) async {
    await _db.collection('goals').add(goal.toMap());
  }
  
  Future<void> updateGoal(GoalModel goal) async {
    await _db.collection('goals').doc(goal.id).update(goal.toMap());
  }
  
  Future<void> deleteGoal(String id) async {
    await _db.collection('goals').doc(id).delete();
  }
}

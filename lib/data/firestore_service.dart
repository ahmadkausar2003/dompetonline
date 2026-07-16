import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/transaction_model.dart';
import 'models/goal_model.dart';

class FirestoreService {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	
	// --- TRANSAKSI ---
	Stream<List<TransactionModel>> getTransactionsStream({String? uid}) {
		Query query = _db.collection('transactions').orderBy('date', descending: true);
		if (uid != null) {
			query = query.where('uid', isEqualTo: uid);
		}
		return query.snapshots().map((snapshot) => snapshot.docs
				.map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
				.toList());
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
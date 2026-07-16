import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/firestore_service.dart';
import 'transaction_provider.dart';

class GoalState {
  final List<GoalModel> goals;
  final bool isLoading;
  
  const GoalState({this.goals = const [], this.isLoading = false});
  
  GoalState copyWith({List<GoalModel>? goals, bool? isLoading}) {
    return GoalState(
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GoalNotifier extends Notifier<GoalState> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _goalSubscription;
  
  @override
  GoalState build() {
    _initCloudStream();
    return const GoalState();
  }
  
  void _initCloudStream() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? 'student';
    final user = FirebaseAuth.instance.currentUser;
    
    final uidFilter = (role == 'admin') ? null : user?.uid;

    _goalSubscription?.cancel();
    _goalSubscription = _firestoreService.getGoalsStream(uid: uidFilter).listen((goals) {
      state = state.copyWith(goals: goals, isLoading: false);
    });
  }

  void refD() {
    _goalSubscription?.cancel();
  }
  
  Future<void> addGoal(GoalModel goal) async {
    final user = FirebaseAuth.instance.currentUser;
    final goalWithUid = goal.copyWith(uid: user?.uid ?? 'unknown');
    await _firestoreService.addGoal(goalWithUid);
  }
  
  // DIUBAH: parameter ID dari int menjadi String
  Future<void> updateGoalAmount(String goalId, double newSavedAmount, {String? type, String? note}) async {
    final goalIndex = state.goals.indexWhere((g) => g.id == goalId);
    if (goalIndex != -1) {
      final goal = state.goals[goalIndex];
      final difference = (newSavedAmount - goal.savedAmount).abs(); 
      
      final updatedGoal = goal.copyWith(savedAmount: newSavedAmount);
      await _firestoreService.updateGoal(updatedGoal);
      
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'unknown';

      // --- SINKRONISASI KATEGORI KHUSUS KE TRANSAKSI ---
      if (type == 'in') {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            uid: uid,
            title: 'Nabung: ${goal.title}',
            amount: difference,
            type: 'expense',
            category: 'Tabungan',
            date: DateTime.now(),
          )
        );
      } else if (type == 'out_refund') {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            uid: uid,
            title: 'Pencairan: ${goal.title}',
            amount: difference,
            type: 'income',
            category: 'Tabungan',
            date: DateTime.now(),
          )
        );
      } else if (type == 'out_expense') {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            uid: uid,
            title: 'Pencairan Darurat (Sistem)',
            amount: difference,
            type: 'income',
            category: 'Tabungan',
            date: DateTime.now(),
          )
        );
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            uid: uid,
            title: '🚨 Darurat: $note',
            amount: difference,
            type: 'expense',
            category: 'Darurat',
            date: DateTime.now().add(const Duration(seconds: 1)),
          )
        );
      }
    }
  }
  
  // DIUBAH: parameter ID dari int menjadi String
  Future<void> deleteGoal(String id) async {
    final goalIndex = state.goals.indexWhere((g) => g.id == id);
    if (goalIndex != -1) {
      final goal = state.goals[goalIndex];
      if (goal.savedAmount > 0) {
        final user = FirebaseAuth.instance.currentUser;
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            uid: user?.uid ?? 'unknown',
            title: 'Batal Target: ${goal.title}',
            amount: goal.savedAmount,
            type: 'income',
            category: 'Tabungan',
            date: DateTime.now(),
          )
        );
      }
    }
    
    await _firestoreService.deleteGoal(id);
  }

  Future<void> loadGoals() async {}
}

final goalProvider = NotifierProvider<GoalNotifier, GoalState>(() => GoalNotifier());
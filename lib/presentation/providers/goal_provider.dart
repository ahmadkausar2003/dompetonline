import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/transaction_model.dart';
import '../../core/database/db_helper.dart';
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
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  GoalState build() {
    Future.microtask(() => loadGoals());
    return const GoalState();
  }

  Future<void> loadGoals() async {
    state = state.copyWith(isLoading: true);
    final goals = await _dbHelper.getAllGoals();
    state = state.copyWith(goals: goals, isLoading: false);
  }

  Future<void> addGoal(GoalModel goal) async {
    await _dbHelper.insertGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoalAmount(int goalId, double newSavedAmount, {String? type, String? note}) async {
    final goalIndex = state.goals.indexWhere((g) => g.id == goalId);
    if (goalIndex != -1) {
      final goal = state.goals[goalIndex];
      final difference = (newSavedAmount - goal.savedAmount).abs(); 

      final updatedGoal = goal.copyWith(savedAmount: newSavedAmount);
      await _dbHelper.updateGoal(updatedGoal);

      // --- SINKRONISASI KATEGORI KHUSUS KE TRANSAKSI ---
      if (type == 'in') {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: 'Nabung: ${goal.title}',
            amount: difference,
            type: 'expense',
            category: 'Tabungan', // Kategori Khusus
            date: DateTime.now(),
          )
        );
      } else if (type == 'out_refund') {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
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
            title: 'Pencairan Darurat (Sistem)',
            amount: difference,
            type: 'income',
            category: 'Tabungan',
            date: DateTime.now(),
          )
        );
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: '🚨 Darurat: $note',
            amount: difference,
            type: 'expense',
            category: 'Darurat', // Kategori Khusus Darurat
            date: DateTime.now().add(const Duration(seconds: 1)),
          )
        );
      }
    }
    
    await loadGoals();
  }

  Future<void> deleteGoal(int id) async {
    final goalIndex = state.goals.indexWhere((g) => g.id == id);
    if (goalIndex != -1) {
      final goal = state.goals[goalIndex];
      if (goal.savedAmount > 0) {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: 'Batal Target: ${goal.title}',
            amount: goal.savedAmount,
            type: 'income',
            category: 'Tabungan',
            date: DateTime.now(),
          )
        );
      }
    }

    await _dbHelper.deleteGoal(id);
    await loadGoals();
  }
}

final goalProvider = NotifierProvider<GoalNotifier, GoalState>(() => GoalNotifier());
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

      // --- SINKRONISASI CERDAS KE TRANSAKSI, REKAPAN, DAN STATISTIK ---
      if (type == 'in') {
        // ISI TABUNGAN: Uang keluar dari rekening, masuk ke celengan target
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: 'Nabung: ${goal.title}',
            amount: difference,
            type: 'expense',
            category: 'Lainnya',
            date: DateTime.now(),
          )
        );
      } else if (type == 'out_refund') {
        // CAIRKAN KE REKENING: Uang dari celengan kembali ke dompet utama
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: 'Pencairan: ${goal.title}',
            amount: difference,
            type: 'income',
            category: 'Lainnya',
            date: DateTime.now(),
          )
        );
      } else if (type == 'out_expense') {
        // PAKAI DARURAT: Sistem melakukan trik akuntansi otomatis. 
        // 1. Mencairkan uang sementara (Income)
        // 2. Langsung membelanjakannya untuk Darurat (Expense)
        // Hasil = Saldo Bank Tetap Aman, tetapi Rekapan & Statistik mencatat pengeluaran.
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: 'Pencairan Darurat (Sistem)',
            amount: difference,
            type: 'income',
            category: 'Lainnya',
            date: DateTime.now(),
          )
        );
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: '🚨 Darurat: $note',
            amount: difference,
            type: 'expense',
            category: 'Lainnya', 
            date: DateTime.now().add(const Duration(seconds: 1)), // Beda 1 detik agar rapi di daftar
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
      
      // Jika target dihapus dan uang masih ada, kembalikan uang ke Saldo Rekening
      if (goal.savedAmount > 0) {
        await ref.read(transactionProvider.notifier).addTransaction(
          TransactionModel(
            title: 'Batal Target: ${goal.title}',
            amount: goal.savedAmount,
            type: 'income',
            category: 'Lainnya',
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
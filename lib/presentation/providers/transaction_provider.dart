import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction_model.dart';
import '../../core/database/db_helper.dart';

class TransactionState {
  final List<TransactionModel> allTransactions;
  final List<TransactionModel> recentTransactions; // Untuk dashboard (7 hari terakhir)
  final double mainBalance; // Saldo Utama Sejati
  final double currentMonthIncome;
  final double currentMonthExpense;
  final bool isLoading;

  const TransactionState({
    this.allTransactions = const [],
    this.recentTransactions = const [],
    this.mainBalance = 0.0,
    this.currentMonthIncome = 0.0,
    this.currentMonthExpense = 0.0,
    this.isLoading = false,
  });

  TransactionState copyWith({
    List<TransactionModel>? allTransactions,
    List<TransactionModel>? recentTransactions,
    double? mainBalance,
    double? currentMonthIncome,
    double? currentMonthExpense,
    bool? isLoading,
  }) {
    return TransactionState(
      allTransactions: allTransactions ?? this.allTransactions,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      mainBalance: mainBalance ?? this.mainBalance,
      currentMonthIncome: currentMonthIncome ?? this.currentMonthIncome,
      currentMonthExpense: currentMonthExpense ?? this.currentMonthExpense,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TransactionNotifier extends Notifier<TransactionState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  TransactionState build() {
    Future.microtask(() => loadTransactions());
    return const TransactionState();
  }

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Ambil 7 hari terakhir untuk dashboard
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final results = await Future.wait([
        _dbHelper.getAllTransactions(), // 0. Semua data
        _dbHelper.getTransactionsByDateRange(sevenDaysAgo, now), // 1. Data 7 hari
        _dbHelper.getLifetimeIncome(), // 2. Total uang masuk selamanya
        _dbHelper.getLifetimeExpense(), // 3. Total uang keluar selamanya
        _dbHelper.getTotalIncome(startOfMonth, endOfMonth), // 4. Pemasukan bulan ini
        _dbHelper.getTotalExpense(startOfMonth, endOfMonth), // 5. Pengeluaran bulan ini
      ]);

      final allTransactions = results[0] as List<TransactionModel>;
      final recentTransactions = results[1] as List<TransactionModel>;
      final lifetimeIncome = results[2] as double;
      final lifetimeExpense = results[3] as double;
      final currentMonthIncome = results[4] as double;
      final currentMonthExpense = results[5] as double;

      // Perhitungan Saldo Utama Murni (Total Seluruh Pemasukan - Total Seluruh Pengeluaran)
      final mainBalance = lifetimeIncome - lifetimeExpense;

      state = state.copyWith(
        allTransactions: allTransactions,
        recentTransactions: recentTransactions,
        mainBalance: mainBalance,
        currentMonthIncome: currentMonthIncome,
        currentMonthExpense: currentMonthExpense,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('Error loading transactions: $e');
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true);
    await _dbHelper.insertTransaction(transaction);
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true);
    await _dbHelper.updateTransaction(transaction);
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    state = state.copyWith(isLoading: true);
    await _dbHelper.deleteTransaction(id);
    await loadTransactions();
  }

  Future<void> clearAllData() async {
    state = state.copyWith(isLoading: true);
    await _dbHelper.clearAllData();
    await loadTransactions();
  }
}

final transactionProvider = NotifierProvider<TransactionNotifier, TransactionState>(() {
  return TransactionNotifier();
});
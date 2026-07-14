import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/transaction_model.dart';
import '../../core/database/db_helper.dart';

class TransactionState {
  final List<TransactionModel> allTransactions;
  final List<TransactionModel> recentTransactions;
  final double mainBalance;   // Saldo Utama (Bank + Cash)
  final double bankBalance;   // Saldo Rekening
  final double cashBalance;   // Saldo Uang Cash
  final double currentMonthIncome;
  final double currentMonthExpense;
  final bool isLoading;
  
  // Fitur Hide Saldo Terpisah
  final bool isMainBalanceHidden; 
  final bool isBankBalanceHidden; 
  final bool isCashBalanceHidden; 
  
  // Kategori Custom & Hidden
  final List<String> customExpenseCategories;
  final List<String> customIncomeCategories;
  final List<String> hiddenExpenseCategories;
  final List<String> hiddenIncomeCategories;

  const TransactionState({
    this.allTransactions = const [],
    this.recentTransactions = const [],
    this.mainBalance = 0.0,
    this.bankBalance = 0.0,
    this.cashBalance = 0.0,
    this.currentMonthIncome = 0.0,
    this.currentMonthExpense = 0.0,
    this.isLoading = false,
    this.isMainBalanceHidden = false,
    this.isBankBalanceHidden = false,
    this.isCashBalanceHidden = false,
    this.customExpenseCategories = const [],
    this.customIncomeCategories = const [],
    this.hiddenExpenseCategories = const [],
    this.hiddenIncomeCategories = const [],
  });

  TransactionState copyWith({
    List<TransactionModel>? allTransactions,
    List<TransactionModel>? recentTransactions,
    double? mainBalance,
    double? bankBalance,
    double? cashBalance,
    double? currentMonthIncome,
    double? currentMonthExpense,
    bool? isLoading,
    bool? isMainBalanceHidden,
    bool? isBankBalanceHidden,
    bool? isCashBalanceHidden,
    List<String>? customExpenseCategories,
    List<String>? customIncomeCategories,
    List<String>? hiddenExpenseCategories,
    List<String>? hiddenIncomeCategories,
  }) {
    return TransactionState(
      allTransactions: allTransactions ?? this.allTransactions,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      mainBalance: mainBalance ?? this.mainBalance,
      bankBalance: bankBalance ?? this.bankBalance,
      cashBalance: cashBalance ?? this.cashBalance,
      currentMonthIncome: currentMonthIncome ?? this.currentMonthIncome,
      currentMonthExpense: currentMonthExpense ?? this.currentMonthExpense,
      isLoading: isLoading ?? this.isLoading,
      isMainBalanceHidden: isMainBalanceHidden ?? this.isMainBalanceHidden,
      isBankBalanceHidden: isBankBalanceHidden ?? this.isBankBalanceHidden,
      isCashBalanceHidden: isCashBalanceHidden ?? this.isCashBalanceHidden,
      customExpenseCategories: customExpenseCategories ?? this.customExpenseCategories,
      customIncomeCategories: customIncomeCategories ?? this.customIncomeCategories,
      hiddenExpenseCategories: hiddenExpenseCategories ?? this.hiddenExpenseCategories,
      hiddenIncomeCategories: hiddenIncomeCategories ?? this.hiddenIncomeCategories,
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
    final prefs = await SharedPreferences.getInstance();

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final results = await Future.wait([
        _dbHelper.getAllTransactions(),
        _dbHelper.getTransactionsByDateRange(sevenDaysAgo, now),
        _dbHelper.getTotalIncome(startOfMonth, endOfMonth),
        _dbHelper.getTotalExpense(startOfMonth, endOfMonth),
      ]);

      // Mengambil nilai mutlak dari SharedPreferences
      final double bankBal = prefs.getDouble('manual_bank_balance') ?? 0.0;
      final double cashBal = prefs.getDouble('manual_cash_balance') ?? 0.0;
      
      // Saldo Utama MURNI adalah gabungan Rekening + Uang Cash
      final double mainBal = bankBal + cashBal;

      final bool mainHidden = prefs.getBool('is_main_hidden') ?? false;
      final bool bankHidden = prefs.getBool('is_bank_hidden') ?? false;
      final bool cashHidden = prefs.getBool('is_cash_hidden') ?? false;

      final customExp = prefs.getStringList('custom_expense_cats') ?? [];
      final customInc = prefs.getStringList('custom_income_cats') ?? [];
      final hiddenExp = prefs.getStringList('hidden_expense_cats') ?? [];
      final hiddenInc = prefs.getStringList('hidden_income_cats') ?? [];

      state = state.copyWith(
        allTransactions: results[0] as List<TransactionModel>,
        recentTransactions: results[1] as List<TransactionModel>,
        mainBalance: mainBal,
        bankBalance: bankBal,
        cashBalance: cashBal,
        currentMonthIncome: results[2] as double,
        currentMonthExpense: results[3] as double,
        customExpenseCategories: customExp,
        customIncomeCategories: customInc,
        hiddenExpenseCategories: hiddenExp,
        hiddenIncomeCategories: hiddenInc,
        isMainBalanceHidden: mainHidden,
        isBankBalanceHidden: bankHidden,
        isCashBalanceHidden: cashHidden,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('Error loading transactions: $e');
    }
  }

  // --- FITUR HIDE SALDO TERPISAH ---
  Future<void> toggleMainBalanceHidden() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.isMainBalanceHidden;
    await prefs.setBool('is_main_hidden', newValue);
    state = state.copyWith(isMainBalanceHidden: newValue);
  }

  Future<void> toggleBankBalanceHidden() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.isBankBalanceHidden;
    await prefs.setBool('is_bank_hidden', newValue);
    state = state.copyWith(isBankBalanceHidden: newValue);
  }

  Future<void> toggleCashBalanceHidden() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.isCashBalanceHidden;
    await prefs.setBool('is_cash_hidden', newValue);
    state = state.copyWith(isCashBalanceHidden: newValue);
  }

  // --- EDIT SALDO REKENING MANUAL ---
  Future<void> updateBankBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_bank_balance', newBalance);
    
    // Saldo Utama otomatis menyesuaikan Rekening Baru + Cash Lama
    state = state.copyWith(
      bankBalance: newBalance,
      mainBalance: newBalance + state.cashBalance,
    );
  }

  // --- EDIT SALDO UANG CASH MANUAL ---
  Future<void> updateCashBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_cash_balance', newBalance);
    
    // Saldo Utama otomatis menyesuaikan Rekening Lama + Cash Baru
    state = state.copyWith(
      cashBalance: newBalance,
      mainBalance: state.bankBalance + newBalance,
    );
  }

  // --- MANAJEMEN KATEGORI ---
  Future<void> addCustomCategory(String categoryName, String type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'expense') {
      final newList = [...state.customExpenseCategories, categoryName];
      await prefs.setStringList('custom_expense_cats', newList);
      state = state.copyWith(customExpenseCategories: newList);
    } else {
      final newList = [...state.customIncomeCategories, categoryName];
      await prefs.setStringList('custom_income_cats', newList);
      state = state.copyWith(customIncomeCategories: newList);
    }
  }

  Future<void> removeCategory(String categoryName, String type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'expense') {
      if (state.customExpenseCategories.contains(categoryName)) {
        // Hapus dari custom
        final newList = List<String>.from(state.customExpenseCategories)..remove(categoryName);
        await prefs.setStringList('custom_expense_cats', newList);
        state = state.copyWith(customExpenseCategories: newList);
      } else {
        // Sembunyikan kategori bawaan
        final newList = [...state.hiddenExpenseCategories, categoryName];
        await prefs.setStringList('hidden_expense_cats', newList);
        state = state.copyWith(hiddenExpenseCategories: newList);
      }
    } else {
      if (state.customIncomeCategories.contains(categoryName)) {
        // Hapus dari custom
        final newList = List<String>.from(state.customIncomeCategories)..remove(categoryName);
        await prefs.setStringList('custom_income_cats', newList);
        state = state.copyWith(customIncomeCategories: newList);
      } else {
        // Sembunyikan kategori bawaan
        final newList = [...state.hiddenIncomeCategories, categoryName];
        await prefs.setStringList('hidden_income_cats', newList);
        state = state.copyWith(hiddenIncomeCategories: newList);
      }
    }
  }

  // --- LOGIKA TRANSAKSI DENGAN FITUR TARIK TUNAI ---
  Future<void> addTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true);
    await _dbHelper.insertTransaction(transaction);
    
    final prefs = await SharedPreferences.getInstance();
    double currentBank = prefs.getDouble('manual_bank_balance') ?? 0.0;
    double currentCash = prefs.getDouble('manual_cash_balance') ?? 0.0;

    // Logika Pintar: Jika Pengeluaran Kategori "Uang Cash" = Tarik Tunai
    if (transaction.type == 'expense' && transaction.category.toLowerCase() == 'uang cash') {
      currentBank -= transaction.amount; // Uang di rekening berkurang
      currentCash += transaction.amount; // Uang cash bertambah (Pindah dompet)
    } 
    // Transaksi normal
    else if (transaction.type == 'income') {
      currentBank += transaction.amount;
    } else {
      currentBank -= transaction.amount;
    }

    await prefs.setDouble('manual_bank_balance', currentBank);
    await prefs.setDouble('manual_cash_balance', currentCash);
    
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true);
    
    final oldTxIndex = state.allTransactions.indexWhere((t) => t.id == transaction.id);
    if (oldTxIndex != -1) {
      final oldTx = state.allTransactions[oldTxIndex];
      final prefs = await SharedPreferences.getInstance();
      double currentBank = prefs.getDouble('manual_bank_balance') ?? 0.0;
      double currentCash = prefs.getDouble('manual_cash_balance') ?? 0.0;

      // 1. REVERSE LOGIKA LAMA
      if (oldTx.type == 'expense' && oldTx.category.toLowerCase() == 'uang cash') {
        currentBank += oldTx.amount; 
        currentCash -= oldTx.amount;
      } else if (oldTx.type == 'income') {
        currentBank -= oldTx.amount;
      } else {
        currentBank += oldTx.amount;
      }

      // 2. APPLY LOGIKA BARU
      if (transaction.type == 'expense' && transaction.category.toLowerCase() == 'uang cash') {
        currentBank -= transaction.amount;
        currentCash += transaction.amount;
      } else if (transaction.type == 'income') {
        currentBank += transaction.amount;
      } else {
        currentBank -= transaction.amount;
      }

      await prefs.setDouble('manual_bank_balance', currentBank);
      await prefs.setDouble('manual_cash_balance', currentCash);
    }
    
    await _dbHelper.updateTransaction(transaction);
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    state = state.copyWith(isLoading: true);
    
    final txIndex = state.allTransactions.indexWhere((t) => t.id == id);
    if (txIndex != -1) {
      final tx = state.allTransactions[txIndex];
      final prefs = await SharedPreferences.getInstance();
      double currentBank = prefs.getDouble('manual_bank_balance') ?? 0.0;
      double currentCash = prefs.getDouble('manual_cash_balance') ?? 0.0;

      // REVERSE LOGIKA SAAT DIHAPUS
      if (tx.type == 'expense' && tx.category.toLowerCase() == 'uang cash') {
        currentBank += tx.amount; // Uang kembali ke rekening
        currentCash -= tx.amount; // Uang cash batal bertambah
      } else if (tx.type == 'income') {
        currentBank -= tx.amount;
      } else {
        currentBank += tx.amount;
      }

      await prefs.setDouble('manual_bank_balance', currentBank);
      await prefs.setDouble('manual_cash_balance', currentCash);
    }

    await _dbHelper.deleteTransaction(id);
    await loadTransactions();
  }

  Future<void> clearAllData() async {
    state = state.copyWith(isLoading: true);
    await _dbHelper.clearAllData();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_bank_balance', 0.0);
    await prefs.setDouble('manual_cash_balance', 0.0); 
    await prefs.remove('custom_expense_cats');
    await prefs.remove('custom_income_cats');
    await prefs.remove('hidden_expense_cats');
    await prefs.remove('hidden_income_cats');
    
    await loadTransactions();
  }
}

final transactionProvider = NotifierProvider<TransactionNotifier, TransactionState>(() {
  return TransactionNotifier();
});
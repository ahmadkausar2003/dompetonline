import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/transaction_model.dart';
import '../../data/firestore_service.dart'; 

class TransactionState {
  final List<TransactionModel> allTransactions;
  final List<TransactionModel> recentTransactions;
  final double mainBalance;   
  final double bankBalance;   
  final double cashBalance;   
  final double currentMonthIncome;
  final double currentMonthExpense;
  final bool isLoading;
  
  final bool isMainBalanceHidden; 
  final bool isBankBalanceHidden; 
  final bool isCashBalanceHidden; 
  
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
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _transactionSubscription;
  
  @override
  TransactionState build() {
    _initCloudStream();
    return const TransactionState();
  }
  
  // --- KONEKSI KE AWAN SECARA REAL-TIME ---
  void _initCloudStream() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    
    final user = FirebaseAuth.instance.currentUser;
    final role = prefs.getString('role') ?? 'student'; 
    
    final uidFilter = (role == 'admin') ? null : user?.uid;
    
    _transactionSubscription?.cancel();
    _transactionSubscription = _firestoreService.getTransactionsStream(uid: uidFilter).listen((transactions) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final recentTx = transactions.where((t) => t.date.isAfter(sevenDaysAgo)).toList();
      
      double currentInc = 0.0;
      double currentExp = 0.0;
      for (var tx in transactions) {
        if (tx.date.isAfter(startOfMonth)) {
          if (tx.type == 'income') currentInc += tx.amount;
          if (tx.type == 'expense') currentExp += tx.amount;
        }
      }
      
      final double bankBal = prefs.getDouble('manual_bank_balance') ?? 0.0;
      final double cashBal = prefs.getDouble('manual_cash_balance') ?? 0.0;
      final double mainBal = bankBal + cashBal;
      
      state = state.copyWith(
        allTransactions: transactions,
        recentTransactions: recentTx,
        mainBalance: mainBal,
        bankBalance: bankBal,
        cashBalance: cashBal,
        currentMonthIncome: currentInc,
        currentMonthExpense: currentExp,
        isMainBalanceHidden: prefs.getBool('is_main_hidden') ?? false,
        isBankBalanceHidden: prefs.getBool('is_bank_hidden') ?? false,
        isCashBalanceHidden: prefs.getBool('is_cash_hidden') ?? false,
        customExpenseCategories: prefs.getStringList('custom_expense_cats') ?? [],
        customIncomeCategories: prefs.getStringList('custom_income_cats') ?? [],
        hiddenExpenseCategories: prefs.getStringList('hidden_expense_cats') ?? [],
        hiddenIncomeCategories: prefs.getStringList('hidden_income_cats') ?? [],
        isLoading: false,
      );
    });
  }
  
  void refD() {
    _transactionSubscription?.cancel();
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
    state = state.copyWith(
      bankBalance: newBalance,
      mainBalance: newBalance + state.cashBalance,
    );
  }
  
  // --- EDIT SALDO UANG CASH MANUAL ---
  Future<void> updateCashBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_cash_balance', newBalance);
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
        final newList = List<String>.from(state.customExpenseCategories)..remove(categoryName);
        await prefs.setStringList('custom_expense_cats', newList);
        state = state.copyWith(customExpenseCategories: newList);
      } else {
        final newList = [...state.hiddenExpenseCategories, categoryName];
        await prefs.setStringList('hidden_expense_cats', newList);
        state = state.copyWith(hiddenExpenseCategories: newList);
      }
    } else {
      if (state.customIncomeCategories.contains(categoryName)) {
        final newList = List<String>.from(state.customIncomeCategories)..remove(categoryName);
        await prefs.setStringList('custom_income_cats', newList);
        state = state.copyWith(customIncomeCategories: newList);
      } else {
        final newList = [...state.hiddenIncomeCategories, categoryName];
        await prefs.setStringList('hidden_income_cats', newList);
        state = state.copyWith(hiddenIncomeCategories: newList);
      }
    }
  }
  
  // --- LOGIKA TRANSAKSI ---
  Future<void> addTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true);
    
    final user = FirebaseAuth.instance.currentUser;
    final txWithUid = transaction.copyWith(uid: user?.uid ?? 'unknown');
    
    await _firestoreService.addTransaction(txWithUid);
    
    final prefs = await SharedPreferences.getInstance();
    double currentBank = prefs.getDouble('manual_bank_balance') ?? 0.0;
    double currentCash = prefs.getDouble('manual_cash_balance') ?? 0.0;
    
    if (transaction.type == 'expense' && transaction.category.toLowerCase() == 'uang cash') {
      currentBank -= transaction.amount; 
      currentCash += transaction.amount; 
    } 
    else if (transaction.type == 'income') {
      currentBank += transaction.amount;
    } else {
      currentBank -= transaction.amount;
    }
    
    await prefs.setDouble('manual_bank_balance', currentBank);
    await prefs.setDouble('manual_cash_balance', currentCash);
  }
  
  Future<void> updateTransaction(TransactionModel transaction) async {
    state = state.copyWith(isLoading: true);
    
    final oldTxIndex = state.allTransactions.indexWhere((t) => t.id == transaction.id);
    if (oldTxIndex != -1) {
      final oldTx = state.allTransactions[oldTxIndex];
      final prefs = await SharedPreferences.getInstance();
      double currentBank = prefs.getDouble('manual_bank_balance') ?? 0.0;
      double currentCash = prefs.getDouble('manual_cash_balance') ?? 0.0;
      
      if (oldTx.type == 'expense' && oldTx.category.toLowerCase() == 'uang cash') {
        currentBank += oldTx.amount; 
        currentCash -= oldTx.amount;
      } else if (oldTx.type == 'income') {
        currentBank -= oldTx.amount;
      } else {
        currentBank += oldTx.amount;
      }
      
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
    
    await _firestoreService.updateTransaction(transaction);
  }
  
  Future<void> deleteTransaction(String id) async {
    state = state.copyWith(isLoading: true);
    
    final txIndex = state.allTransactions.indexWhere((t) => t.id == id);
    if (txIndex != -1) {
      final tx = state.allTransactions[txIndex];
      final prefs = await SharedPreferences.getInstance();
      double currentBank = prefs.getDouble('manual_bank_balance') ?? 0.0;
      double currentCash = prefs.getDouble('manual_cash_balance') ?? 0.0;
      
      if (tx.type == 'expense' && tx.category.toLowerCase() == 'uang cash') {
        currentBank += tx.amount; 
        currentCash -= tx.amount; 
      } else if (tx.type == 'income') {
        currentBank -= tx.amount;
      } else {
        currentBank += tx.amount;
      }
      
      await prefs.setDouble('manual_bank_balance', currentBank);
      await prefs.setDouble('manual_cash_balance', currentCash);
    }
    
    await _firestoreService.deleteTransaction(id);
  }
  
  Future<void> clearAllData() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manual_bank_balance', 0.0);
    await prefs.setDouble('manual_cash_balance', 0.0); 
    await prefs.remove('custom_expense_cats');
    await prefs.remove('custom_income_cats');
    await prefs.remove('hidden_expense_cats');
    await prefs.remove('hidden_income_cats');
  }

  Future<void> loadTransactions() async {}
}

final transactionProvider = NotifierProvider<TransactionNotifier, TransactionState>(() {
  return TransactionNotifier();
});
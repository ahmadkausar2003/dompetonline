import 'dart:async';
import 'package:flutter/foundation.dart'; // Tambahan untuk debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/transaction_model.dart';
import '../../data/firestore_service.dart';
import 'auth_provider.dart'; 

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
		final authState = ref.watch(authProvider);
		_transactionSubscription?.cancel();
		
		if (authState.user != null) {
			Future.microtask(() => _initCloudStream(authState.user!.uid, authState.role ?? 'student'));
		}
		
		return const TransactionState();
	}
	
	void _initCloudStream(String uid, String role) async {
		state = state.copyWith(isLoading: true);
		final prefs = await SharedPreferences.getInstance();
		
		final isMainHidden = prefs.getBool('is_main_hidden') ?? false;
		final isBankHidden = prefs.getBool('is_bank_hidden') ?? false;
		final isCashHidden = prefs.getBool('is_cash_hidden') ?? false;
		final cExp = prefs.getStringList('custom_expense_cats') ?? [];
		final cInc = prefs.getStringList('custom_income_cats') ?? [];
		
		final uidFilter = (role == 'admin') ? null : uid;
		
		_transactionSubscription = _firestoreService.getTransactionsStream(uid: uidFilter).listen((transactions) {
			final now = DateTime.now();
			final startOfMonth = DateTime(now.year, now.month, 1);
			final sevenDaysAgo = now.subtract(const Duration(days: 7));
			
			final recentTx = transactions.where((t) => t.date.isAfter(sevenDaysAgo)).toList();
			
			double currentInc = 0.0;
			double currentExp = 0.0;
			double calcBank = 0.0; 
			double calcCash = 0.0; 
			
			for (var tx in transactions) {
				if (tx.date.isAfter(startOfMonth)) {
					if (tx.type == 'income' && !tx.title.contains('Penyesuaian') && !tx.title.contains('Tarik Tunai') && !tx.title.contains('Setor Tunai')) {
						currentInc += tx.amount;
					}
					if (tx.type == 'expense' && !tx.title.contains('Penyesuaian') && !tx.title.contains('Tarik Tunai') && !tx.title.contains('Setor Tunai')) {
						currentExp += tx.amount;
					}
				}
				
				// --- PERBAIKAN: Menambahkan Kurung Kurawal {} ---
				if (tx.category.toLowerCase() == 'uang cash') {
					if (tx.type == 'income') {
						calcCash += tx.amount;
					} else if (tx.type == 'expense') {
						calcCash -= tx.amount;
					}
				} else {
					if (tx.type == 'income') {
						calcBank += tx.amount;
					} else if (tx.type == 'expense') {
						calcBank -= tx.amount;
					}
				}
			}
			
			state = state.copyWith(
				allTransactions: transactions,
				recentTransactions: recentTx,
				bankBalance: calcBank, 
				cashBalance: calcCash, 
				mainBalance: calcBank + calcCash,
				currentMonthIncome: currentInc,
				currentMonthExpense: currentExp,
				isMainBalanceHidden: isMainHidden,
				isBankBalanceHidden: isBankHidden,
				isCashBalanceHidden: isCashHidden,
				customExpenseCategories: cExp,
				customIncomeCategories: cInc,
				isLoading: false, 
			);
		}, onError: (error) {
			debugPrint("🔥 STREAM TERPUTUS: $error"); // Perbaikan 'avoid_print'
			state = state.copyWith(isLoading: false);
		});
	}
	
	void refD() {
		_transactionSubscription?.cancel();
	}
	
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
	
	Future<void> updateBankBalance(double newBalance) async {
		final difference = newBalance - state.bankBalance;
		if (difference == 0) return; 
		
		final authState = ref.read(authProvider); 
		final uid = authState.user?.uid ?? 'unknown';
		
		final tx = TransactionModel(
			uid: uid,
			title: 'Penyesuaian Saldo Rekening Manual',
			amount: difference.abs(),
			type: difference > 0 ? 'income' : 'expense',
			category: 'Lainnya',
			date: DateTime.now(),
		);
		await _firestoreService.addTransaction(tx);
	}
	
	Future<void> updateCashBalance(double newCash) async {
		final difference = newCash - state.cashBalance;
		if (difference == 0) return;
		
		final authState = ref.read(authProvider); 
		final uid = authState.user?.uid ?? 'unknown';
		
		final txCash = TransactionModel(
			uid: uid,
			title: difference > 0 ? 'Tarik Tunai dari Rekening' : 'Setor Tunai ke Rekening',
			amount: difference.abs(),
			type: difference > 0 ? 'income' : 'expense',
			category: 'Uang Cash',
			date: DateTime.now(),
		);
		await _firestoreService.addTransaction(txCash);
		
		final txBank = TransactionModel(
			uid: uid,
			title: difference > 0 ? 'Tarik Tunai ke Uang Cash' : 'Setor Tunai dari Uang Cash',
			amount: difference.abs(),
			type: difference > 0 ? 'expense' : 'income',
			category: 'Lainnya',
			date: DateTime.now().add(const Duration(seconds: 1)),
		);
		await _firestoreService.addTransaction(txBank);
	}
	
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
			final newList = List<String>.from(state.customExpenseCategories)..remove(categoryName);
			await prefs.setStringList('custom_expense_cats', newList);
			state = state.copyWith(customExpenseCategories: newList);
		} else {
			final newList = List<String>.from(state.customIncomeCategories)..remove(categoryName);
			await prefs.setStringList('custom_income_cats', newList);
			state = state.copyWith(customIncomeCategories: newList);
		}
	}
	
	Future<void> addTransaction(TransactionModel transaction) async {
		state = state.copyWith(isLoading: true); 
		try {
			final authState = ref.read(authProvider); 
			final txWithUid = transaction.copyWith(uid: authState.user?.uid ?? 'unknown');
			
			await _firestoreService.addTransaction(txWithUid);
		} finally {
			state = state.copyWith(isLoading: false);
		}
	}
	
	Future<void> updateTransaction(TransactionModel transaction) async {
		state = state.copyWith(isLoading: true);
		try {
			await _firestoreService.updateTransaction(transaction);
		} finally {
			state = state.copyWith(isLoading: false);
		}
	}
	
	Future<void> deleteTransaction(String id) async {
		state = state.copyWith(isLoading: true);
		try {
			await _firestoreService.deleteTransaction(id);
		} finally {
			state = state.copyWith(isLoading: false);
		}
	}
	
	Future<void> clearAllData() async {
		state = state.copyWith(isLoading: true);
		try {
			for (var tx in state.allTransactions) {
				if (tx.id != null) {
					await _firestoreService.deleteTransaction(tx.id!);
				}
			}
			
			final prefs = await SharedPreferences.getInstance();
			await prefs.remove('custom_expense_cats');
			await prefs.remove('custom_income_cats');
		} finally {
			state = state.copyWith(isLoading: false);
		}
	}
	
	Future<void> loadTransactions() async {}
}

final transactionProvider = NotifierProvider<TransactionNotifier, TransactionState>(() {
	return TransactionNotifier();
});
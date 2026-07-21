import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart'; 
import '../../data/firestore_service.dart';
import 'auth_provider.dart'; 

class TransactionState {
	final List<TransactionModel> allTransactions;
	final List<TransactionModel> recentTransactions;
	
	final List<WalletModel> wallets; 
	final Map<String, double> ewalletBalances; 
	
	final double mainBalance;       
	final double bankBalance;       
	final double lockedBalance;     
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
		this.wallets = const [], 
		this.ewalletBalances = const {}, 
		this.mainBalance = 0.0,
		this.bankBalance = 0.0,
		this.lockedBalance = 0.0, 
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
		List<WalletModel>? wallets,
		Map<String, double>? ewalletBalances,
		double? mainBalance,
		double? bankBalance,
		double? lockedBalance,
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
			wallets: wallets ?? this.wallets,
			ewalletBalances: ewalletBalances ?? this.ewalletBalances,
			mainBalance: mainBalance ?? this.mainBalance,
			bankBalance: bankBalance ?? this.bankBalance,
			lockedBalance: lockedBalance ?? this.lockedBalance,
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
	StreamSubscription? _walletSubscription; 
	
	@override
	TransactionState build() {
		final authState = ref.watch(authProvider);
		_transactionSubscription?.cancel();
		_walletSubscription?.cancel();
		
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
		
		// 1. PANTAU DOMPET DIGITAL & SAPU BERSIH DUPLIKAT OTOMATIS
		_walletSubscription = _firestoreService.getWalletsStream(uid: uidFilter).listen((walletsData) async {
			if (walletsData.isEmpty && role != 'admin' && uidFilter != null) {
				final defaults = [
					WalletModel(uid: uidFilter, name: 'DANA', type: 'ewallet', isDefault: true),
					WalletModel(uid: uidFilter, name: 'GoPay', type: 'ewallet', isDefault: true),
					WalletModel(uid: uidFilter, name: 'OVO', type: 'ewallet', isDefault: true),
					WalletModel(uid: uidFilter, name: 'ShopeePay', type: 'ewallet', isDefault: true, accountNumber: null), 
				];
				for (var w in defaults) {
					await _firestoreService.addWallet(w);
				}
			} else {
				// Pembersihan Dompet Duplikat Otomatis (Bug Fix)
				final seen = <String>{};
				final uniqueWallets = <WalletModel>[];
				
				for (var w in walletsData) {
					final wName = w.name.toLowerCase();
					if (seen.contains(wName) && w.id != null) {
						await _firestoreService.deleteWallet(w.id!); // Hapus duplikat dari Cloud
					} else {
						seen.add(wName);
						uniqueWallets.add(w);
					}
				}
				state = state.copyWith(wallets: uniqueWallets);
			}
		});

		// 2. PANTAU & KALKULASI SELURUH TRANSAKSI
		_transactionSubscription = _firestoreService.getTransactionsStream(uid: uidFilter).listen((transactions) {
			final now = DateTime.now();
			final startOfMonth = DateTime(now.year, now.month, 1);
			final sevenDaysAgo = now.subtract(const Duration(days: 7));
			
			final recentTx = transactions.where((t) => t.date.isAfter(sevenDaysAgo)).toList();
			
			double currentInc = 0.0;
			double currentExp = 0.0;
			
			double cBank = 0.0; 
			double cCash = 0.0; 
			double cLocked = 0.0; 
			Map<String, double> cEwallets = {}; 
			
			for (var tx in transactions) {
				if (tx.date.isAfter(startOfMonth)) {
					if (tx.type == 'income' && !tx.title.contains('Penyesuaian') && !tx.title.contains('Tarik Saldo') && !tx.title.contains('Top Up') && !tx.title.contains('Tarik Tunai') && !tx.title.contains('Setor Tunai')) {
						currentInc += tx.amount;
					}
					if (tx.type == 'expense' && !tx.title.contains('Penyesuaian') && !tx.title.contains('Tarik Saldo') && !tx.title.contains('Top Up') && !tx.title.contains('Tarik Tunai') && !tx.title.contains('Setor Tunai')) {
						currentExp += tx.amount;
					}
				}
				
				String cat = tx.category.trim().toLowerCase();
				
				if (cat == 'tabungan') {
					if (tx.type == 'expense') {
						cLocked += tx.amount; 
						cBank -= tx.amount;   
					} else {
						cLocked -= tx.amount; 
						cBank += tx.amount;   
					}
				} 
				else if (cat == 'uang cash') {
					if (tx.type == 'income') cCash += tx.amount;
					else cCash -= tx.amount;
				} 
				else if (['dana', 'gopay', 'ovo', 'shopeepay'].contains(cat) || state.wallets.any((w) => w.name.toLowerCase() == cat)) {
					String wName = tx.category.trim(); 
					if (tx.type == 'income') {
						cEwallets[wName] = (cEwallets[wName] ?? 0) + tx.amount;
					} else {
						cEwallets[wName] = (cEwallets[wName] ?? 0) - tx.amount;
					}
				} 
				else {
					if (tx.type == 'income') cBank += tx.amount;
					else cBank -= tx.amount;
				}
			}
			
			state = state.copyWith(
				allTransactions: transactions,
				recentTransactions: recentTx,
				bankBalance: cBank, 
				cashBalance: cCash, 
				lockedBalance: cLocked, 
				mainBalance: cBank + cLocked, 
				ewalletBalances: cEwallets, 
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
			debugPrint("🔥 STREAM TERPUTUS: $error");
			state = state.copyWith(isLoading: false);
		});
	}
	
	void refD() {
		_transactionSubscription?.cancel();
		_walletSubscription?.cancel();
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

	// --- FUNGSI BARU (FIX): TOP UP E-WALLET DARI REKENING BEBAS ---
	Future<void> updateEWalletBalance(WalletModel wallet, double newBalance) async {
		final currentBalance = state.ewalletBalances[wallet.name] ?? 0.0;
		final difference = newBalance - currentBalance;
		if (difference == 0) return;
		
		final authState = ref.read(authProvider); 
		final uid = authState.user?.uid ?? 'unknown';
		
		// 1. Catat ke E-Wallet
		final txWallet = TransactionModel(
			uid: uid,
			title: difference > 0 ? 'Top Up ${wallet.name}' : 'Tarik Saldo dari ${wallet.name}',
			amount: difference.abs(),
			type: difference > 0 ? 'income' : 'expense',
			category: wallet.name,
			date: DateTime.now(),
		);
		await _firestoreService.addTransaction(txWallet);
		
		// 2. Potong/Tambah dari Rekening Bebas (Agar Saldo Asli Terkoneksi!)
		final txBank = TransactionModel(
			uid: uid,
			title: difference > 0 ? 'Top Up ke ${wallet.name}' : 'Tarik Saldo dari ${wallet.name} ke Rekening',
			amount: difference.abs(),
			type: difference > 0 ? 'expense' : 'income',
			category: 'Lainnya',
			date: DateTime.now().add(const Duration(seconds: 1)),
		);
		await _firestoreService.addTransaction(txBank);
	}
	
	Future<void> addWallet(WalletModel wallet) async {
		await _firestoreService.addWallet(wallet);
	}
	
	Future<void> updateWallet(WalletModel wallet) async {
		await _firestoreService.updateWallet(wallet);
	}
	
	Future<void> deleteWallet(String id) async {
		await _firestoreService.deleteWallet(id);
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
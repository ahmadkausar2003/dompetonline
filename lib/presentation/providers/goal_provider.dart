import 'dart:async';
import 'package:flutter/foundation.dart'; // Tambahan untuk debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:shared_preferences/shared_preferences.dart'; <-- INI SUDAH DIHAPUS

import '../../data/models/goal_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/firestore_service.dart';
import 'transaction_provider.dart';
import 'auth_provider.dart'; 

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
		final authState = ref.watch(authProvider);
		_goalSubscription?.cancel();
		
		if (authState.user != null) {
			Future.microtask(() => _initCloudStream(authState.user!.uid, authState.role ?? 'student'));
		}
		
		return const GoalState();
	}
	
	void _initCloudStream(String uid, String role) async {
		state = state.copyWith(isLoading: true);
		
		final uidFilter = (role == 'admin') ? null : uid;
		
		_goalSubscription = _firestoreService.getGoalsStream(uid: uidFilter).listen((goals) {
			state = state.copyWith(goals: goals, isLoading: false);
		}, onError: (error) {
			debugPrint("🔥 STREAM GOAL TERPUTUS: $error"); // Perbaikan 'avoid_print'
			state = state.copyWith(isLoading: false);
		});
	}
	
	void refD() {
		_goalSubscription?.cancel();
	}
	
	Future<void> addGoal(GoalModel goal) async {
		final authState = ref.read(authProvider);
		final goalWithUid = goal.copyWith(uid: authState.user?.uid ?? 'unknown');
		await _firestoreService.addGoal(goalWithUid);
	}
	
	Future<void> updateGoalAmount(String goalId, double newSavedAmount, {String? type, String? note}) async {
		final goalIndex = state.goals.indexWhere((g) => g.id == goalId);
		if (goalIndex != -1) {
			final goal = state.goals[goalIndex];
			final difference = (newSavedAmount - goal.savedAmount).abs(); 
			
			final updatedGoal = goal.copyWith(savedAmount: newSavedAmount);
			await _firestoreService.updateGoal(updatedGoal);
			
			final authState = ref.read(authProvider);
			final uid = authState.user?.uid ?? 'unknown';
			
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
	
	Future<void> deleteGoal(String id) async {
		final goalIndex = state.goals.indexWhere((g) => g.id == id);
		if (goalIndex != -1) {
			final goal = state.goals[goalIndex];
			if (goal.savedAmount > 0) {
				final authState = ref.read(authProvider);
				final uid = authState.user?.uid ?? 'unknown';
				await ref.read(transactionProvider.notifier).addTransaction(
					TransactionModel(
						uid: uid,
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

	Future<void> clearAllGoals() async {
		state = state.copyWith(isLoading: true);
		try {
			for (var goal in state.goals) {
				if (goal.id != null) {
					await _firestoreService.deleteGoal(goal.id!);
				}
			}
		} finally {
			state = state.copyWith(isLoading: false);
		}
	}
	
	Future<void> loadGoals() async {}
}

final goalProvider = NotifierProvider<GoalNotifier, GoalState>(() => GoalNotifier());
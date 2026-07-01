import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/goal_model.dart';
import '../../core/database/db_helper.dart';

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

  Future<void> updateGoalAmount(int goalId, double newSavedAmount) async {
    final goal = state.goals.firstWhere((g) => g.id == goalId);
    final updatedGoal = goal.copyWith(savedAmount: newSavedAmount);
    await _dbHelper.updateGoal(updatedGoal);
    await loadGoals();
  }

  Future<void> deleteGoal(int id) async {
    await _dbHelper.deleteGoal(id);
    await loadGoals();
  }
}

final goalProvider = NotifierProvider<GoalNotifier, GoalState>(() => GoalNotifier());
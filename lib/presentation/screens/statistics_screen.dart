import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  int _touchedIndex = -1;

  final Map<String, Color> _categoryColors = {
    'Makanan': const Color(0xFFF59E0B),
    'Kos': const Color(0xFF3B82F6),
    'Transportasi': const Color(0xFF8B5CF6),
    'Tugas Kuliah': const Color(0xFFEC4899),
    'Nongkrong': const Color(0xFFEF4444),
    'Lainnya': const Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);

    // Menyaring HANYA pengeluaran untuk BULAN INI agar akurat dengan dasbor
    final now = DateTime.now();
    final expensesThisMonth = state.allTransactions.where((t) {
      return t.type == 'expense' && t.date.year == now.year && t.date.month == now.month;
    }).toList();
    
    // Hitung total per kategori
    final Map<String, double> expensesByCategory = {};
    for (var transaction in expensesThisMonth) {
      if (expensesByCategory.containsKey(transaction.category)) {
        expensesByCategory[transaction.category] = expensesByCategory[transaction.category]! + transaction.amount;
      } else {
        expensesByCategory[transaction.category] = transaction.amount;
      }
    }

    // Mengurutkan kategori berdasarkan pengeluaran terbesar
    final sortedCategories = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Bulan Ini'),
      ),
      body: state.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : expensesThisMonth.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data pengeluaran bulan ini.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.brightness == Brightness.light 
                                ? const Color(0xFFE2E8F0) 
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total Pengeluaran Bulan Ini',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currencyFormat.format(state.currentMonthExpense),
                              style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 220,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                  sections: _buildPieChartSections(sortedCategories, state.currentMonthExpense, theme),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Rincian Kategori',
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedCategories.length,
                        itemBuilder: (context, index) {
                          final category = sortedCategories[index].key;
                          final amount = sortedCategories[index].value;
                          final percentage = state.currentMonthExpense > 0 
                              ? (amount / state.currentMonthExpense) * 100 
                              : 0.0;
                          final color = _categoryColors[category] ?? Colors.grey;

                          return _buildLegendItem(
                            context: context,
                            category: category,
                            amount: amount,
                            percentage: percentage,
                            color: color,
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    List<MapEntry<String, double>> sortedCategories, 
    double totalExpense,
    ThemeData theme,
  ) {
    if (totalExpense <= 0) return [];

    return List.generate(sortedCategories.length, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 0.0;
      final radius = isTouched ? 45.0 : 35.0;
      
      final category = sortedCategories[i].key;
      final amount = sortedCategories[i].value;
      final percentage = (amount / totalExpense) * 100;
      final color = _categoryColors[category] ?? Colors.grey;

      return PieChartSectionData(
        color: color,
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildLegendItem({
    required BuildContext context,
    required String category,
    required double amount,
    required double percentage,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.brightness == Brightness.light 
              ? const Color(0xFFF1F5F9) 
              : const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${percentage.toStringAsFixed(1)}% dari total',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFEF4444),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
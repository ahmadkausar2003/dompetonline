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
  String _selectedType = 'expense';
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Definisi warna yang kaya untuk chart
  final List<Color> _chartColors = [
    const Color(0xFF10B981), // Emerald
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFF97316), // Orange
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Filter transaksi HANYA untuk bulan saat ini & sesuai tipe
    final now = DateTime.now();
    final currentMonthTransactions = state.allTransactions.where((t) {
      return t.type == _selectedType && 
             t.date.month == now.month && 
             t.date.year == now.year;
    }).toList();

    // Hitung total per kategori
    Map<String, double> categoryTotals = {};
    double grandTotal = 0;
    for (var t in currentMonthTransactions) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
      grandTotal += t.amount;
    }

    // Urutkan kategori dari nominal terbesar ke terkecil
    var sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Bulanan'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // TOGGLE PEMASUKAN / PENGELUARAN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'expense',
                    label: Text('Pengeluaran'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text('Pemasukan'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _selectedType == 'expense' 
                      ? const Color(0xFFEF4444) 
                      : const Color(0xFF10B981),
                  selectedForegroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (sortedCategories.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded, 
                      size: 80, 
                      color: theme.colorScheme.primary.withValues(alpha: 0.2)
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada data ${_selectedType == 'income' ? 'pemasukan' : 'pengeluaran'} bulan ini.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // CHART BAGIAN ATAS
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 70,
                      sections: List.generate(sortedCategories.length, (index) {
                        final data = sortedCategories[index];
                        final percentage = (data.value / grandTotal) * 100;
                        return PieChartSectionData(
                          color: _chartColors[index % _chartColors.length],
                          value: data.value,
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: 20,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                  // TEXT DI TENGAH CHART
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        _currencyFormat.format(grandTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _selectedType == 'expense' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // LIST KATEGORI BAGIAN BAWAH
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: ListView.builder(
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final data = sortedCategories[index];
                    final percentage = (data.value / grandTotal) * 100;
                    final color = _chartColors[index % _chartColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
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
                            child: Text(
                              data.key,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormat.format(data.value),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';
import 'transaction_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartStudent Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading && state.allTransactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(transactionProvider.notifier).loadTransactions(),
              color: theme.colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Menggunakan Saldo Utama Absolut
                      _buildBalanceCard(context, state.mainBalance),
                      const SizedBox(height: 24),
                      // Ringkasan Pemasukan & Pengeluaran Bulan Ini
                      _buildSummaryRow(context, state.currentMonthIncome, state.currentMonthExpense),
                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaksi 7 Hari Terakhir',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Data lain di Rekapan',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Menggunakan recentTransactions dari Provider (sudah terfilter 7 hari)
                      _buildRecentTransactions(context, state.recentTransactions),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const TransactionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.transparent 
                : theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Utama', // Teks diperbarui
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(balance),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, double income, double expense) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: 'Masuk (Bulan ini)',
            amount: income,
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: 'Keluar (Bulan ini)',
            amount: expense,
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.light 
              ? const Color(0xFFE2E8F0) 
              : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFormat.format(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, List<TransactionModel> recentTransactions) {
    if (recentTransactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Belum ada transaksi 7 hari terakhir.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(context, recentTransactions[index]);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome ? const Color(0xFF10B981) : theme.textTheme.titleMedium?.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIncome 
                  ? const Color(0xFF10B981).withValues(alpha: 0.1) 
                  : theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(transaction.category),
              color: isIncome ? const Color(0xFF10B981) : theme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Indikator visual jika ada lokasi atau foto
                Row(
                  children: [
                    Text(
                      transaction.category,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    if (transaction.location != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                    ],
                    if (transaction.imagePath != null) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.image, size: 12, color: Colors.grey),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isIncome ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'makanan': return Icons.restaurant;
      case 'kos': return Icons.home;
      case 'transportasi': return Icons.directions_bus;
      case 'tugas kuliah': return Icons.menu_book;
      case 'nongkrong': return Icons.coffee;
      case 'uang saku':
      case 'pemasukan': return Icons.account_balance_wallet;
      default: return Icons.receipt_long;
    }
  }
}
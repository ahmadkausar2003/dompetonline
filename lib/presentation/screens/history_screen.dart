import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rekapan Transaksi'),
          bottom: TabBar(
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Semua'),
              Tab(text: 'Masuk'),
              Tab(text: 'Keluar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTransactionList(context, state.allTransactions, 'Semua'),
            _buildTransactionList(
              context, 
              state.allTransactions.where((t) => t.type == 'income').toList(), 
              'Pemasukan'
            ),
            _buildTransactionList(
              context, 
              state.allTransactions.where((t) => t.type == 'expense').toList(), 
              'Pengeluaran'
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, List<TransactionModel> transactions, String type) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data $type.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(context, transactions[index]);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome ? const Color(0xFF10B981) : theme.textTheme.titleMedium?.color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTransactionDetails(context, transaction),
      child: Container(
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
                  Row(
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(transaction.date),
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
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
      ),
    );
  }

  // Dialog untuk melihat detail lengkap termasuk foto struk dan lokasi
  void _showTransactionDetails(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      transaction.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${isIncome ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildDetailRow(context, 'Kategori', transaction.category, Icons.category_outlined),
                  const SizedBox(height: 16),
                  _buildDetailRow(context, 'Tanggal', DateFormat('dd MMMM yyyy, HH:mm').format(transaction.date), Icons.calendar_today),
                  
                  if (transaction.location != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(context, 'Lokasi', transaction.location!, Icons.location_on_outlined),
                  ],

                  if (transaction.imagePath != null) ...[
                    const SizedBox(height: 24),
                    Text('Bukti Transaksi', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(transaction.imagePath!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: const Center(child: Text('Gambar tidak ditemukan / dihapus')),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        const Spacer(),
        Text(value, style: theme.textTheme.titleMedium),
      ],
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
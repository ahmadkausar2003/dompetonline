import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Dialog untuk mengedit Saldo Rekening Manual
  void _showEditBankBalance(BuildContext context, WidgetRef ref, double currentBalance) {
    // Format teks awal agar saat dialog terbuka sudah ada titik ribuannya
    final initialText = currentBalance == 0 
        ? '' 
        : NumberFormat.decimalPattern('id_ID').format(currentBalance.toInt());
        
    final controller = TextEditingController(text: initialText);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Saldo Rekening'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            // Hapus digitsOnly, dan gunakan CurrencyInputFormatter kustom kita
            inputFormatters: [
              CurrencyInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Nominal Saldo Saat Ini',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Tidak boleh kosong';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // Hapus semua karakter non-angka (seperti titik) sebelum diparse
                final cleanText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                final newBalance = double.tryParse(cleanText) ?? 0.0;
                
                ref.read(transactionProvider.notifier).updateBankBalance(newBalance);
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

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
                      // 1. Kartu Saldo Utama (Hasil Kalkulasi Transaksi)
                      _buildBalanceCard(context, state.mainBalance),
                      const SizedBox(height: 16),
                      
                      // 2. Kartu Saldo Rekening (Input Manual Berdiri Sendiri)
                      _buildBankBalanceCard(context, state.bankBalance),
                      const SizedBox(height: 24),
                      
                      // 3. Ringkasan Pemasukan & Pengeluaran Bulan Ini
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
                            'Lainnya di Rekapan',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 4. Daftar Transaksi 7 Hari Terakhir
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
            'Saldo Utama (Total Transaksi)',
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

  Widget _buildBankBalanceCard(BuildContext context, double balance) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.light 
              ? const Color(0xFFE2E8F0) 
              : const Color(0xFF334155),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance, color: Colors.blueAccent),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo Rekening / Bank',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currencyFormat.format(balance),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: Colors.grey,
            tooltip: 'Ubah Saldo Manual',
            onPressed: () => _showEditBankBalance(context, ref, balance),
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
      ),
    );
  }

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

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(transactionProvider.notifier).deleteTransaction(transaction.id!);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transaksi berhasil dihapus')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus Transaksi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
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

/// Custom formatter untuk menambahkan titik pemisah ribuan secara real-time
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hanya ambil karakter angka murni
    String numericOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (numericOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Format angka menggunakan titik ribuan bergaya Indonesia (id_ID)
    final formatter = NumberFormat.decimalPattern('id_ID');
    String newText = formatter.format(int.parse(numericOnly));

    // Kembalikan value dengan penempatan kursor di akhir text
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
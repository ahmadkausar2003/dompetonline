import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<void> _exportAndSharePDF(List<TransactionModel> transactions, double totalIncome, double totalExpense) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Laporan Transaksi Keuangan - SmartStudent Finance', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Pemasukan: ${_currencyFormat.format(totalIncome)}', style: pw.TextStyle(color: PdfColors.green)),
                  pw.Text('Total Pengeluaran: ${_currencyFormat.format(totalExpense)}', style: pw.TextStyle(color: PdfColors.red)),
                ]
              ),
              pw.SizedBox(height: 20),

              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['Tanggal', 'Judul', 'Kategori', 'Tipe', 'Nominal'],
                  ...transactions.map((t) => [
                        DateFormat('dd/MM/yyyy').format(t.date),
                        t.title,
                        t.category,
                        t.type == 'income' ? 'Masuk' : 'Keluar',
                        _currencyFormat.format(t.amount),
                      ]),
                ],
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Laporan_Keuangan_Mahasiswa.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      Navigator.pop(context);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Halo! Berikut adalah rekapan transaksi keuangan saya dari aplikasi SmartStudent Finance. 📄',
        ),
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencetak laporan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (var t in state.allTransactions) {
      if (t.type == 'income') totalIncome += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rekapan Transaksi'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Bagikan ke WhatsApp (PDF)',
              onPressed: () => _exportAndSharePDF(state.allTransactions, totalIncome, totalExpense),
            ),
            const SizedBox(width: 8),
          ],
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

  // LOGIKA WARNA & IKON JUGA DIPERBAIKI DI REKAPAN
  Widget _buildTransactionItem(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    
    // Warna Dinamis: Hijau untuk Pemasukan, Merah untuk Pengeluaran
    final itemColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

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
                : const Color(0xFF2D2D2D),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: itemColor,
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
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.grey),
                      ],
                      if (transaction.imagePath != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.image_rounded, size: 12, color: Colors.grey),
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
                color: itemColor,
                fontWeight: FontWeight.w800,
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
    final itemColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

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
                        color: itemColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildDetailRow(context, 'Kategori', transaction.category, Icons.category_outlined),
                  const SizedBox(height: 16),
                  _buildDetailRow(context, 'Tanggal', DateFormat('dd MMMM yyyy, HH:mm').format(transaction.date), Icons.calendar_today_rounded),
                  
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
      case 'makanan': return Icons.restaurant_rounded;
      case 'kos': return Icons.home_rounded;
      case 'transportasi': return Icons.directions_bus_rounded;
      case 'tugas kuliah': return Icons.menu_book_rounded;
      case 'nongkrong': return Icons.coffee_rounded;
      case 'uang saku': return Icons.account_balance_wallet_rounded;
      case 'gaji part-time': return Icons.work_rounded;
      case 'bonus': return Icons.card_giftcard_rounded;
      case 'lainnya': return Icons.category_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }
}
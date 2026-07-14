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

  // State untuk Filter UI
  String _filterType = 'Semua'; // Semua, Pemasukan, Pengeluaran, Tabungan
  String _filterTime = 'Bulan Ini'; // Semua Waktu, Hari Ini, Bulan Ini, Tahun Ini, Pilih Tanggal
  DateTime? _customDate;

  // --- LOGIKA FILTER TRANSAKSI ---
  List<TransactionModel> get _filteredTransactions {
    final state = ref.watch(transactionProvider);
    final now = DateTime.now();

    return state.allTransactions.where((t) {
      // 1. Logika Filter Tipe
      bool passType = false;
      final isSystem = t.category == 'Tabungan' || 
          t.category == 'Darurat' || 
          t.title.contains('Darurat') || 
          t.title.contains('Pencairan') || 
          t.title.contains('Batal Target') || 
          t.title.contains('Nabung');

      if (_filterType == 'Semua') {
        passType = true;
      } else if (_filterType == 'Pemasukan') {
        passType = t.type == 'income' && !isSystem;
      } else if (_filterType == 'Pengeluaran') {
        passType = t.type == 'expense' && !isSystem;
      } else if (_filterType == 'Tabungan') {
        passType = isSystem;
      }

      // 2. Logika Filter Waktu
      bool passTime = false;
      if (_filterTime == 'Semua Waktu') {
        passTime = true;
      } else if (_filterTime == 'Hari Ini') {
        passTime = t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
      } else if (_filterTime == 'Bulan Ini') {
        passTime = t.date.year == now.year && t.date.month == now.month;
      } else if (_filterTime == 'Tahun Ini') {
        passTime = t.date.year == now.year;
      } else if (_filterTime == 'Pilih Tanggal' && _customDate != null) {
        passTime = t.date.year == _customDate!.year && t.date.month == _customDate!.month && t.date.day == _customDate!.day;
      } else {
        passTime = true;
      }

      return passType && passTime;
    }).toList();
  }

  // --- POP-UP FILTER WAKTU ---
  void _showTimeFilterDialog() {
    final theme = Theme.of(context);
    final options = ['Semua Waktu', 'Hari Ini', 'Bulan Ini', 'Tahun Ini', 'Pilih Tanggal'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter Waktu', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...options.map((option) => ListTile(
                  title: Text(option),
                  trailing: _filterTime == option ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
                  onTap: () async {
                    if (option == 'Pilih Tanggal') {
                      Navigator.pop(context); // Tutup bottom sheet sebelum buka DatePicker
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _customDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _filterTime = option;
                          _customDate = pickedDate;
                        });
                      }
                    } else {
                      setState(() {
                        _filterTime = option;
                      });
                      Navigator.pop(context);
                    }
                  },
                )),
              ],
            ),
          ),
        );
      }
    );
  }

  // --- FUNGSI GENERATE PDF DENGAN 3 TABEL & SELISIH BERSIH ---
  Future<void> _exportAndSharePDF(List<TransactionModel> transactions, String periodLabel, TransactionState state) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();

      // MEMISAHKAN DATA UNTUK PDF
      final incomeTransactions = transactions.where((t) => 
          t.type == 'income' && 
          t.category != 'Tabungan' && 
          t.category != 'Darurat' && 
          !t.title.contains('Darurat') && 
          !t.title.contains('Pencairan') &&
          !t.title.contains('Batal Target')).toList();

      // List pengeluaran ini sudah MENGABAIKAN uang yang lari ke tabungan
      final expenseTransactions = transactions.where((t) => 
          t.type == 'expense' && 
          t.category != 'Tabungan' && 
          t.category != 'Darurat' && 
          !t.title.contains('Nabung')).toList();

      final targetTransactions = transactions.where((t) => 
          t.category == 'Tabungan' || 
          t.category == 'Darurat' || 
          t.title.contains('Darurat') ||
          t.title.contains('Nabung') ||
          t.title.contains('Pencairan') ||
          t.title.contains('Batal Target')).toList();

      // KALKULASI TOTAL SELISIH BERSIH SESUAI REQUEST (Semua Masuk - Keluar Non Tabungan)
      final double totalAllIncome = transactions.where((t) => t.type == 'income').fold(0, (sum, item) => sum + item.amount);
      final double totalNonTabunganExpense = expenseTransactions.fold(0, (sum, item) => sum + item.amount);
      final double selisihBersihReal = totalAllIncome - totalNonTabunganExpense;

      // Kalkulasi Tambahan (Hanya untuk Display Label)
      double totalTabungan = 0.0;
      double totalDarurat = 0.0;

      for (var t in targetTransactions) {
        if (t.category == 'Darurat' || t.title.contains('Darurat')) {
          if (t.type == 'income' || t.title.contains('Pencairan')) {
            totalDarurat += t.amount;
          }
        } else {
          if (t.type == 'expense') {
            totalTabungan += t.amount;
          }
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // HEADER & INFO SALDO
              pw.Header(
                level: 0,
                child: pw.Text('Laporan Keuangan - SmartStudent Finance', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Periode Laporan: $periodLabel', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Text('Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 15),

              // KOTAK INFORMASI SISA SALDO SAAT INI
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Saldo:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(_currencyFormat.format(state.mainBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue800)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Di Rekening:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(_currencyFormat.format(state.bankBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Uang Cash:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(_currencyFormat.format(state.cashBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ]
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // TABEL 1: PEMASUKAN
              pw.Text('1. Riwayat Pemasukan Harian', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (incomeTransactions.isEmpty)
                pw.Text('Tidak ada riwayat pemasukan pada periode ini.', style: const pw.TextStyle(color: PdfColors.grey))
              else
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: <List<String>>[
                    <String>['Tanggal', 'Judul', 'Kategori', 'Nominal'],
                    ...incomeTransactions.map((t) => [
                      DateFormat('dd/MM/yyyy').format(t.date),
                      t.title,
                      t.category,
                      '+${_currencyFormat.format(t.amount)}',
                    ]),
                  ],
                ),
              pw.SizedBox(height: 25),

              // TABEL 2: PENGELUARAN
              pw.Text('2. Riwayat Pengeluaran (Tanpa Tabungan)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (expenseTransactions.isEmpty)
                pw.Text('Tidak ada riwayat pengeluaran pada periode ini.', style: const pw.TextStyle(color: PdfColors.grey))
              else
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: <List<String>>[
                    <String>['Tanggal', 'Judul', 'Kategori', 'Nominal'],
                    ...expenseTransactions.map((t) => [
                      DateFormat('dd/MM/yyyy').format(t.date),
                      t.title,
                      t.category,
                      '-${_currencyFormat.format(t.amount)}',
                    ]),
                  ],
                ),
              pw.SizedBox(height: 25),

              // TABEL 3: TARGET & DARURAT
              pw.Text('3. Riwayat Tabungan & Dana Darurat', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (targetTransactions.isEmpty)
                pw.Text('Tidak ada aktivitas tabungan atau dana darurat.', style: const pw.TextStyle(color: PdfColors.grey))
              else
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: <List<String>>[
                    <String>['Tanggal', 'Judul', 'Tipe', 'Nominal'],
                    ...targetTransactions.map((t) => [
                      DateFormat('dd/MM/yyyy').format(t.date),
                      t.title,
                      t.type == 'income' ? 'Cair/Ditarik' : 'Ditabung',
                      _currencyFormat.format(t.amount),
                    ]),
                  ],
                ),
              pw.SizedBox(height: 30),

              // RINGKASAN TOTAL (FOOTER)
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Ringkasan Aktivitas ($periodLabel)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Riwayat Tabungan (Uang Masuk ke Target):', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(_currencyFormat.format(totalTabungan), style: pw.TextStyle(fontSize: 12, color: PdfColors.indigo, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Penarikan Darurat:', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(_currencyFormat.format(totalDarurat), style: pw.TextStyle(fontSize: 12, color: PdfColors.orange, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.SizedBox(height: 16),

              // TOTAL SELISIH BERSIH
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: selisihBersihReal >= 0 ? PdfColors.green50 : PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: selisihBersihReal >= 0 ? PdfColors.green200 : PdfColors.red200, width: 1.5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Uang Masuk (Seluruhnya):', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('+ ${_currencyFormat.format(totalAllIncome)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Uang Keluar (Tanpa Tabungan):', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('- ${_currencyFormat.format(totalNonTabunganExpense)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.Divider(color: selisihBersihReal >= 0 ? PdfColors.green200 : PdfColors.red200),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Selisih Bersih:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          '${selisihBersihReal >= 0 ? '+' : '-'} ${_currencyFormat.format(selisihBersihReal.abs())}', 
                          style: pw.TextStyle(
                            fontSize: 14, 
                            color: selisihBersihReal >= 0 ? PdfColors.green800 : PdfColors.red800, 
                            fontWeight: pw.FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ]
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Laporan_Keuangan_Mahasiswa.pdf');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) {
        return;
      }

      Navigator.pop(context); // Tutup dialog loading

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Halo! Berikut adalah rekapan transaksi keuangan saya dari aplikasi SmartStudent Finance ($periodLabel). 📄',
        ),
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup dialog loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencetak laporan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final theme = Theme.of(context);
    final filteredData = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekapan Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Cetak Laporan (PDF)',
            onPressed: () {
              // Jika filter spesifik, label PDF akan mengikuti filter
              String label = _filterTime;
              if (_filterTime == 'Pilih Tanggal' && _customDate != null) {
                label = DateFormat('dd MMMM yyyy', 'id_ID').format(_customDate!);
              }
              _exportAndSharePDF(filteredData, label, state);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // HEADER FILTER UI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Semua', 'Pemasukan', 'Pengeluaran', 'Tabungan'].map((type) {
                        final isSelected = _filterType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setState(() => _filterType = type);
                            },
                            backgroundColor: theme.cardTheme.color,
                            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            checkmarkColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? theme.colorScheme.primary : Colors.grey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                InkWell(
                  onTap: _showTimeFilterDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 20, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PEMBERITAHUAN FILTER AKTIF (Jika bukan Semua Waktu)
          if (_filterTime != 'Semua Waktu')
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Menampilkan: ${_filterTime == 'Pilih Tanggal' && _customDate != null ? DateFormat('dd MMM yyyy').format(_customDate!) : _filterTime}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // LIST TRANSAKSI
          Expanded(
            child: filteredData.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada transaksi untuk filter ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionItem(context, filteredData[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
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

    final isSystemTransaction = transaction.category == 'Darurat' || 
        transaction.category == 'Tabungan' || 
        transaction.title.contains('Darurat') ||
        transaction.title.contains('Pencairan') ||
        transaction.title.contains('Batal Target');

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
                      textAlign: TextAlign.center,
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
                  
                  // LOGIKA PELINDUNG HAPUS TRANSAKSI SISTEM
                  if (isSystemTransaction)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Riwayat otomatis dari fitur Target Tabungan. Penghapusan manual dinonaktifkan untuk menjaga akurasi saldo.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
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
      case 'uang cash': return Icons.local_atm_rounded;
      case 'bonus': return Icons.card_giftcard_rounded;
      case 'darurat': return Icons.warning_rounded; 
      case 'tabungan': return Icons.savings_rounded; 
      case 'belanja': return Icons.shopping_bag_rounded;
      case 'hiburan': return Icons.movie_creation_rounded;
      case 'kesehatan': return Icons.medical_services_rounded;
      case 'tagihan': return Icons.receipt_rounded;
      case 'olahraga': return Icons.sports_basketball_rounded;
      case 'investasi': return Icons.trending_up_rounded;
      case 'hadiah': return Icons.redeem_rounded;
      case 'lainnya': return Icons.category_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }
}
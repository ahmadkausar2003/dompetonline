import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/goal_model.dart'; 

// --- CUSTOM FORMATTER UNTUK RIBUAN RUPIAH ---
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String numericOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final formatter = NumberFormat.decimalPattern('id_ID');
    String newText = formatter.format(int.parse(numericOnly));

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
// --- AKHIR CUSTOM FORMATTER ---

class GoalDetailScreen extends ConsumerStatefulWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  late Future<List<GoalLogModel>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _dbHelper.getGoalLogs(widget.goalId);
    });
  }

  Future<void> _handleTransaction(String type, double amount, String note, double currentSaved) async {
    // Tentukan tipe log untuk UI Detail Target
    final logType = type == 'in' ? 'in' : 'out';

    final newLog = GoalLogModel(
      goalId: widget.goalId,
      amount: amount,
      type: logType,
      note: note,
      date: DateTime.now(),
    );

    await _dbHelper.insertGoalLog(newLog);
    
    final newSavedAmount = type == 'in' ? currentSaved + amount : currentSaved - amount;
    
    // Meneruskan perintah spesifik ke Goal Provider
    await ref.read(goalProvider.notifier).updateGoalAmount(
      widget.goalId, 
      newSavedAmount, 
      type: type, 
      note: note,
    );
    
    _refreshLogs();
    if (mounted) Navigator.pop(context);
  }

  void _showAddFundDialog(double currentSaved, double target) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final currentBankBalance = ref.read(transactionProvider).bankBalance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Isi Tabungan'),
        content: SingleChildScrollView( 
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo Rekening Tersedia:', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        _currencyFormat.format(currentBankBalance), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ', border: OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Wajib diisi';
                    final cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                    final amount = double.tryParse(cleanVal) ?? 0;
                    
                    if (amount <= 0) return 'Nominal tidak valid';
                    if (amount > currentBankBalance) return 'Saldo Rekening tidak mencukupi!';
                    
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Sumber Dana (Misal: Sisa Uang Jajan)', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cleanAmountText = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                final amount = double.parse(cleanAmountText);
                
                _handleTransaction('in', amount, noteController.text.trim(), currentSaved);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawFundDialog(double currentSaved) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarik Tabungan'),
        content: SingleChildScrollView( 
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Nominal Penarikan', prefixText: 'Rp ', border: OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Wajib diisi';
                    final cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                    final amt = double.tryParse(cleanVal) ?? 0;
                    
                    if (amt <= 0) return 'Tidak valid';
                    if (amt > currentSaved) return 'Saldo tabungan tidak cukup';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Catatan Penarikan', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 24),
                // TOMBOL 1: CAIRKAN KE REKENING
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final cleanAmountText = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                        final amount = double.parse(cleanAmountText);
                        _handleTransaction('out_refund', amount, noteController.text.trim(), currentSaved);
                      }
                    },
                    child: const Text('Cairkan ke Rekening / Dompet'),
                  ),
                ),
                const SizedBox(height: 8),
                // TOMBOL 2: PAKAI LANGSUNG (DARURAT)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final cleanAmountText = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                        final amount = double.parse(cleanAmountText);
                        _handleTransaction('out_expense', amount, noteController.text.trim(), currentSaved);
                      }
                    },
                    child: const Text('Gunakan Langsung (Darurat)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(goalProvider);
    final theme = Theme.of(context);
    
    final goalIndex = state.goals.indexWhere((g) => g.id == widget.goalId);
    if (goalIndex == -1) return const Scaffold(body: Center(child: Text('Target tidak ditemukan')));
    final goal = state.goals[goalIndex];

    double progress = (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: () async {
              await ref.read(goalProvider.notifier).deleteGoal(goal.id!);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2))),
            ),
            child: Column(
              children: [
                Text('Total Terkumpul', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_currencyFormat.format(goal.savedAmount), style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Text('dari target ${_currencyFormat.format(goal.targetAmount)}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white54,
                    valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? const Color(0xFF10B981) : theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<GoalLogModel>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final logs = snapshot.data ?? [];
                
                if (logs.isEmpty) {
                  return const Center(child: Text('Belum ada riwayat untuk target ini.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isIn = log.type == 'in';
                    final color = isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: color),
                      ),
                      title: Text(log.note, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(log.date)),
                      trailing: Text(
                        '${isIn ? '+' : '-'}${_currencyFormat.format(log.amount)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: goal.savedAmount <= 0 ? null : () => _showWithdrawFundDialog(goal.savedAmount),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Tarik Tabungan'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: progress >= 1.0 ? null : () => _showAddFundDialog(goal.savedAmount, goal.targetAmount),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Isi Tabungan'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
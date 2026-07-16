import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/goal_provider.dart';
import '../../data/models/goal_model.dart';
import 'goal_detail_screen.dart';

// Formatter Khusus untuk mengubah input angka menjadi format ribuan otomatis
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    // Menghapus karakter non-digit
    final numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericString.isEmpty) return newValue.copyWith(text: '');
    
    // Format kembali dengan pemisah ribuan (titik)
    final number = int.parse(numericString);
    final formatter = NumberFormat('#,###', 'id_ID');
    final newString = formatter.format(number);
    
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalProvider);
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Tabungan'),
      ),
      body: state.isLoading
      ? const Center(child: CircularProgressIndicator())
      : state.goals.isEmpty
      ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Belum ada target tabungan.',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol + di bawah untuk mulai menabung!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
      : ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: state.goals.length,
        itemBuilder: (context, index) {
          final goal = state.goals[index];
          
          double progress = goal.targetAmount > 0 ? (goal.savedAmount / goal.targetAmount) : 0.0;
          progress = progress.clamp(0.0, 1.0);
          final isCompleted = progress >= 1.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  // PERBAIKAN: Menggunakan goal.id! (satu tanda seru)
                  MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id!)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isCompleted 
                    ? const Color(0xFF10B981)
                    : (theme.brightness == Brightness.light ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                    width: isCompleted ? 2 : 1,
                  ),
                  boxShadow: theme.brightness == Brightness.light
                  ? [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]
                  : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCompleted)
                          const Row(
                            children: [
                              Text('Tercapai ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                              Icon(Icons.emoji_events, color: Color(0xFF10B981)),
                            ],
                          )
                        else
                          Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Terkumpul', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(goal.savedAmount),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: isCompleted ? const Color(0xFF10B981) : theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Target', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(goal.targetAmount),
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? const Color(0xFF10B981) : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? const Color(0xFF10B981) : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _showAddGoalDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Target Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
  
  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Buat Target Baru'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nama Target',
                    hintText: 'Misal: Beli Laptop, UKT',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Nama target wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Nominal Target',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Nominal wajib diisi';
                    final numericString = value.replaceAll('.', '');
                    if ((double.tryParse(numericString) ?? 0) <= 0) return 'Nominal tidak valid';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final numericString = targetController.text.replaceAll('.', '');
                  final newGoal = GoalModel(
                    title: titleController.text.trim(),
                    targetAmount: double.parse(numericString),
                    savedAmount: 0.0, uid: '',
                  );
                  ref.read(goalProvider.notifier).addGoal(newGoal);
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan Target'),
            ),
          ],
        );
      },
    );
  }
}
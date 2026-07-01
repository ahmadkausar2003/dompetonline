import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _goalTitle = 'Belum ada target';
  double _targetAmount = 0.0;
  double _savedAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgetInfo();
  }

  // --- LOGIKA DATA (SHARED PREFERENCES) ---
  Future<void> _loadBudgetInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _goalTitle = prefs.getString('budget_title') ?? 'Belum ada target';
      _targetAmount = prefs.getDouble('budget_target') ?? 0.0;
      _savedAmount = prefs.getDouble('budget_saved') ?? 0.0;
      _isLoading = false;
    });
  }

  Future<void> _saveGoal(String title, double target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('budget_title', title);
    await prefs.setDouble('budget_target', target);
    
    // Reset tabungan jika membuat target baru
    if (title != _goalTitle || target != _targetAmount) {
      await prefs.setDouble('budget_saved', 0.0);
    }
    
    _loadBudgetInfo();
  }

  Future<void> _addSaving(double amountToAdd) async {
    final prefs = await SharedPreferences.getInstance();
    final newSavedAmount = _savedAmount + amountToAdd;
    
    // Cegah agar tabungan tidak melebihi target
    final finalAmount = newSavedAmount > _targetAmount ? _targetAmount : newSavedAmount;
    
    await prefs.setDouble('budget_saved', finalAmount);
    _loadBudgetInfo();
  }

  // --- DIALOG UI ---
  void _showSetGoalDialog() {
    final titleController = TextEditingController(text: _goalTitle == 'Belum ada target' ? '' : _goalTitle);
    final targetController = TextEditingController(
      text: _targetAmount == 0.0 ? '' : _targetAmount.toInt().toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Atur Target Baru'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama Target (misal: Beli Laptop)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Target',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Tidak boleh kosong';
                    if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Nominal tidak valid';
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _saveGoal(titleController.text.trim(), double.parse(targetController.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Target tabungan berhasil diatur!')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSavingDialog() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Tabungan'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal Ditabung',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Tidak boleh kosong';
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) return 'Nominal tidak valid';
                if (_savedAmount + amount > _targetAmount) return 'Nominal melebihi sisa target';
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
                  _addSaving(double.parse(amountController.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tabungan berhasil ditambahkan!')),
                  );
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTarget = _targetAmount > 0;
    
    // Kalkulasi Persentase
    double progress = hasTarget ? (_savedAmount / _targetAmount) : 0.0;
    // Mencegah error jika nilai progress melebihi 1.0 atau kurang dari 0
    progress = progress.clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Tabungan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- KARTU TARGET UTAMA ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.brightness == Brightness.light 
                            ? const Color(0xFFE2E8F0) 
                            : const Color(0xFF334155),
                      ),
                      boxShadow: theme.brightness == Brightness.light
                          ? [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                _goalTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _showSetGoalDialog,
                              icon: const Icon(Icons.edit_outlined),
                              color: theme.colorScheme.primary,
                              tooltip: 'Atur Target',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Informasi Nominal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Terkumpul',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currencyFormat.format(_savedAmount),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Target',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currencyFormat.format(_targetAmount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Persentase Text
                        Center(
                          child: Text(
                            '${(progress * 100).toStringAsFixed(1)}% Tercapai',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- TOMBOL TAMBAH TABUNGAN ---
                  if (hasTarget && progress < 1.0)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _showAddSavingDialog,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Tambah Tabungan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    
                  if (progress >= 1.0 && hasTarget)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.emoji_events, color: Color(0xFF10B981), size: 48),
                          SizedBox(height: 8),
                          Text(
                            'Selamat! Target tabunganmu telah tercapai.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            ),
    );
  }
}
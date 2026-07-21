import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../providers/auth_provider.dart'; 
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import 'transaction_screen.dart';

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
  
  void _showEditBankBalance(BuildContext context, WidgetRef ref, double currentBalance) {
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
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Nominal Saldo Saat Ini',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
              helperText: 'Akan memperbarui Total Saldo Utama secara langsung.',
              helperMaxLines: 2,
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
  
  void _showEditCashBalance(BuildContext context, WidgetRef ref, double currentBalance) {
    final initialText = currentBalance == 0 
        ? '' 
        : NumberFormat.decimalPattern('id_ID').format(currentBalance.toInt());
    
    final controller = TextEditingController(text: initialText);
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.wallet, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Ubah Uang Cash'),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Uang Cash di Dompet',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
              helperText: 'Otomatis tarik/setor dari Rekening Bebas agar Saldo Asli tidak berubah.',
              helperMaxLines: 4,
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
                final cleanText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                final newBalance = double.tryParse(cleanText) ?? 0.0;
                
                ref.read(transactionProvider.notifier).updateCashBalance(newBalance);
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- LOGIKA BARU: KELOLA E-WALLET LEBIH PRAKTIS (TOP UP / TARIK) ---
  void _showEditEWalletBalance(BuildContext context, WidgetRef ref, WalletModel wallet, double currentBalance) {
    final controller = TextEditingController(); // Dikosongkan agar praktis
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kelola Saldo ${wallet.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo Saat Ini: ${_currencyFormat.format(currentBalance)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                  helperText: 'Pilih Top Up (Tambah) atau Tarik (Kurangi).',
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Masukkan nominal';
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
          OutlinedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cleanText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                final nominal = double.tryParse(cleanText) ?? 0.0;
                
                if (nominal > 0) {
                  // Logika Tarik (Mengurangi Saldo E-Wallet)
                  ref.read(transactionProvider.notifier).updateEWalletBalance(wallet, currentBalance - nominal);
                }
                Navigator.pop(context);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
            ),
            child: const Text('Tarik'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cleanText = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                final nominal = double.tryParse(cleanText) ?? 0.0;
                
                if (nominal > 0) {
                  // Logika Top Up (Menambah Saldo E-Wallet)
                  ref.read(transactionProvider.notifier).updateEWalletBalance(wallet, currentBalance + nominal);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  void _showSetWalletNumber(BuildContext context, WidgetRef ref, WalletModel wallet) {
    final controller = TextEditingController(text: wallet.accountNumber ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nomor ${wallet.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'No. HP / Rekening',
            border: OutlineInputBorder(),
            hintText: 'Contoh: 081234567890',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')
          ),
          FilledButton(
            onPressed: () {
              final newNumber = controller.text.trim();
              ref.read(transactionProvider.notifier).updateWallet(
                wallet.copyWith(accountNumber: newNumber.isEmpty ? null : newNumber)
              );
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
  
  void _showAddWalletDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah E-Wallet Baru'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama E-Wallet',
              hintText: 'Contoh: LinkAja, PayPal',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Tidak boleh kosong' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final authState = ref.read(authProvider);
                ref.read(transactionProvider.notifier).addWallet(
                  WalletModel(
                    uid: authState.user?.uid ?? 'unknown',
                    name: controller.text.trim(),
                    type: 'ewallet',
                  )
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
  
  void _showNotifications(BuildContext context, double mainBalance) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
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
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      'Pusat Notifikasi',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildNotifItem(
                  context: context,
                  icon: Icons.wb_sunny_rounded,
                  color: const Color(0xFF3B82F6),
                  title: 'Pengingat Harian',
                  desc: 'Halo! Jangan lupa mencatat pengeluaran atau pemasukanmu hari ini ya.',
                ),
                const SizedBox(height: 16),
                if (mainBalance < 50000)
                  _buildNotifItem(
                    context: context,
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFEF4444),
                    title: 'Peringatan Saldo Menipis',
                    desc: 'Total Asetmu saat ini tersisa ${_currencyFormat.format(mainBalance)}. Yuk, mulai berhemat!',
                  )
                else
                  _buildNotifItem(
                    context: context,
                    icon: Icons.thumb_up_rounded,
                    color: const Color(0xFF10B981),
                    title: 'Kondisi Keuangan Aman',
                    desc: 'Kondisi keuanganmu terlihat stabil. Jangan lupa sisihkan sebagian untuk Target Tabungan!',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildNotifItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String desc
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color
                  )
                ),
                const SizedBox(height: 4),
                Text(desc, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isAdmin = authState.role == 'admin';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartStudent Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Notifikasi',
            onPressed: () => _showNotifications(context, state.mainBalance),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading && state.allTransactions.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
        onRefresh: () async => ref.read(transactionProvider.notifier).loadTransactions(),
        color: theme.colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(context, state.mainBalance, state.isMainBalanceHidden),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildSubBalanceCard(
                        context: context,
                        title: 'Rekening Bebas Pakai',
                        balance: state.bankBalance,
                        icon: Icons.account_balance_rounded,
                        color: Colors.blueAccent,
                        isHidden: state.isBankBalanceHidden,
                        isAdmin: isAdmin,
                        onToggleHide: () => ref.read(transactionProvider.notifier).toggleBankBalanceHidden(),
                        onTap: isAdmin ? () {} : () => _showEditBankBalance(context, ref, state.bankBalance),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSubBalanceCard(
                        context: context,
                        title: 'Uang Cash',
                        balance: state.cashBalance,
                        icon: Icons.wallet_rounded,
                        color: const Color(0xFFF59E0B),
                        isHidden: state.isCashBalanceHidden,
                        isAdmin: isAdmin,
                        onToggleHide: () => ref.read(transactionProvider.notifier).toggleCashBalanceHidden(),
                        onTap: isAdmin ? () {} : () => _showEditCashBalance(context, ref, state.cashBalance),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                if (state.wallets.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dompet Digital (E-Wallet)',
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 18)
                      ),
                      if (!isAdmin)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                          onPressed: () => _showAddWalletDialog(context, ref),
                          tooltip: 'Tambah E-Wallet',
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: state.wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = state.wallets[index];
                      final wBalance = state.ewalletBalances[wallet.name] ?? 0.0;
                      return _buildWalletCard(context, ref, wallet, wBalance, isAdmin);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                
                _buildSummaryRow(context, state.currentMonthIncome, state.currentMonthExpense),
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaksi 7 Hari Terakhir',
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 18)
                    ),
                    Text(
                      'Lainnya di Rekapan',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildRecentTransactions(context, state.recentTransactions, isAdmin),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: isAdmin ? null : FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TransactionScreen())
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildBalanceCard(BuildContext context, double balance, bool isHidden) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.transparent 
                : theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Aset (Rekening Asli)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500
                )
              ),
              InkWell(
                onTap: () => ref.read(transactionProvider.notifier).toggleMainBalanceHidden(),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.white70,
                    size: 20
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isHidden ? 'Rp ••••••••' : _currencyFormat.format(balance),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 32
            )
          ),
          const SizedBox(height: 4),
          const Text(
            'Termasuk uang di Tabungan',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12
            )
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubBalanceCard({
    required BuildContext context,
    required String title,
    required double balance,
    required IconData icon,
    required Color color,
    required bool isHidden,
    required bool isAdmin,
    required VoidCallback onToggleHide,
    required VoidCallback onTap
  }) {
    final theme = Theme.of(context);
    final isNegative = balance < 0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.brightness == Brightness.light 
                  ? const Color(0xFFF1F5F9) 
                  : const Color(0xFF2D2D2D)
            )
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)
                    ),
                    child: Icon(icon, color: color, size: 18)
                  ),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: Colors.grey,
                          size: 18
                        ),
                        onPressed: onToggleHide
                      ),
                      if (!isAdmin) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit_rounded,
                          color: Colors.grey.withValues(alpha: 0.5),
                          size: 16
                        )
                      ]
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey
                )
              ),
              const SizedBox(height: 4),
              Text(
                isHidden ? 'Rp ••••' : _currencyFormat.format(balance),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: -0.5,
                  color: isNegative && !isHidden 
                      ? const Color(0xFFEF4444) 
                      : theme.textTheme.titleMedium?.color
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, WidgetRef ref, WalletModel wallet, double balance, bool isAdmin) {
    final theme = Theme.of(context);
    final isHidden = ref.watch(transactionProvider).isCashBalanceHidden; 
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.light 
              ? const Color(0xFFF1F5F9) 
              : const Color(0xFF2D2D2D)
        )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(wallet.name),
                    color: const Color(0xFF3B82F6),
                    size: 18
                  ),
                  const SizedBox(width: 6),
                  Text(
                    wallet.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14)
                  )
                ]
              ),
              if (!isAdmin)
                InkWell(
                  onTap: () => _showEditEWalletBalance(context, ref, wallet, balance),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.grey.withValues(alpha: 0.5),
                    size: 16
                  )
                ),
            ],
          ),
          const Spacer(),
          Text(
            isHidden ? 'Rp ••••' : _currencyFormat.format(balance),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: -0.5
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              if (wallet.accountNumber != null && wallet.accountNumber!.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: wallet.accountNumber!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Nomor ${wallet.name} berhasil disalin!'),
                    backgroundColor: theme.colorScheme.primary
                  )
                );
              } else if (!isAdmin) {
                _showSetWalletNumber(context, ref, wallet);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.1 : 1.0
                ),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    wallet.accountNumber == null ? Icons.add_rounded : Icons.copy_rounded,
                    size: 12,
                    color: Colors.grey
                  ),
                  const SizedBox(width: 4),
                  Text(
                    wallet.accountNumber == null ? 'Set No. Rek' : 'Salin Nomor',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
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
            iconColor: const Color(0xFF10B981)
          )
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: 'Keluar (Bulan ini)',
            amount: expense,
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFEF4444)
          )
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.light 
              ? const Color(0xFFF1F5F9) 
              : const Color(0xFF2D2D2D)
        )
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
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Icon(icon, color: iconColor, size: 20)
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFormat.format(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              letterSpacing: -0.5
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentTransactions(BuildContext context, List<TransactionModel> recentTransactions, bool isAdmin) {
    if (recentTransactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Belum ada transaksi 7 hari terakhir.',
            style: TextStyle(color: Colors.grey)
          )
        )
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionItem(context, recentTransactions[index], isAdmin);
      }
    );
  }
  
  Widget _buildTransactionItem(BuildContext context, TransactionModel transaction, bool isAdmin) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final itemColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showTransactionDetails(context, transaction, isAdmin),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.brightness == Brightness.light 
                ? const Color(0xFFF1F5F9) 
                : const Color(0xFF2D2D2D)
          )
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: itemColor,
                size: 24
              )
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
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        transaction.category,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)
                      ),
                      if (transaction.location != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.grey)
                      ],
                      if (transaction.imagePath != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.image_rounded, size: 12, color: Colors.grey)
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
                letterSpacing: -0.5
              )
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTransactionDetails(BuildContext context, TransactionModel transaction, bool isAdmin) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final itemColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    final isSystemTransaction = transaction.category == 'Darurat' || 
                                transaction.category == 'Tabungan' || 
                                transaction.title.startsWith('Pencairan') || 
                                transaction.title.startsWith('Batal Target');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
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
                        borderRadius: BorderRadius.circular(4)
                      )
                    )
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      transaction.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center
                    )
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${isIncome ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: itemColor,
                        letterSpacing: -1.0
                      )
                    )
                  ),
                  const SizedBox(height: 32),
                  
                  _buildDetailRow(context, 'Kategori', transaction.category, Icons.category_outlined),
                  const SizedBox(height: 16),
                  _buildDetailRow(context, 'Tanggal', DateFormat('dd MMMM yyyy, HH:mm').format(transaction.date), Icons.calendar_today_rounded),
                  
                  if (transaction.location != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(context, 'Lokasi', transaction.location!, Icons.location_on_outlined)
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
                            child: const Center(child: Text('Gambar tidak ditemukan / dihapus'))
                          );
                        }
                      )
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  if (isAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3))
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mode Pantau (Admin): Anda hanya dapat melihat riwayat, tidak dapat menghapusnya.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.blue.shade700)
                            )
                          )
                        ]
                      ),
                    )
                  else if (isSystemTransaction)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Riwayat otomatis dari fitur Target Tabungan. Penghapusan manual dinonaktifkan untuk menjaga akurasi saldo.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB45309))
                            )
                          )
                        ]
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
                              const SnackBar(content: Text('Transaksi berhasil dihapus'))
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus Transaksi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 16)
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
        Text(value, style: theme.textTheme.titleMedium)
      ]
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
      case 'dana': return Icons.account_balance_wallet_rounded;
      case 'gopay': return Icons.account_balance_wallet_rounded;
      case 'ovo': return Icons.account_balance_wallet_rounded;
      case 'shopeepay': return Icons.shopping_bag_rounded;
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
      default: return Icons.category_rounded;
    }
  }
}
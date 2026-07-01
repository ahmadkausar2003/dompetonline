import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../providers/transaction_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Pengaturan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- BAGIAN PROFIL ---
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mahasiswa Hebat',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pengguna SmartStudent Finance',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),

            // --- BAGIAN PENGATURAN ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pengaturan Aplikasi',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            
            // Pengaturan Tema
            _buildSettingsTile(
              context: context,
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              title: 'Mode Gelap (Dark Mode)',
              trailing: Switch(
                value: isDark,
                activeThumbColor: theme.colorScheme.primary,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
              ),
            ),
            const SizedBox(height: 16),

            // Pengaturan Reset Data
            _buildSettingsTile(
              context: context,
              icon: Icons.delete_forever,
              title: 'Hapus Semua Data',
              iconColor: const Color(0xFFEF4444),
              textColor: const Color(0xFFEF4444),
              onTap: () => _showResetConfirmationDialog(context, ref),
            ),
            const SizedBox(height: 16),

            // Info Aplikasi
            _buildSettingsTile(
              context: context,
              icon: Icons.info_outline,
              title: 'Tentang Aplikasi',
              subtitle: 'Versi 1.0.0',
            ),
          ],
        ),
      ),
    );
  }

  // Komponen Helper untuk list pengaturan
  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.brightness == Brightness.light 
                ? const Color(0xFFE2E8F0) 
                : const Color(0xFF334155),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Dialog Konfirmasi Hapus Data
  void _showResetConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Peringatan!'),
          content: const Text(
            'Apakah kamu yakin ingin menghapus seluruh data transaksi? Data yang sudah dihapus tidak dapat dikembalikan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                // Proses hapus data
                await ref.read(transactionProvider.notifier).clearAllData();
                if (!context.mounted) return;
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seluruh data berhasil dihapus.'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              },
              child: const Text('Hapus Semua'),
            ),
          ],
        );
      },
    );
  }
}
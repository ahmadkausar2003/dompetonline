import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/theme_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
	const ProfileScreen({super.key});
	
	@override
	ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
	String _userName = 'Mahasiswa Hebat';
	String? _profileImagePath;
	
	@override
	void initState() {
		super.initState();
		_loadProfileData();
	}
	
	Future<void> _loadProfileData() async {
		final prefs = await SharedPreferences.getInstance();
		setState(() {
			_userName = prefs.getString('user_name') ?? 'Mahasiswa Hebat';
			_profileImagePath = prefs.getString('profile_image');
		});
	}
	
	Future<void> _saveUserName(String newName) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setString('user_name', newName);
		setState(() {
			_userName = newName;
		});
	}
	
	Future<void> _pickProfileImage() async {
		final picker = ImagePicker();
		final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
		
		if (pickedFile != null) {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('profile_image', pickedFile.path);
			setState(() {
				_profileImagePath = pickedFile.path;
			});
		}
	}
	
	void _showEditNameDialog() {
		final nameController = TextEditingController(text: _userName);
		final formKey = GlobalKey<FormState>();
		
		showDialog(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: const Text('Ubah Nama'),
					content: Form(
						key: formKey,
						child: TextFormField(
							controller: nameController,
							textCapitalization: TextCapitalization.words,
							decoration: const InputDecoration(
								labelText: 'Nama Panggilan',
								border: OutlineInputBorder(),
							),
							validator: (value) => value == null || value.trim().isEmpty ? 'Nama tidak boleh kosong' : null,
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
									_saveUserName(nameController.text.trim());
									Navigator.pop(context);
								}
							},
							child: const Text('Simpan'),
						),
					],
				);
			},
		);
	}
	
	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final themeMode = ref.watch(themeProvider);
		final isDark = themeMode == ThemeMode.dark;
		
		final transactionState = ref.watch(transactionProvider);
		final goalState = ref.watch(goalProvider);
		
		final authState = ref.watch(authProvider);
		final isAdmin = authState.role == 'admin';
		
		final subtitleColor = theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87;
		
		return Scaffold(
			appBar: AppBar(
				title: const Text('Profil & Pengaturan'),
				centerTitle: true,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(24.0),
				child: Column(
					children: [
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
								? [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]
								: null,
							),
							child: Column(
								children: [
									Stack(
										alignment: Alignment.bottomRight,
										children: [
											GestureDetector(
												onTap: isAdmin ? null : _pickProfileImage,
												child: CircleAvatar(
													radius: 50,
													backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
													backgroundImage: _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null,
													child: _profileImagePath == null 
													? Icon(Icons.person, size: 50, color: theme.colorScheme.primary)
													: null,
												),
											),
											if (!isAdmin)
												GestureDetector(
													onTap: _pickProfileImage,
													child: CircleAvatar(
														radius: 16,
														backgroundColor: theme.colorScheme.primary,
														child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
													),
												),
										],
									),
									const SizedBox(height: 16),
									Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Text(
												isAdmin ? 'Akun Orang Tua' : _userName,
												style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
											),
											if (!isAdmin)
												IconButton(
													icon: const Icon(Icons.edit, size: 20),
													color: theme.colorScheme.primary,
													onPressed: _showEditNameDialog,
												)
										],
									),
									Text(
										isAdmin ? 'Mode Pemantauan' : 'Pengguna SmartStudent Finance',
										style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor),
									),
									const SizedBox(height: 24),
									const Divider(),
									const SizedBox(height: 16),
									
									Row(
										children: [
											Expanded(
												child: Column(
													children: [
														Text(
															'${transactionState.allTransactions.length}',
															style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
														),
														const SizedBox(height: 4),
														Text('Total Transaksi', style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor)),
													],
												),
											),
											Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
											Expanded(
												child: Column(
													children: [
														Text(
															'${goalState.goals.length}',
															style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
														),
														const SizedBox(height: 4),
														Text('Target Dibuat', style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor)),
													],
												),
											),
										],
									),
								],
							),
						),
						const SizedBox(height: 32),
						
						Align(
							alignment: Alignment.centerLeft,
							child: Text('Pengaturan', style: theme.textTheme.titleMedium),
						),
						const SizedBox(height: 16),
						
						_buildSettingsTile(
							context: context,
							icon: isDark ? Icons.dark_mode : Icons.light_mode,
							title: 'Mode Gelap (Dark Mode)',
							subtitle: 'Ubah tampilan gelap/terang',
							subtitleColor: subtitleColor,
							trailing: Switch(
								value: isDark,
								activeThumbColor: theme.colorScheme.primary,
								onChanged: (value) => ref.read(themeProvider.notifier).toggleTheme(),
							),
						),
						const SizedBox(height: 12),
						
						if (!isAdmin) ...[
							_buildSettingsTile(
								context: context,
								icon: Icons.delete_forever,
								title: 'Hapus Semua Data',
								subtitle: 'Reset transaksi dan target tabungan',
								subtitleColor: subtitleColor,
								iconColor: const Color(0xFFEF4444),
								textColor: const Color(0xFFEF4444),
								onTap: () => _showResetConfirmationDialog(context, ref),
							),
							const SizedBox(height: 12),
						],
						
						_buildSettingsTile(
							context: context,
							icon: Icons.info_outline,
							title: 'Tentang Aplikasi',
							subtitle: 'SmartStudent Finance v1.0.0',
							subtitleColor: subtitleColor,
							onTap: () {
								showAboutDialog(
									context: context,
									applicationName: 'SmartStudent Finance',
									applicationVersion: '1.0.0',
									applicationIcon: Icon(Icons.account_balance_wallet, size: 50, color: theme.colorScheme.primary),
									children: const [
										Text('Aplikasi manajemen keuangan khusus mahasiswa dengan fitur pelacakan pengeluaran, struk cerdas, dan target tabungan.'),
									],
								);
							},
						),
						const SizedBox(height: 12),

						_buildSettingsTile(
							context: context,
							icon: Icons.logout_rounded,
							title: 'Keluar Akun',
							subtitle: 'Akhiri sesi dan kembali ke layar login',
							subtitleColor: subtitleColor,
							iconColor: const Color(0xFFEF4444),
							textColor: const Color(0xFFEF4444),
							onTap: () => _showLogoutDialog(context, ref),
						),
					],
				),
			),
		);
	}
	
	Widget _buildSettingsTile({
		required BuildContext context,
		required IconData icon,
		required String title,
		String? subtitle,
		Color? subtitleColor,
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
				padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
							padding: const EdgeInsets.all(12),
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
										style: theme.textTheme.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
									),
									if (subtitle != null) ...[
										const SizedBox(height: 4),
										Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor)),
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
	
	void _showResetConfirmationDialog(BuildContext context, WidgetRef ref) {
		showDialog(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: const Text('Peringatan!'),
					content: const Text(
						'Apakah kamu yakin ingin menghapus SELURUH data transaksi dan target tabungan dari Cloud? Data yang sudah dihapus tidak dapat dikembalikan.',
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context),
							child: const Text('Batal'),
						),
						FilledButton(
							style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
							onPressed: () async {
								// Tembak Firestore untuk hapus semua transaksi dan tabungan
								await ref.read(transactionProvider.notifier).clearAllData();
								await ref.read(goalProvider.notifier).clearAllGoals(); // <-- FUNGSI BARU DIPANGGIL DI SINI
								
								if (!context.mounted) return;
								Navigator.pop(context);
								ScaffoldMessenger.of(context).showSnackBar(
									const SnackBar(
										content: Text('Seluruh data di Cloud berhasil dibersihkan!'),
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

	void _showLogoutDialog(BuildContext context, WidgetRef ref) {
		showDialog(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: const Text('Keluar Akun'),
					content: const Text('Apakah Anda yakin ingin keluar dari aplikasi? Anda harus login kembali untuk masuk.'),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context),
							child: const Text('Batal'),
						),
						FilledButton(
							style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
							onPressed: () async {
								Navigator.pop(context);
								await ref.read(authProvider.notifier).signOut();
							},
							child: const Text('Keluar'),
						),
					],
				);
			},
		);
	}
}
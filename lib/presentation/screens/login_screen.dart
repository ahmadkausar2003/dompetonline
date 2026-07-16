import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
	const LoginScreen({super.key});
	
	@override
	ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
	final _formKey = GlobalKey<FormState>();
	final _emailController = TextEditingController();
	final _passwordController = TextEditingController();
	
	bool _isLogin = true; 
	bool _isPasswordVisible = false;
	
	@override
	void dispose() {
		_emailController.dispose();
		_passwordController.dispose();
		super.dispose();
	}
	
	void _submitAuth() async {
		if (!_formKey.currentState!.validate()) {
			return;
		}
		
		final email = _emailController.text.trim();
		final password = _passwordController.text.trim();
		
		if (_isLogin) {
			await ref.read(authProvider.notifier).signIn(email, password);
		} else {
			// ROLE OTOMATIS 'student' UNTUK SEMUA PENDAFTARAN DARI APLIKASI
			await ref.read(authProvider.notifier).signUp(email, password, 'student');
		}
		
		if (!mounted) {
			return;
		}
		
		final authState = ref.read(authProvider);
		if (authState.errorMessage != null) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(authState.errorMessage!),
					backgroundColor: const Color(0xFFEF4444), 
				),
			);
		}
	}
	
	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final authState = ref.watch(authProvider);
		
		return Scaffold(
			backgroundColor: theme.scaffoldBackgroundColor,
			body: SafeArea(
				child: Center(
					child: SingleChildScrollView(
						padding: const EdgeInsets.all(24.0),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Icon(
									Icons.account_balance_wallet_rounded,
									size: 80,
									color: theme.colorScheme.primary,
								),
								const SizedBox(height: 24),
								
								Text(
									_isLogin ? 'Selamat Datang' : 'Buat Akun Anak/Adik',
									style: theme.textTheme.headlineMedium?.copyWith(
										fontWeight: FontWeight.bold,
									),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 8),
								Text(
									_isLogin 
									? 'Masuk ke SmartStudent Finance' 
									: 'Mulai pantau keuangan dengan cerdas',
									style: theme.textTheme.bodyLarge?.copyWith(
										color: Colors.grey,
									),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 48),
								
								Container(
									padding: const EdgeInsets.all(24),
									decoration: BoxDecoration(
										color: theme.cardTheme.color,
										borderRadius: BorderRadius.circular(24),
										boxShadow: [
											BoxShadow(
												color: Colors.black.withValues(alpha: 0.05),
												blurRadius: 20,
												offset: const Offset(0, 10),
											),
										],
									),
									child: Form(
										key: _formKey,
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												TextFormField(
													controller: _emailController,
													keyboardType: TextInputType.emailAddress,
													decoration: InputDecoration(
														labelText: 'Alamat Email',
														prefixIcon: const Icon(Icons.email_outlined),
														border: OutlineInputBorder(
															borderRadius: BorderRadius.circular(16),
														),
													),
													validator: (value) {
														if (value == null || value.trim().isEmpty) {
															return 'Email tidak boleh kosong';
														}
														if (!value.contains('@')) {
															return 'Format email tidak valid';
														}
														return null;
													},
												),
												const SizedBox(height: 20),
												
												TextFormField(
													controller: _passwordController,
													obscureText: !_isPasswordVisible,
													decoration: InputDecoration(
														labelText: 'Kata Sandi',
														prefixIcon: const Icon(Icons.lock_outline_rounded),
														suffixIcon: IconButton(
															icon: Icon(
																_isPasswordVisible 
																? Icons.visibility_rounded 
																: Icons.visibility_off_rounded,
															),
															onPressed: () {
																setState(() {
																	_isPasswordVisible = !_isPasswordVisible;
																});
															},
														),
														border: OutlineInputBorder(
															borderRadius: BorderRadius.circular(16),
														),
													),
													validator: (value) {
														if (value == null || value.trim().isEmpty) {
															return 'Kata sandi tidak boleh kosong';
														}
														if (value.length < 6) {
															return 'Minimal 6 karakter';
														}
														return null;
													},
												),
												
												const SizedBox(height: 32),
												
												SizedBox(
													width: double.infinity,
													height: 56,
													child: FilledButton(
														onPressed: authState.isLoading ? null : _submitAuth,
														style: FilledButton.styleFrom(
															shape: RoundedRectangleBorder(
																borderRadius: BorderRadius.circular(16),
															),
														),
														child: authState.isLoading
														? const SizedBox(
															height: 24,
															width: 24,
															child: CircularProgressIndicator(
																color: Colors.white,
																strokeWidth: 3,
															),
														)
														: Text(
															_isLogin ? 'Masuk Sekarang' : 'Buat Akun',
															style: const TextStyle(
																fontSize: 16, 
																fontWeight: FontWeight.bold,
															),
														),
													),
												),
											],
										),
									),
								),
								
								const SizedBox(height: 24),
								
								TextButton(
									onPressed: () {
										setState(() {
											_isLogin = !_isLogin;
											_formKey.currentState?.reset();
											_emailController.clear();
											_passwordController.clear();
										});
									},
									child: Text(
										_isLogin 
										? 'Belum punya akun? Daftar di sini' 
										: 'Sudah punya akun? Masuk di sini',
										style: TextStyle(color: theme.colorScheme.primary),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:firebase_core/firebase_core.dart'; // IMPORT FIREBASE
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- TAMBAHAN: IMPORT FIRESTORE

import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/auth_provider.dart'; // IMPORT AUTH PROVIDER
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/login_screen.dart'; // IMPORT LOGIN SCREEN

void main() async {
  // Pastikan binding Flutter sudah siap sebelum inisialisasi lainnya
  WidgetsFlutterBinding.ensureInitialized();
  
  // INISIALISASI FIREBASE
  await Firebase.initializeApp();
  
  // --- MESIN OFFLINE (PENGGANTI SQLITE) DIAKTIFKAN DI SINI ---
  // Firebase akan otomatis menyimpan data di memori HP saat tidak ada kuota, 
  // lalu mengirimkannya ke awan saat kuota kembali!
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, 
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // ------------------------------------------------------------
  
  // MENGHIDUPKAN KAMUS BAHASA INDONESIA UNTUK FORMAT TANGGAL (INTL)
  await initializeDateFormatting('id_ID', null);
  
  // Mengatur warna status bar agar menyatu dengan aplikasi
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(
    // ProviderScope wajib ada di akar aplikasi agar Riverpod bisa bekerja
    const ProviderScope(
      child: SmartStudentFinanceApp(),
    ),
  );
}

class SmartStudentFinanceApp extends ConsumerWidget {
  const SmartStudentFinanceApp({super.key});

  // --- PALET WARNA UTAMA ---
  static const Color primaryEmerald = Color(0xFF10B981); 
  
  // Warna Latar & Kartu (Light Mode - Bright & Crisp)
  static const Color backgroundLight = Color(0xFFF8F9FA); 
  static const Color surfaceLight = Colors.white; 
  
  // Warna Latar & Kartu (Dark Mode - Matte & Deep)
  static const Color backgroundDark = Color(0xFF121212); 
  static const Color surfaceDark = Color(0xFF1E1E1E); 

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mendengarkan perubahan tema dari themeProvider
    final themeMode = ref.watch(themeProvider);
    // Mendengarkan status autentikasi user
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'SmartStudent Finance',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      
      // ==========================================
      // PENGATURAN TEMA TERANG (LIGHT MODE)
      // ==========================================
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryEmerald,
          primary: primaryEmerald,
          surface: surfaceLight,
          brightness: Brightness.light,
          onSurface: const Color(0xFF1A1A1A), 
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundLight,
          surfaceTintColor: Colors.transparent, 
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20,
            fontWeight: FontWeight.w700, 
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceLight,
          elevation: 0, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), 
            side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5), 
          ),
        ),
        fontFamily: 'Roboto', 
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A), letterSpacing: -1.0),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          bodyLarge: TextStyle(color: Color(0xFF475569)), 
          bodyMedium: TextStyle(color: Color(0xFF64748B)),
        ),
        splashFactory: InkSparkle.splashFactory,
      ),

      // ==========================================
      // PENGATURAN TEMA GELAP (DARK MODE)
      // ==========================================
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryEmerald,
          primary: primaryEmerald,
          surface: surfaceDark,
          brightness: Brightness.dark,
          onSurface: const Color(0xFFF8FAFC), 
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
          titleTextStyle: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF2D2D2D), width: 1), 
          ),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.0),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC)),
          bodyLarge: TextStyle(color: Color(0xFFCBD5E1)),
          bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
        ),
        splashFactory: InkSparkle.splashFactory,
      ),
      
      // ==========================================
      // LOGIKA ROUTING (PINTU MASUK)
      // ==========================================
      home: Builder(
        builder: (context) {
          // Tampilkan loading screen sementara Riverpod memeriksa status login
          if (authState.isLoading && authState.user == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: primaryEmerald),
              ),
            );
          }
          
          // Jika sudah login, arahkan ke MainScreen
          if (authState.user != null) {
            return const MainScreen();
          }
          
          // Jika belum login, arahkan ke LoginScreen
          return const LoginScreen();
        },
      ),
    );
  }
}
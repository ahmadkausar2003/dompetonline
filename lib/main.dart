import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  // Emerald Green yang modern dan segar
  static const Color primaryEmerald = Color(0xFF10B981); 
  
  // Warna Latar & Kartu (Light Mode)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Off-White (Soft)
  static const Color surfaceLight = Colors.white; // Pure White untuk kartu
  
  // Warna Latar & Kartu (Dark Mode)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate Dark (Elegan, tidak terlalu hitam pekat)
  static const Color surfaceDark = Color(0xFF1E293B); // Slate Gray untuk kartu

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mendengarkan perubahan tema dari themeProvider
    final themeMode = ref.watch(themeProvider);

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
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundLight,
          surfaceTintColor: Colors.transparent, // Mencegah warna berubah saat di-scroll
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceLight,
          elevation: 0, // Menggunakan Neumorphism / Shadow halus dari Container nanti, atau border tipis
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        fontFamily: 'Roboto', // Bisa diganti 'Poppins' atau 'Inter' jika menggunakan google_fonts
        textTheme: const TextTheme(
          // Headline untuk angka saldo yang besar
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -1.0),
          // Title untuk label kategori/judul transaksi
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          // Body untuk deskripsi dan tanggal
          bodyMedium: TextStyle(color: Colors.black54),
        ),
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
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.0),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      
      // Perubahan penting: Mengarahkan ke MainScreen sebagai kerangka navigasi
      home: const MainScreen(),
    );
  }
}
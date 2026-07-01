import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'smart_student_theme_mode';

  @override
  ThemeMode build() {
    // Memuat preferensi tema di latar belakang tanpa memblokir inisialisasi awal
    _loadTheme();
    // Kembalikan nilai default terlebih dahulu
    return ThemeMode.system;
  }

  // Membaca preferensi tema dari penyimpanan lokal saat aplikasi dibuka
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey);
    
    if (isDark != null) {
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  // Method untuk mengganti tema (digunakan di Profile & Settings Screen)
  Future<void> toggleTheme() async {
    final isDark = state == ThemeMode.dark;
    
    // Ganti state Riverpod
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    
    // Simpan pilihan ke penyimpanan lokal
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, !isDark);
  }
}

// Provider yang akan digunakan di MaterialApp
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
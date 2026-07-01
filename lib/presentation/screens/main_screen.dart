import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'statistics_screen.dart';
import 'budget_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Daftar layar yang akan ditampilkan berdasarkan tab yang dipilih
  final List<Widget> _screens = [
    const DashboardScreen(),
    const StatisticsScreen(),
    const BudgetScreen(), // Mengganti placeholder dengan layar sebenarnya
    // Placeholder untuk layar Profile/Settings (Akan kita buat selanjutnya)
    const Scaffold(body: Center(child: Text('Layar Profil (Segera Hadir)'))),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // IndexedStack digunakan agar state (seperti posisi scroll) tiap layar tidak hilang saat pindah tab
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      // Menggunakan NavigationBar standar Material 3
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes),
            label: 'Target',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
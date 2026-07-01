import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplikasi_keuangan_mahasiswa/main.dart';

void main() {
  testWidgets('Aplikasi dapat diluncurkan tanpa error', (WidgetTester tester) async {
    // Build aplikasi kita. Jangan lupa dibungkus ProviderScope karena kita pakai Riverpod.
    await tester.pumpWidget(const ProviderScope(child: SmartStudentFinanceApp()));

    // Verifikasi bahwa aplikasi berhasil dirender (mencari AppBar dengan judul aplikasi kita)
    expect(find.text('SmartStudent Finance'), findsOneWidget);
  });
}
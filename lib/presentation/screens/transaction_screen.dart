import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key});

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _locationController = TextEditingController(); 

  String _selectedType = 'expense';
  DateTime _selectedDate = DateTime.now();
  File? _receiptImage; 

  // Penambahan List Default sesuai permintaan
  final List<String> _baseExpenseCategories = [
    'Makanan', 'Kos', 'Transportasi', 'Tugas Kuliah', 'Nongkrong', 
    'Belanja', 'Hiburan', 'Tagihan', 'Kesehatan', 'Olahraga', 'Lainnya'
  ];
  final List<String> _baseIncomeCategories = [
    'Uang Saku', 'Gaji Part-time', 'Bonus', 'Investasi', 'Hadiah', 'Lainnya'
  ];

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _baseExpenseCategories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- FUNGSI KAMERA & GALERI ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70, // Kompresi agar database tidak bengkak
      );

      if (pickedFile != null) {
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    // Menghapus titik/karakter selain angka sebelum disimpan ke database
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari Rp 0')),
      );
      return;
    }

    final newTransaction = TransactionModel(
      title: _titleController.text.trim(),
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      date: _selectedDate,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      imagePath: _receiptImage?.path, // Menyimpan path lokal foto
    );

    await ref.read(transactionProvider.notifier).addTransaction(newTransaction);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_selectedCategory berhasil dicatat!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Dialog Tambah Kategori Manual
  void _showAddCategoryDialog(String type) {
    final customCatController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori Baru'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: customCatController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Contoh: Modal Usaha',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) 
                ? 'Tidak boleh kosong' 
                : null,
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
                final newCat = customCatController.text.trim();
                
                // Panggil provider untuk menyimpan kategori
                ref.read(transactionProvider.notifier).addCustomCategory(newCat, type);
                
                setState(() {
                  _selectedCategory = newCat;
                });
                
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(transactionProvider);
    
    final isIncome = _selectedType == 'income';
    final activeColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    // Menggabungkan list bawaan dan custom
    List<String> currentCategories = isIncome
        ? [..._baseIncomeCategories, ...state.customIncomeCategories]
        : [..._baseExpenseCategories, ...state.customExpenseCategories];
        
    // Hilangkan duplikat jika ada dan tambahkan opsi "Tambah Manual"
    currentCategories = currentCategories.toSet().toList();
    currentCategories.add('+ Tambah Kategori...');

    // Keamanan UI: Pastikan _selectedCategory valid ada di List, jika tidak reset ke yang pertama
    if (!currentCategories.contains(_selectedCategory) && _selectedCategory != '+ Tambah Kategori...') {
       _selectedCategory = currentCategories.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tipe Transaksi
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text('Pengeluaran'),
                        icon: Icon(Icons.arrow_upward_rounded),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('Pemasukan'),
                        icon: Icon(Icons.arrow_downward_rounded),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                        _selectedCategory = _selectedType == 'expense' 
                            ? _baseExpenseCategories.first 
                            : _baseIncomeCategories.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: activeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // 2. Input Nominal
                Text('Nominal', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: theme.textTheme.headlineLarge?.copyWith(fontSize: 28, color: Colors.grey),
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.light 
                        ? const Color(0xFFF1F5F9) 
                        : const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Nominal tidak boleh kosong' : null,
                ),
                const SizedBox(height: 24),
                
                // 3. Input Judul / Catatan
                Text('Catatan / Judul', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: isIncome ? 'Contoh: Transfer dari Ibu' : 'Contoh: Makan Siang di Kantin',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.light 
                        ? const Color(0xFFF1F5F9) 
                        : const Color(0xFF1E293B),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Judul transaksi wajib diisi' : null,
                ),
                const SizedBox(height: 24),
                
                // 4. Input Lokasi (Opsional)
                Text('Lokasi (Opsional)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Warteg Berkah',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.light 
                        ? const Color(0xFFF1F5F9) 
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 5. Kategori & Tanggal
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kategori', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.light 
                                  ? const Color(0xFFF1F5F9) 
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                items: currentCategories.map((String category) {
                                  final isAddAction = category == '+ Tambah Kategori...';
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: isAddAction ? theme.colorScheme.primary : null,
                                        fontWeight: isAddAction ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue == null) return;
                                  
                                  if (newValue == '+ Tambah Kategori...') {
                                    _showAddCategoryDialog(_selectedType);
                                  } else {
                                    setState(() => _selectedCategory = newValue);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tanggal', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.light 
                                    ? const Color(0xFFF1F5F9) 
                                    : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(_selectedDate),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 6. Unggah Struk / Bukti (Opsional)
                Text('Bukti Transaksi (Opsional)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_receiptImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _receiptImage!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: () => setState(() => _receiptImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Kamera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Galeri'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                const SizedBox(height: 48),
                
                // 7. Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Simpan Transaksi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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

/// Custom formatter untuk menambahkan titik pemisah ribuan secara real-time
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Hanya ambil karakter angka murni
    String numericOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (numericOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Format angka menggunakan titik ribuan bergaya Indonesia (id_ID)
    final formatter = NumberFormat.decimalPattern('id_ID');
    String newText = formatter.format(int.parse(numericOnly));
    
    // Kembalikan value dengan penempatan kursor di akhir text
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
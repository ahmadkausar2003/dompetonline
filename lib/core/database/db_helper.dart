import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/goal_model.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  static const String _tableTransactions = 'transactions';
  static const String _tableGoals = 'goals';
  static const String _tableGoalLogs = 'goal_logs';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'smart_student_finance.db');
    return await openDatabase(
      path,
      version: 3, // VERSI 3: Menambahkan Fitur Target Mandiri
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Transaksi Utama
    await db.execute('''
      CREATE TABLE $_tableTransactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        imagePath TEXT,
        location TEXT
      )
    ''');
    
    // Tabel Target Tabungan
    await db.execute('''
      CREATE TABLE $_tableGoals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        savedAmount REAL NOT NULL
      )
    ''');

    // Tabel Log Target Tabungan
    await db.execute('''
      CREATE TABLE $_tableGoalLogs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goalId INTEGER NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        note TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $_tableTransactions ADD COLUMN imagePath TEXT');
      await db.execute('ALTER TABLE $_tableTransactions ADD COLUMN location TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $_tableGoals(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          targetAmount REAL NOT NULL,
          savedAmount REAL NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE $_tableGoalLogs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goalId INTEGER NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          note TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');
    }
  }

  // --- CRUD TRANSAKSI UTAMA (Tetap Sama) ---
  Future<int> insertTransaction(TransactionModel transaction) async {
    Database db = await instance.database;
    return await db.insert(_tableTransactions, transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<TransactionModel>> getAllTransactions() async {
    Database db = await instance.database;
    final maps = await db.query(_tableTransactions, orderBy: 'date DESC');
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }
  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    Database db = await instance.database;
    final maps = await db.query(_tableTransactions, where: 'date >= ? AND date <= ?', whereArgs: [start.toIso8601String(), end.toIso8601String()], orderBy: 'date DESC');
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }
  Future<int> updateTransaction(TransactionModel transaction) async {
    Database db = await instance.database;
    return await db.update(_tableTransactions, transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id]);
  }
  Future<int> deleteTransaction(int id) async {
    Database db = await instance.database;
    return await db.delete(_tableTransactions, where: 'id = ?', whereArgs: [id]);
  }
  Future<double> getLifetimeIncome() async {
    Database db = await instance.database;
    var res = await db.rawQuery('SELECT SUM(amount) as total FROM $_tableTransactions WHERE type = "income"');
    return res.isNotEmpty && res.first['total'] != null ? res.first['total'] as double : 0.0;
  }
  Future<double> getLifetimeExpense() async {
    Database db = await instance.database;
    var res = await db.rawQuery('SELECT SUM(amount) as total FROM $_tableTransactions WHERE type = "expense"');
    return res.isNotEmpty && res.first['total'] != null ? res.first['total'] as double : 0.0;
  }
  Future<double> getTotalIncome(DateTime start, DateTime end) async {
    Database db = await instance.database;
    var res = await db.rawQuery('SELECT SUM(amount) as total FROM $_tableTransactions WHERE type = "income" AND date >= ? AND date <= ?', [start.toIso8601String(), end.toIso8601String()]);
    return res.isNotEmpty && res.first['total'] != null ? res.first['total'] as double : 0.0;
  }
  Future<double> getTotalExpense(DateTime start, DateTime end) async {
    Database db = await instance.database;
    var res = await db.rawQuery('SELECT SUM(amount) as total FROM $_tableTransactions WHERE type = "expense" AND date >= ? AND date <= ?', [start.toIso8601String(), end.toIso8601String()]);
    return res.isNotEmpty && res.first['total'] != null ? res.first['total'] as double : 0.0;
  }
  Future<void> clearAllData() async {
    Database db = await instance.database;
    await db.delete(_tableTransactions);
    await db.delete(_tableGoals);
    await db.delete(_tableGoalLogs);
  }

  // --- CRUD TARGET TABUNGAN (BARU) ---
  Future<int> insertGoal(GoalModel goal) async {
    Database db = await instance.database;
    return await db.insert(_tableGoals, goal.toMap());
  }
  Future<List<GoalModel>> getAllGoals() async {
    Database db = await instance.database;
    final maps = await db.query(_tableGoals, orderBy: 'id DESC');
    return List.generate(maps.length, (i) => GoalModel.fromMap(maps[i]));
  }
  Future<int> updateGoal(GoalModel goal) async {
    Database db = await instance.database;
    return await db.update(_tableGoals, goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }
  Future<int> deleteGoal(int id) async {
    Database db = await instance.database;
    await db.delete(_tableGoalLogs, where: 'goalId = ?', whereArgs: [id]); // Hapus log-nya juga
    return await db.delete(_tableGoals, where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD LOG TARGET TABUNGAN (BARU) ---
  Future<int> insertGoalLog(GoalLogModel log) async {
    Database db = await instance.database;
    return await db.insert(_tableGoalLogs, log.toMap());
  }
  Future<List<GoalLogModel>> getGoalLogs(int goalId) async {
    Database db = await instance.database;
    final maps = await db.query(_tableGoalLogs, where: 'goalId = ?', whereArgs: [goalId], orderBy: 'date DESC');
    return List.generate(maps.length, (i) => GoalLogModel.fromMap(maps[i]));
  }
}
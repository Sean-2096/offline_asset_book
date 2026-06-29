import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('offline_asset_book.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        include_in_assets INTEGER NOT NULL DEFAULT 1,
        nature TEXT NOT NULL DEFAULT 'asset',
        note TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await _createSettingsTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSettingsTable(db);
    }
    if (oldVersion < 3) {
      await _addIncludeInAssetsColumn(db);
    }
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _addIncludeInAssetsColumn(Database db) async {
    await db.execute('''
      ALTER TABLE accounts
      ADD COLUMN include_in_assets INTEGER NOT NULL DEFAULT 1
    ''');
  }

  Future<String> insertAccount(Account account) async {
    final db = await database;
    await db.insert(
      'accounts',
      _toDatabaseMap(account),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return account.id;
  }

  Future<List<Account>> getAllAccounts() async {
    final db = await database;
    final maps = await db.query('accounts', orderBy: 'created_at DESC');
    return maps.map(Account.fromMap).toList();
  }

  Future<Account?> getAccount(String id) async {
    final db = await database;
    final maps = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return db.update(
      'accounts',
      _toDatabaseMap(account),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await database;
    return db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAccounts(Set<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.delete(
      'accounts',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('accounts');
  }

  Future<void> replaceAccounts(List<Account> accounts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('accounts');
      for (final account in accounts) {
        await txn.insert(
          'accounts',
          _toDatabaseMap(account),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _toDatabaseMap(Account account) {
    return {
      ...account.toMap(),
      // Keep the legacy column populated for users upgrading from the old
      // schema where nature was NOT NULL.
      'nature': 'asset',
    };
  }
}

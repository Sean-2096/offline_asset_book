import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../database/database_helper.dart';

class AccountProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  List<Account> _accounts = [];
  bool _loading = true;

  List<Account> get accounts => _accounts;
  bool get loading => _loading;

  // --- 计算属性 ---

  double get totalAssets {
    return _accounts
        .where((a) => a.includeInAssets && a.balance > 0)
        .fold(0.0, (sum, a) => sum + a.balance);
  }

  double get totalLiabilities {
    return _accounts
        .where((a) => a.includeInAssets && a.balance < 0)
        .fold(0.0, (sum, a) => sum + a.balance.abs());
  }

  double get netWorth {
    return _accounts
        .where((a) => a.includeInAssets)
        .fold(0.0, (sum, a) => sum + a.balance);
  }

  int get accountCount => _accounts.length;

  // --- 操作 ---

  Future<void> loadAccounts() async {
    _loading = true;
    notifyListeners();
    _accounts = await _db.getAllAccounts();
    _loading = false;
    notifyListeners();
  }

  Future<void> addAccount({
    required String name,
    required String accountType,
    required double balance,
    bool includeInAssets = true,
    String? note,
  }) async {
    final account = Account(
      id: _uuid.v4(),
      name: name,
      accountType: accountType,
      balance: balance,
      includeInAssets: includeInAssets,
      note: note,
      createdAt: DateTime.now(),
    );
    await _db.insertAccount(account);
    await loadAccounts();
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String accountType,
    required double balance,
    required bool includeInAssets,
    String? note,
  }) async {
    final existing = await _db.getAccount(id);
    if (existing == null) return;

    final updated = existing.copyWith(
      name: name,
      accountType: accountType,
      balance: balance,
      includeInAssets: includeInAssets,
      note: note,
    );
    await _db.updateAccount(updated);
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> deleteAccounts(Set<String> ids) async {
    if (ids.isEmpty) return;
    await _db.deleteAccounts(ids);
    await loadAccounts();
  }

  Future<void> replaceAccounts(List<Account> accounts) async {
    await _db.replaceAccounts(accounts);
    await loadAccounts();
  }

  /// 清空所有账户（用于测试清理）
  Future<void> clearAll() async {
    await _db.clearAll();
    _accounts = [];
    notifyListeners();
  }
}

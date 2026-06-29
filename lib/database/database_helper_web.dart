// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../models/account.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const _storageKey = 'offline_asset_book.accounts';
  static const _settingPrefix = 'offline_asset_book.setting.';

  DatabaseHelper._init();

  Future<String> insertAccount(Account account) async {
    final accounts = _readAccounts();
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      accounts.add(account);
    } else {
      accounts[index] = account;
    }
    _writeAccounts(accounts);
    return account.id;
  }

  Future<List<Account>> getAllAccounts() async {
    final accounts = _readAccounts()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return accounts;
  }

  Future<Account?> getAccount(String id) async {
    for (final account in _readAccounts()) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<int> updateAccount(Account account) async {
    final accounts = _readAccounts();
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) return 0;

    accounts[index] = account;
    _writeAccounts(accounts);
    return 1;
  }

  Future<int> deleteAccount(String id) async {
    final accounts = _readAccounts();
    final before = accounts.length;
    accounts.removeWhere((account) => account.id == id);
    _writeAccounts(accounts);
    return before - accounts.length;
  }

  Future<int> deleteAccounts(Set<String> ids) async {
    if (ids.isEmpty) return 0;
    final accounts = _readAccounts();
    final before = accounts.length;
    accounts.removeWhere((account) => ids.contains(account.id));
    _writeAccounts(accounts);
    return before - accounts.length;
  }

  Future<void> clearAll() async {
    html.window.localStorage.remove(_storageKey);
  }

  Future<void> replaceAccounts(List<Account> accounts) async {
    _writeAccounts(accounts);
  }

  Future<String?> getSetting(String key) async {
    return html.window.localStorage['$_settingPrefix$key'];
  }

  Future<void> setSetting(String key, String value) async {
    html.window.localStorage['$_settingPrefix$key'] = value;
  }

  List<Account> _readAccounts() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((item) => Account.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  void _writeAccounts(List<Account> accounts) {
    final encoded = jsonEncode(
      accounts.map((account) => account.toMap()).toList(),
    );
    html.window.localStorage[_storageKey] = encoded;
  }
}

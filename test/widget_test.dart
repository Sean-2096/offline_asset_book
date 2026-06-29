import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_asset_book/models/account.dart';
import 'package:offline_asset_book/providers/account_provider.dart';

void main() {
  late AccountProvider provider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    provider = AccountProvider();
    await provider.clearAll();
  });

  test('Account model serialization', () {
    final account = Account(
      id: 'test-id',
      name: '招行工资卡',
      accountType: '储蓄卡',
      balance: -50000.0,
      note: '工资卡',
      createdAt: DateTime(2026, 6, 1),
    );

    final map = account.toMap();
    expect(map['name'], '招行工资卡');
    expect(map['account_type'], '储蓄卡');
    expect(map['balance'], -50000.0);
    expect(map.containsKey('nature'), isFalse);

    final restored = Account.fromMap(map);
    expect(restored.name, account.name);
    expect(restored.balance, account.balance);
  });

  test('AccountProvider computes totals correctly', () async {
    await provider.addAccount(
      name: '储蓄卡',
      accountType: '银行卡',
      balance: 100000,
    );

    await provider.addAccount(
      name: '信用卡',
      accountType: '信用卡',
      balance: -5000,
    );

    await provider.addAccount(
      name: '借给朋友',
      accountType: '借贷',
      balance: 3000,
    );

    await provider.addAccount(
      name: '借入',
      accountType: '借贷',
      balance: -2000,
    );

    expect(provider.totalAssets, 103000.0);
    expect(provider.totalLiabilities, 7000.0);
    expect(provider.netWorth, 96000.0);
  });

  test('AccountProvider CRUD operations', () async {
    // Initial state
    expect(provider.accounts.length, 0);
    expect(provider.totalAssets, 0.0);
    expect(provider.netWorth, 0.0);

    // Add
    await provider.addAccount(
      name: '微信零钱',
      accountType: '微信',
      balance: -500,
    );
    expect(provider.accounts.length, 1);
    expect(provider.totalLiabilities, 500.0);
    expect(provider.netWorth, -500.0);

    // Delete
    final id = provider.accounts.first.id;
    await provider.deleteAccount(id);
    expect(provider.accounts.length, 0);
    expect(provider.totalAssets, 0.0);
  });
}

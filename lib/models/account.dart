/// 常用账户类型预设
const presetAccountTypes = [
  '信用卡',
  '储蓄卡',
  '微信',
  '支付宝',
  '现金',
  '投资账户',
  '借出款',
  '借入款',
  '房贷',
  '车贷',
  '花呗',
  '借呗',
];

class Account {
  final String id;
  final String name;
  final String accountType;
  final double balance;
  final bool includeInAssets;
  final String? note;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.balance,
    this.includeInAssets = true,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'account_type': accountType,
        'balance': balance,
        'include_in_assets': includeInAssets ? 1 : 0,
        'note': note ?? '',
        'created_at': createdAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      accountType: map['account_type'] as String,
      balance: (map['balance'] as num).toDouble(),
      includeInAssets: _parseIncludeInAssets(map['include_in_assets']),
      note: (map['note'] as String?)?.isEmpty ?? true
          ? null
          : map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? accountType,
    double? balance,
    bool? includeInAssets,
    String? note,
    DateTime? createdAt,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        accountType: accountType ?? this.accountType,
        balance: balance ?? this.balance,
        includeInAssets: includeInAssets ?? this.includeInAssets,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  static bool _parseIncludeInAssets(Object? raw) {
    return switch (raw) {
      bool value => value,
      int value => value != 0,
      num value => value != 0,
      String value => value != '0' && value.toLowerCase() != 'false',
      _ => true,
    };
  }
}

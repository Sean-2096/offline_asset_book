import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/account.dart';

class BackupCodec {
  static const format = 'offline_asset_book_encrypted_backup';
  static const version = 1;
  static const _iterations = 60000;

  String encode({
    required List<Account> accounts,
    required String password,
  }) {
    final normalizedPassword = password.trim();
    if (normalizedPassword.length < 6) {
      throw const FormatException('密码至少需要 6 位');
    }

    final salt = _randomBytes(16);
    final key = _deriveKey(normalizedPassword, salt);
    final plainText = jsonEncode({
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': accounts.map((account) => account.toMap()).toList(),
    });
    final cipherBytes = _xorWithKeyStream(utf8.encode(plainText), key);
    final cipherText = base64Encode(cipherBytes);
    final saltText = base64Encode(salt);
    final mac = _mac(key, '$saltText.$cipherText');

    return jsonEncode({
      'format': format,
      'version': version,
      'kdf': {
        'name': 'sha256-iterated',
        'iterations': _iterations,
        'salt': saltText,
      },
      'cipher': 'sha256-hmac-stream-xor',
      'ciphertext': cipherText,
      'mac': mac,
    });
  }

  List<Account> decode({
    required String encryptedText,
    required String password,
  }) {
    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      throw const FormatException('请输入解密密码');
    }

    final envelope = jsonDecode(encryptedText);
    if (envelope is! Map || envelope['format'] != format) {
      throw const FormatException('备份文件格式不正确');
    }

    final kdf = envelope['kdf'];
    if (kdf is! Map || kdf['salt'] is! String) {
      throw const FormatException('备份文件缺少密钥信息');
    }

    final saltText = kdf['salt'] as String;
    final cipherText = envelope['ciphertext'];
    final expectedMac = envelope['mac'];
    if (cipherText is! String || expectedMac is! String) {
      throw const FormatException('备份文件内容不完整');
    }

    final key = _deriveKey(normalizedPassword, base64Decode(saltText));
    final actualMac = _mac(key, '$saltText.$cipherText');
    if (actualMac != expectedMac) {
      throw const FormatException('密码错误或备份文件已损坏');
    }

    final plainBytes = _xorWithKeyStream(base64Decode(cipherText), key);
    final payload = jsonDecode(utf8.decode(plainBytes));
    if (payload is! Map || payload['accounts'] is! List) {
      throw const FormatException('备份数据内容不正确');
    }

    return (payload['accounts'] as List)
        .whereType<Map>()
        .map((item) => Account.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Uint8List _deriveKey(String password, List<int> salt) {
    var digest = sha256.convert([...utf8.encode(password), ...salt]).bytes;
    for (var i = 0; i < _iterations; i++) {
      digest =
          sha256.convert([...digest, ...salt, ...utf8.encode(password)]).bytes;
    }
    return Uint8List.fromList(digest);
  }

  Uint8List _xorWithKeyStream(List<int> input, List<int> key) {
    final output = Uint8List(input.length);
    var offset = 0;
    var counter = 0;

    while (offset < input.length) {
      final block = Hmac(sha256, key)
          .convert(utf8.encode('asset-book-backup:$counter'))
          .bytes;
      for (final byte in block) {
        if (offset >= input.length) break;
        output[offset] = input[offset] ^ byte;
        offset += 1;
      }
      counter += 1;
    }

    return output;
  }

  String _mac(List<int> key, String body) {
    return Hmac(sha256, key).convert(utf8.encode(body)).toString();
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

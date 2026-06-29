import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

const _backupTypeGroup = XTypeGroup(
  label: '资产账本备份',
  extensions: ['assetbook', 'json'],
  mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
);

const _androidBackupChannel = MethodChannel('offline_asset_book/backup_file');

class BackupFileSaveResult {
  final String fileName;
  final String? path;
  final bool selectedLocation;
  final bool cancelled;

  const BackupFileSaveResult({
    required this.fileName,
    this.path,
    required this.selectedLocation,
    this.cancelled = false,
  });

  const BackupFileSaveResult.cancelled()
      : fileName = '',
        path = null,
        selectedLocation = false,
        cancelled = true;
}

abstract class BackupFileSaveDestination {
  String get fileName;
  String? get path;
  bool get selectedLocation;

  Future<BackupFileSaveResult> write(String contents);
}

class _IoBackupFileSaveDestination implements BackupFileSaveDestination {
  @override
  final String fileName;

  @override
  final String path;

  const _IoBackupFileSaveDestination({
    required this.fileName,
    required this.path,
  });

  @override
  bool get selectedLocation => true;

  @override
  Future<BackupFileSaveResult> write(String contents) async {
    final file = XFile.fromData(
      utf8.encode(contents),
      mimeType: 'application/json',
      name: fileName,
    );
    await file.saveTo(path);
    return BackupFileSaveResult(
      fileName: fileName,
      path: path,
      selectedLocation: true,
    );
  }
}

class _AndroidBackupFileSaveDestination implements BackupFileSaveDestination {
  @override
  final String fileName;

  final String uri;

  const _AndroidBackupFileSaveDestination({
    required this.fileName,
    required this.uri,
  });

  @override
  String? get path => null;

  @override
  bool get selectedLocation => true;

  @override
  Future<BackupFileSaveResult> write(String contents) async {
    await _androidBackupChannel.invokeMethod<void>(
      'writeBackupToUri',
      {
        'uri': uri,
        'contents': contents,
      },
    );
    return BackupFileSaveResult(
      fileName: fileName,
      selectedLocation: true,
    );
  }
}

Future<BackupFileSaveDestination?> chooseBackupFileDestination({
  required String fileName,
}) async {
  if (Platform.isAndroid) {
    final result = await _androidBackupChannel.invokeMapMethod<String, String>(
      'chooseBackupDestination',
      {'fileName': fileName},
    );
    if (result == null) return null;
    final uri = result['uri'];
    if (uri == null || uri.isEmpty) return null;

    return _AndroidBackupFileSaveDestination(
      fileName: result['fileName'] ?? fileName,
      uri: uri,
    );
  }

  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: const [_backupTypeGroup],
  );
  if (location == null) return null;

  return _IoBackupFileSaveDestination(
    fileName: fileName,
    path: location.path,
  );
}

Future<BackupFileSaveResult> downloadBackupFile({
  required String fileName,
  required String contents,
}) async {
  final destination = await chooseBackupFileDestination(fileName: fileName);
  if (destination == null) return const BackupFileSaveResult.cancelled();
  return destination.write(contents);
}

Future<String?> pickBackupFileText({void Function()? onFileSelected}) async {
  final file = await openFile(
    acceptedTypeGroups: const [_backupTypeGroup],
    confirmButtonText: '选择备份',
  );
  if (file == null) return null;

  onFileSelected?.call();
  return file.readAsString(encoding: utf8);
}

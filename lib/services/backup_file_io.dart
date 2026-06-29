Future<void> downloadBackupFile({
  required String fileName,
  required String contents,
}) async {
  throw UnsupportedError('当前平台暂不支持文件导出，请使用 Web 调试版导出。');
}

Future<String?> pickBackupFileText() async {
  throw UnsupportedError('当前平台暂不支持文件导入，请使用 Web 调试版导入。');
}

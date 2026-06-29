// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<void> downloadBackupFile({
  required String fileName,
  required String contents,
}) async {
  final blob = html.Blob([contents], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String?> pickBackupFileText() async {
  final input = html.FileUploadInputElement()
    ..accept = '.assetbook,application/json,text/plain';
  input.click();

  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  final reader = html.FileReader();
  final completer = Completer<String?>();
  reader.onLoad.listen((_) => completer.complete(reader.result as String?));
  reader.onError.listen((_) => completer.completeError(reader.error!));
  reader.readAsText(file);
  return completer.future;
}

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

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

class _WebPickerBackupFileDestination implements BackupFileSaveDestination {
  final JSObject _handle;

  @override
  final String fileName;

  const _WebPickerBackupFileDestination({
    required JSObject handle,
    required this.fileName,
  }) : _handle = handle;

  @override
  String? get path => null;

  @override
  bool get selectedLocation => true;

  @override
  Future<BackupFileSaveResult> write(String contents) async {
    final writable = await _handle
        .callMethod<JSPromise<JSObject>>('createWritable'.toJS)
        .toDart;
    await writable
        .callMethod<JSPromise<JSAny?>>('write'.toJS, contents.toJS)
        .toDart;
    await writable.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
    return BackupFileSaveResult(
      fileName: fileName,
      selectedLocation: true,
    );
  }
}

class _WebDownloadBackupFileDestination implements BackupFileSaveDestination {
  @override
  final String fileName;

  const _WebDownloadBackupFileDestination({required this.fileName});

  @override
  String? get path => null;

  @override
  bool get selectedLocation => false;

  @override
  Future<BackupFileSaveResult> write(String contents) async {
    final blob = html.Blob([contents], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return BackupFileSaveResult(
      fileName: fileName,
      selectedLocation: false,
    );
  }
}

Future<BackupFileSaveDestination?> chooseBackupFileDestination({
  required String fileName,
}) async {
  if (_window.has('showSaveFilePicker')) {
    try {
      final options = {
        'suggestedName': fileName,
        'types': [
          {
            'description': '资产账本备份',
            'accept': {
              'application/json': ['.assetbook'],
            },
          },
        ],
      }.jsify() as JSObject;
      final handle = await _window
          .callMethod<JSPromise<JSObject>>(
            'showSaveFilePicker'.toJS,
            options,
          )
          .toDart;
      return _WebPickerBackupFileDestination(
        handle: handle,
        fileName: fileName,
      );
    } catch (error) {
      final errorName = error is JSObject
          ? (error['name'] as JSString?)?.toDart
          : error.toString();
      if (errorName == 'AbortError') {
        return null;
      }
    }
  }

  return _WebDownloadBackupFileDestination(fileName: fileName);
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
  final input = html.FileUploadInputElement()
    ..accept = '.assetbook,application/json,text/plain';
  input.click();

  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  onFileSelected?.call();
  final reader = html.FileReader();
  final completer = Completer<String?>();
  reader.onLoad.listen((_) => completer.complete(reader.result as String?));
  reader.onError.listen((_) => completer.completeError(reader.error!));
  reader.readAsText(file);
  return completer.future;
}

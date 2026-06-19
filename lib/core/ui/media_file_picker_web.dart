import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class PickedMediaFile {
  const PickedMediaFile({
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.base64Data,
  });

  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String base64Data;
}

Future<PickedMediaFile?> pickMediaFile({String? accept}) async {
  final completer = Completer<PickedMediaFile?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..style.display = 'none';

  if (accept != null && accept.trim().isNotEmpty) {
    input.accept = accept.trim();
  }

  void completeOnce(PickedMediaFile? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  void completeErrorOnce(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void cleanup() {
    input.remove();
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      final file = files == null || files.length == 0 ? null : files.item(0);
      if (file == null) {
        cleanup();
        completeOnce(null);
        return;
      }

      final reader = web.FileReader();

      reader.addEventListener(
        'load',
        ((web.Event _) {
          final rawResult = reader.result;
          final result = rawResult == null ? '' : (rawResult as JSString).toDart;
          final commaIndex = result.indexOf(',');
          final base64Data = commaIndex >= 0 ? result.substring(commaIndex + 1) : result;

          cleanup();
          completeOnce(
            PickedMediaFile(
              filename: file.name,
              mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
              sizeBytes: file.size.toInt(),
              base64Data: base64Data,
            ),
          );
        }).toJS,
      );

      reader.addEventListener(
        'error',
        ((web.Event _) {
          cleanup();
          completeErrorOnce(StateError('Failed to read selected file'));
        }).toJS,
      );

      reader.readAsDataURL(file);
    }).toJS,
  );

  web.document.body?.append(input);
  input.click();
  return completer.future;
}

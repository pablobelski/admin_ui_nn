import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void openMediaUrl(
  String url, {
  String target = '_blank',
  bool keepCurrentFocus = false,
}) {
  if (url.trim().isEmpty) return;
  final openedWindow = web.window.open(url, target);
  if (keepCurrentFocus) {
    openedWindow?.blur();
    web.window.focus();
  } else {
    openedWindow?.focus();
  }
}

void downloadMediaUrl(String url, {String? filename}) {
  if (url.trim().isEmpty) return;
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..target = '_blank'
    ..style.display = 'none';

  final normalizedFilename = filename?.trim();
  if (normalizedFilename != null && normalizedFilename.isNotEmpty) {
    anchor.download = normalizedFilename;
  }

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

void openMediaBytes(
  Uint8List bytes, {
  String? filename,
  String? contentType,
}) {
  if (bytes.isEmpty) return;
  final url = _objectUrl(bytes, contentType);
  web.window.open(url, '_blank');
  Future<void>.delayed(const Duration(seconds: 30), () {
    web.URL.revokeObjectURL(url);
  });
}

void downloadMediaBytes(
  Uint8List bytes, {
  String? filename,
  String? contentType,
}) {
  if (bytes.isEmpty) return;
  final url = _objectUrl(bytes, contentType);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..style.display = 'none';

  final normalizedFilename = filename?.trim();
  if (normalizedFilename != null && normalizedFilename.isNotEmpty) {
    anchor.download = normalizedFilename;
  }

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(const Duration(seconds: 1), () {
    web.URL.revokeObjectURL(url);
  });
}

String _objectUrl(Uint8List bytes, String? contentType) {
  final normalizedContentType = contentType?.trim();
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(
      type: normalizedContentType == null || normalizedContentType.isEmpty
          ? 'application/octet-stream'
          : normalizedContentType,
    ),
  );
  return web.URL.createObjectURL(blob);
}

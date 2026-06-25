import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void openMediaUrl(String url) {
  if (url.trim().isEmpty) return;
  web.window.open(url, '_blank');
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


void downloadMediaBytes(
  Uint8List bytes, {
  String? filename,
  String? contentType,
}) {
  if (bytes.isEmpty) return;

  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);

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

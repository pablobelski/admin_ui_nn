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

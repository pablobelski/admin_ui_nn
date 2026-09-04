import 'dart:typed_data';

void openMediaUrl(
  String url, {
  String target = '_blank',
  bool keepCurrentFocus = false,
}) {}

Future<void> openMediaUrlFromFuture(
  Future<String?> Function() resolveUrl, {
  String target = '_blank',
}) async {
  await resolveUrl();
}

void downloadMediaUrl(String url, {String? filename}) {}

void openMediaBytes(Uint8List bytes, {String? filename, String? contentType}) {}

void downloadMediaBytes(Uint8List bytes, {String? filename, String? contentType}) {}

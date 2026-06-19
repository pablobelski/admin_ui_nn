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
  return null;
}

import 'dart:async';

import '../../../core/ui/media_file_actions.dart';
import '../data/calculator_repository.dart';

// Reserve tabs during the user's click; the background job supplies the URLs later.
class GeneratedPdfPreview {
  GeneratedPdfPreview(
    int count,
    CalculatorRepository repository, {
    required void Function(Object error) onError,
  }) {
    for (var index = 0; index < count; index++) {
      final documentIndex = index;
      unawaited(
        openMediaUrlFromFuture(
          () async {
            final documents = await _documents.future;
            if (documentIndex >= documents.length) return null;
            final document = documents[documentIndex];
            final url = '${document['file_url'] ?? ''}'.trim();
            if (url.isNotEmpty) return url;
            final fileId = '${document['file_id'] ?? ''}'.trim();
            if (fileId.isEmpty) return null;
            final media = await repository.fetchMediaFileUrl(fileId);
            return '${media['url'] ?? media['download_url'] ?? ''}';
          },
          keepCurrentFocusWhileLoading: true,
        ).catchError((Object error) => onError(error)),
      );
    }
  }

  final _documents = Completer<List<Map<String, dynamic>>>();

  void complete(List<Map<String, dynamic>> documents) {
    if (_documents.isCompleted) return;
    final seen = <String>{};
    _documents.complete(
      documents
          .where((document) {
            final id = '${document['file_id'] ?? ''}';
            return id.isNotEmpty && seen.add(id);
          })
          .toList(growable: false),
    );
  }

  void close() => complete(const []);
}

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
      final pending = Completer<Map<String, dynamic>?>();
      _pending.add(pending);
      unawaited(
        openMediaUrlFromFuture(
          () async {
            final document = await pending.future;
            if (document == null) {
              return null;
            }
            final url = '${document['file_url'] ?? ''}'.trim();
            if (url.isNotEmpty) {
              return url;
            }
            final fileId = '${document['file_id'] ?? ''}'.trim();
            if (fileId.isEmpty) {
              return null;
            }
            final media = await repository.fetchMediaFileUrl(fileId);
            return '${media['url'] ?? media['download_url'] ?? ''}';
          },
          keepCurrentFocusWhileLoading: true,
        ).catchError((Object error) => onError(error)),
      );
    }
  }

  final _pending = <Completer<Map<String, dynamic>?>>[];
  final _seen = <String>{};
  int _next = 0;
  bool _closed = false;

  void addDocuments(List<Map<String, dynamic>> documents) {
    if (_closed) {
      return;
    }
    for (final document in documents) {
      final id = '${document['file_id'] ?? ''}'.trim();
      if (id.isNotEmpty && _seen.add(id) && _next < _pending.length) {
        _pending[_next++].complete(document);
      }
    }
  }

  void complete(List<Map<String, dynamic>> documents) {
    addDocuments(documents);
    close();
  }

  void close() {
    _closed = true;
    while (_next < _pending.length) {
      _pending[_next++].complete(null);
    }
  }
}

import 'package:flutter/material.dart';

import '../http/admin_resource_repository.dart';
import '../http/api_client.dart';
import 'media_file_actions.dart';

class MediaFileRef {
  const MediaFileRef({
    required this.fieldKey,
    required this.label,
    required this.fileId,
  });

  final String fieldKey;
  final String label;
  final String fileId;
}

class MediaPreviewDialog extends StatelessWidget {
  const MediaPreviewDialog({
    super.key,
    required this.repository,
    required this.files,
  });

  final AdminResourceRepository repository;
  final List<MediaFileRef> files;

  @override
  Widget build(BuildContext context) {
    final title = files.length == 1 ? 'Media file' : 'Media files';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 760,
        child: files.isEmpty
            ? const Text('No linked media files found.')
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 640),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _MediaPreviewCard(
                    repository: repository,
                    ref: files[index],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard({
    required this.repository,
    required this.ref,
  });

  final AdminResourceRepository repository;
  final MediaFileRef ref;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repository.fetchMediaFileUrl(ref.fileId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText('Failed to load file URL: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final file = Map<String, dynamic>.from((data['file'] as Map?) ?? const <String, dynamic>{});
        final url = repository.mediaFileViewUrl(ref.fileId);
        final filename = file['original_filename']?.toString() ?? ref.fileId;
        final mimeType = file['mime_type']?.toString() ?? '';
        final sizeText = _sizeText(file['size_bytes']);
        final canPreviewImage = _isImageMime(mimeType) || _isImageFilename(filename);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(canPreviewImage ? Icons.image_outlined : Icons.insert_drive_file_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ref.label, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          SelectableText(filename),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open',
                      onPressed: () => _openMediaFile(context, repository, ref.fileId, filename),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                    IconButton(
                      tooltip: 'Download',
                      onPressed: () => _downloadMediaFile(context, repository, ref.fileId, filename),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (mimeType.isNotEmpty) Text(mimeType),
                    if (sizeText.isNotEmpty) Text(sizeText),
                    SelectableText(ref.fileId),
                  ],
                ),
                if (canPreviewImage && url.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 420),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<ApiBinaryResponse>(
                      future: repository.viewMediaFile(ref.fileId),
                      builder: (context, imageSnapshot) {
                        if (imageSnapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final response = imageSnapshot.data;
                        if (imageSnapshot.hasError || response == null || response.bytes.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Image preview failed. Open or download the file instead.\n${imageSnapshot.error ?? ''}',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Image.memory(
                                response.bytes,
                                errorBuilder: (context, error, stackTrace) => Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Image preview failed. Open or download the file instead.\n$error',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


Future<void> _openMediaFile(
  BuildContext context,
  AdminResourceRepository repository,
  String fileId,
  String fallbackFilename,
) async {
  try {
    final response = await repository.viewMediaFile(fileId);
    openMediaBytes(
      response.bytes,
      filename: response.filename ?? fallbackFilename,
      contentType: response.contentType,
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open file failed: $error')),
    );
  }
}

Future<void> _downloadMediaFile(
  BuildContext context,
  AdminResourceRepository repository,
  String fileId,
  String fallbackFilename,
) async {
  try {
    final response = await repository.downloadMediaFile(fileId);
    downloadMediaBytes(
      response.bytes,
      filename: response.filename ?? fallbackFilename,
      contentType: response.contentType,
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File download failed: $error')),
    );
  }
}

bool _isImageMime(String mimeType) {
  return mimeType.toLowerCase().startsWith('image/');
}

bool _isImageFilename(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.svg');
}

String _sizeText(Object? value) {
  final size = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  if (size == null || size <= 0) return '';
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

import 'package:flutter/material.dart';

import '../http/admin_resource_repository.dart';
import 'searchable_select_form_field.dart';

class MediaUploadRootDialog extends StatefulWidget {
  const MediaUploadRootDialog({
    super.key,
    required this.repository,
    required this.filename,
  });

  final AdminResourceRepository repository;
  final String filename;

  @override
  State<MediaUploadRootDialog> createState() => _MediaUploadRootDialogState();
}

class _MediaUploadRootDialogState extends State<MediaUploadRootDialog> {
  late Future<Map<String, dynamic>> _roots = widget.repository
      .fetchMediaStorageRoots();
  String _root = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Upload to Media Library'),
    content: SizedBox(
      width: 460,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _roots,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load storage folders: ${snapshot.error}'),
                TextButton(
                  onPressed: () => setState(
                    () => _roots = widget.repository.fetchMediaStorageRoots(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final items = (snapshot.data!['items'] as List? ?? const [])
              .whereType<Map>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.filename),
              const SizedBox(height: 16),
              SearchableSelectFormField(
                labelText: 'Root folder',
                emptyLabel: 'media_library/ (default)',
                value: _root,
                options: items
                    .map(
                      (item) => SearchableSelectOption(
                        value: item['path'] == '' ? '/' : '${item['path']}',
                        label: '${item['label']}',
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _root = value ?? ''),
                helperText: 'Leave empty for media_library/. Year and month subfolders are added automatically.',
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(<String, String?>{
          'root_path': _root.isEmpty
              ? null
              : _root == '/'
              ? ''
              : _root,
        }),
        child: const Text('Upload'),
      ),
    ],
  );
}

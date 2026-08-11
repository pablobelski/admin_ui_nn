import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../../../core/ui/searchable_select_form_field.dart';
import '../../../core/ui/top_notification.dart';

class DocumentBatchItemsPanel extends ConsumerStatefulWidget {
  const DocumentBatchItemsPanel({
    super.key,
    required this.batchId,
    required this.repository,
  });

  final String batchId;
  final AdminResourceRepository repository;

  @override
  ConsumerState<DocumentBatchItemsPanel> createState() =>
      _DocumentBatchItemsPanelState();
}

class _DocumentBatchItemsPanelState
    extends ConsumerState<DocumentBatchItemsPanel> {
  late Future<ResourceListResponse> _itemsFuture;
  String _itemType = '';
  String _documentTemplateId = '';
  String _mediaFileId = '';
  String _active = '';

  AdminResourceDefinition get _resource =>
      findResourceByKey('document_batches_items');

  AdminResourceDefinition get _editorResource => AdminResourceDefinition(
        key: _resource.key,
        title: 'Document batch item',
        endpoint: _resource.endpoint,
        icon: _resource.icon,
        columns: _resource.columns,
        formFields: _resource.formFields
            .where((field) => field.key != 'document_batch_id')
            .toList(growable: false),
        supportsCreate: _resource.supportsCreate,
        supportsEdit: _resource.supportsEdit,
        supportsDelete: _resource.supportsDelete,
        listFilters: _resource.listFilters,
        detailActions: _resource.detailActions,
        requiresSysadmin: _resource.requiresSysadmin,
        showInNavigation: false,
      );

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchItems();
  }

  @override
  void didUpdateWidget(covariant DocumentBatchItemsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batchId != widget.batchId) {
      _itemType = '';
      _documentTemplateId = '';
      _mediaFileId = '';
      _active = '';
      _itemsFuture = _fetchItems();
    }
  }

  Future<ResourceListResponse> _fetchItems() {
    if (widget.batchId.trim().isEmpty) {
      return Future.value(
        const ResourceListResponse(items: <Map<String, dynamic>>[], total: 0),
      );
    }
    return widget.repository.fetchList(
      _resource,
      limit: 500,
      filters: {
        'document_batch_id': widget.batchId,
        if (_itemType.isNotEmpty) 'item_type_code': _itemType,
        if (_documentTemplateId.isNotEmpty)
          'document_template_id': _documentTemplateId,
        if (_mediaFileId.isNotEmpty) 'media_file_id': _mediaFileId,
        if (_active.isNotEmpty) 'is_active': _active,
      },
    );
  }

  void _reload() {
    setState(() {
      _itemsFuture = _fetchItems();
    });
    ref.invalidate(resourceListProvider(_resource));
    ref.invalidate(resourceDetailsProvider(_resource));
  }

  Future<void> _createItem() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ResourceEditorDialog(
        resource: _editorResource,
        repository: widget.repository,
      ),
    );
    if (payload == null) return;
    payload['document_batch_id'] = widget.batchId;

    try {
      await widget.repository.create(_resource, payload);
      if (!mounted) return;
      _reload();
      showTopNotification(
        context,
        'Batch item created.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        'Create failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  Future<void> _editItem(Map<String, dynamic> row) async {
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ResourceEditorDialog(
        resource: _editorResource,
        repository: widget.repository,
        initialData: row,
      ),
    );
    if (payload == null) return;

    try {
      await widget.repository.update(_resource, id, payload);
      if (!mounted) return;
      _reload();
      showTopNotification(
        context,
        'Batch item updated.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        'Update failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> row) async {
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final label = _sourceLabel(row, const <String, String>{});
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete batch item?'),
        content: Text('Delete "$label" from this document batch?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.delete(_resource, id);
      if (!mounted) return;
      _reload();
      showTopNotification(
        context,
        'Batch item deleted.',
        type: TopNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        'Delete failed: $error',
        type: TopNotificationType.error,
      );
    }
  }

  String _sourceLabel(
    Map<String, dynamic> row,
    Map<String, String> templateLabels, [
    Map<String, String> mediaLabels = const <String, String>{},
  ]) {
    final type = row['item_type_code']?.toString().trim() ??
        'document_template';
    if (type == 'geometry_preview' || type == 'quote_media') {
      return 'Geometry preview';
    }
    if (type == 'media_file') {
      final filename = row['media_original_filename']?.toString().trim() ?? '';
      final mediaFileId = row['media_file_id']?.toString().trim() ?? '';
      return filename.isNotEmpty
          ? filename
          : (mediaLabels[mediaFileId] ??
              (mediaFileId.isEmpty ? 'Media library file' : mediaFileId));
    }
    final templateId = row['document_template_id']?.toString().trim() ?? '';
    return templateLabels[templateId] ??
        (templateId.isEmpty ? 'Document template' : templateId);
  }

  String _templateLookupLabel(Map<String, dynamic> row) {
    final labels = <String>[];
    for (final key in documentTemplateLookup.labelKeys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) labels.add(value);
    }
    final id = row[documentTemplateLookup.idKey]?.toString().trim() ?? '';
    if (labels.isEmpty) return id;
    return labels.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final templateLookup = ref.watch(adminLookupProvider(documentTemplateLookup));
    final templateLabels = templateLookup.maybeWhen(
      data: (rows) => <String, String>{
        for (final row in rows)
          if ((row[documentTemplateLookup.idKey]?.toString().trim() ?? '')
              .isNotEmpty)
            row[documentTemplateLookup.idKey]!.toString():
                _templateLookupLabel(row),
      },
      orElse: () => const <String, String>{},
    );
    final templateOptions = templateLookup.maybeWhen(
      data: (rows) => rows
          .map(
            (row) => SearchableSelectOption(
              value:
                  row[documentTemplateLookup.idKey]?.toString().trim() ?? '',
              label: _templateLookupLabel(row),
            ),
          )
          .where((option) => option.value.isNotEmpty)
          .toList(growable: false),
      orElse: () => const <SearchableSelectOption>[],
    );

    final mediaLookup = ref.watch(adminLookupProvider(documentBatchMediaFileLookup));
    String mediaLookupLabel(Map<String, dynamic> row) {
      final filename = row['original_filename']?.toString().trim() ?? '';
      final mime = row['mime_type']?.toString().trim() ?? '';
      final id = row[documentBatchMediaFileLookup.idKey]?.toString().trim() ?? '';
      final parts = <String>[
        if (filename.isNotEmpty) filename,
        if (mime.isNotEmpty) mime,
      ];
      return parts.isEmpty ? id : parts.join(' · ');
    }
    final mediaLabels = mediaLookup.maybeWhen(
      data: (rows) => <String, String>{
        for (final row in rows)
          if ((row[documentBatchMediaFileLookup.idKey]?.toString().trim() ?? '').isNotEmpty)
            row[documentBatchMediaFileLookup.idKey]!.toString(): mediaLookupLabel(row),
      },
      orElse: () => const <String, String>{},
    );
    final mediaOptions = mediaLookup.maybeWhen(
      data: (rows) => rows
          .map(
            (row) => SearchableSelectOption(
              value: row[documentBatchMediaFileLookup.idKey]?.toString().trim() ?? '',
              label: mediaLookupLabel(row),
            ),
          )
          .where((option) => option.value.isNotEmpty)
          .toList(growable: false),
      orElse: () => const <SearchableSelectOption>[],
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_list_numbered_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('Batch items', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh batch items',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _createItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _itemType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: '',
                      child: Text('— All —', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'document_template',
                      child: Text(
                        'XLS document template',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'geometry_preview',
                      child: Text(
                        'Geometry preview',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'media_file',
                      child: Text(
                        'Media library file',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _itemType = value ?? '';
                      _itemsFuture = _fetchItems();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 300,
                child: SearchableSelectFormField(
                  value: _documentTemplateId,
                  options: templateOptions,
                  labelText: 'Document template',
                  emptyLabel: '— All —',
                  onChanged: (value) {
                    setState(() {
                      _documentTemplateId = value ?? '';
                      _itemsFuture = _fetchItems();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 300,
                child: SearchableSelectFormField(
                  value: _mediaFileId,
                  options: mediaOptions,
                  labelText: 'Media file',
                  emptyLabel: '— All —',
                  onChanged: (value) {
                    setState(() {
                      _mediaFileId = value ?? '';
                      _itemsFuture = _fetchItems();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _active,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Active'),
                  items: const [
                    DropdownMenuItem(
                      value: '',
                      child: Text('— All —', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'true',
                      child: Text('Active', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'false',
                      child: Text('Inactive', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _active = value ?? '';
                      _itemsFuture = _fetchItems();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<ResourceListResponse>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Batch items failed: ${snapshot.error}'),
                  );
                }
                final rows = snapshot.data?.items ??
                    const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No batch items match the current filters.'),
                  );
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final type = row['item_type_code']?.toString().trim() ??
                        'document_template';
                    final order = row['batch_order']?.toString() ?? '100';
                    final active = row['is_active'] == true;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: SizedBox(
                        width: 42,
                        child: Text(
                          order,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      title: Text(
                        _sourceLabel(row, templateLabels, mediaLabels),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        type == 'geometry_preview' || type == 'quote_media'
                            ? 'Geometry preview'
                            : type == 'media_file'
                                ? 'Media library file'
                                : 'XLS document template',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: active ? 'Active' : 'Inactive',
                            child: Icon(
                              active
                                  ? Icons.check_circle_outline
                                  : Icons.do_not_disturb_on_outlined,
                              size: 18,
                              color: active
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit batch item',
                            onPressed: () => _editItem(row),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Delete batch item',
                            onPressed: () => _deleteItem(row),
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../../../core/ui/searchable_select_form_field.dart';
import '../../../core/ui/top_notification.dart';

/// Integration batch items inside the Integration batch details, like DocumentBatchItemsPanel.
/// Filters come from the listFilters of `integration_batch_items` (without the batch itself).
class IntegrationBatchItemsPanel extends ConsumerStatefulWidget {
  const IntegrationBatchItemsPanel({
    super.key,
    required this.batchId,
    required this.repository,
  });

  final String batchId;
  final AdminResourceRepository repository;

  @override
  ConsumerState<IntegrationBatchItemsPanel> createState() =>
      _IntegrationBatchItemsPanelState();
}

class _IntegrationBatchItemsPanelState
    extends ConsumerState<IntegrationBatchItemsPanel> {
  static const _batchKey = 'integration_batch_id';

  late Future<ResourceListResponse> _itemsFuture;
  final Map<String, String> _filters = <String, String>{};

  AdminResourceDefinition get _resource =>
      findResourceByKey('integration_batch_items');

  List<AdminResourceFilter> get _itemFilters => _resource.listFilters
      .where((filter) => filter.key != _batchKey)
      .toList(growable: false);

  AdminResourceDefinition get _editorResource => AdminResourceDefinition(
        key: _resource.key,
        title: 'Integration batch item',
        endpoint: _resource.endpoint,
        icon: _resource.icon,
        columns: _resource.columns,
        formFields: _resource.formFields
            .where((field) => field.key != _batchKey)
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
  void didUpdateWidget(covariant IntegrationBatchItemsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batchId != widget.batchId) {
      _filters.clear();
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
      filters: {_batchKey: widget.batchId, ..._filters},
    );
  }

  void _setFilter(String key, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _filters.remove(key);
      } else {
        _filters[key] = value;
      }
      _itemsFuture = _fetchItems();
    });
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
    payload[_batchKey] = widget.batchId;

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
    final label = _operationLabel(row);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete batch item?'),
        content: Text('Delete "$label" from this integration batch?'),
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

  String _operationLabel(Map<String, dynamic> row) {
    final code = row['operation_code']?.toString().trim() ?? '';
    for (final option in integrationOperationOptions) {
      if (option.value == code) return option.label;
    }
    return code.isEmpty ? 'Operation' : code;
  }

  String _lookupLabel(AdminLookup lookup, Map<String, dynamic> row) {
    final labels = <String>[];
    for (final key in lookup.labelKeys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) labels.add(value);
    }
    final id = row[lookup.idKey]?.toString().trim() ?? '';
    return labels.isEmpty ? id : labels.join(' · ');
  }

  List<SearchableSelectOption> _lookupOptions(AdminLookup lookup) {
    return ref.watch(adminLookupProvider(lookup)).maybeWhen(
          data: (rows) => rows
              .map(
                (row) => SearchableSelectOption(
                  value: row[lookup.idKey]?.toString().trim() ?? '',
                  label: _lookupLabel(lookup, row),
                ),
              )
              .where((option) => option.value.isNotEmpty)
              .toList(growable: false),
          orElse: () => const <SearchableSelectOption>[],
        );
  }

  Widget _filterField(AdminResourceFilter filter) {
    final lookup = filter.lookup;
    final options = lookup != null
        ? _lookupOptions(lookup)
        : [
            for (final option in filter.options)
              SearchableSelectOption(value: option.value, label: option.label),
          ];
    return SizedBox(
      width: filter.key == 'is_active' ? 150 : 300,
      child: SearchableSelectFormField(
        value: _filters[filter.key] ?? '',
        options: options,
        labelText: filter.label,
        emptyLabel: '— All —',
        onChanged: (value) => _setFilter(filter.key, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final endpointLabels = <String, String>{
      for (final option in _lookupOptions(integrationEndpointLookup))
        option.value: option.label,
    };

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
            children: [for (final filter in _itemFilters) _filterField(filter)],
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
                    final order = row['batch_order']?.toString() ?? '100';
                    final active = row['is_active'] == true;
                    final endpointId =
                        row['integration_endpoint_id']?.toString().trim() ?? '';
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
                        _operationLabel(row),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Endpoint: ${endpointLabels[endpointId] ?? (endpointId.isEmpty ? '—' : endpointId)}',
                        overflow: TextOverflow.ellipsis,
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

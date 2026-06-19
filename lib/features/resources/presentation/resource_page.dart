import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/models/admin_state.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/admin_list_table.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/media_file_actions.dart';
import '../../../core/ui/media_preview_dialog.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/scrollable_areas.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../../../core/ui/searchable_select_form_field.dart';
import '../../calculator/data/calculator_models.dart';
import '../../calculator/presentation/calculator_providers.dart';
import 'catalog_item_dependency_tree.dart';

class ResourcePage extends ConsumerWidget {
  const ResourcePage({
    super.key,
    required this.resource,
  });

  final AdminResourceDefinition resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final listAsync = ref.watch(resourceListProvider(resource));
    final detailsAsync = ref.watch(resourceDetailsProvider(resource));
    final isWide = MediaQuery.sizeOf(context).width >= 1300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(resource: resource),
        const SizedBox(height: 16),
        _Toolbar(resource: resource, browserState: browserState),
        const SizedBox(height: 16),
        Expanded(
          child: ResizableSplitPane(
            axis: isWide ? Axis.horizontal : Axis.vertical,
            initialFraction: isWide ? 0.6 : 0.5,
            minFirstFraction: 0.25,
            minSecondFraction: 0.25,
            first: _ListCard(resource: resource, listAsync: listAsync),
            second: _DetailsCard(resource: resource, detailsAsync: detailsAsync),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.resource});

  final AdminResourceDefinition resource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(resource.icon),
            const SizedBox(width: 12),
            Text(resource.title, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        if (resource.description != null) ...[
          const SizedBox(height: 8),
          Text(resource.description!),
        ],
      ],
    );
  }
}

class _Toolbar extends ConsumerStatefulWidget {
  const _Toolbar({
    required this.resource,
    required this.browserState,
  });

  final AdminResourceDefinition resource;
  final ResourceBrowserState browserState;

  @override
  ConsumerState<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<_Toolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.browserState.query);
  }

  @override
  void didUpdateWidget(covariant _Toolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.browserState.query != widget.browserState.query) {
      _searchController.text = widget.browserState.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.read(resourceBrowserProvider(widget.resource.key).notifier);
    final repository = ref.read(resourceRepositoryProvider);
    final hasActiveFilters = widget.browserState.filters.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                ),
                onSubmitted: browser.setQuery,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => browser.setQuery(_searchController.text.trim()),
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Apply'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(resourceListProvider(widget.resource));
                ref.invalidate(resourceDetailsProvider(widget.resource));
              },
              icon: const Icon(Icons.refresh),
            ),
            const Spacer(),
            if (widget.resource.supportsCreate)
              FilledButton.icon(
                onPressed: () async {
                  final payload = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ResourceEditorDialog(
                      resource: widget.resource,
                      repository: repository,
                    ),
                  );
                  if (payload == null) return;
                  await repository.create(widget.resource, payload);
                  ref.invalidate(resourceListProvider(widget.resource));
                },
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
          ],
        ),
        if (widget.resource.listFilters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final filter in widget.resource.listFilters)
                SizedBox(
                  width: 320,
                  child: _ListFilterField(
                    resource: widget.resource,
                    filter: filter,
                    value: widget.browserState.filters[filter.key] ?? '',
                  ),
                ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: browser.clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ListFilterField extends ConsumerWidget {
  const _ListFilterField({
    required this.resource,
    required this.filter,
    required this.value,
  });

  final AdminResourceDefinition resource;
  final AdminResourceFilter filter;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browser = ref.read(resourceBrowserProvider(resource.key).notifier);
    final lookup = filter.lookup;

    if (filter.options.isNotEmpty) {
      return SearchableSelectFormField(
        key: ValueKey('filter-${resource.key}-${filter.key}-$value-options'),
        value: value,
        options: [
          for (final option in filter.options)
            SearchableSelectOption(value: option.value, label: option.label),
        ],
        onChanged: (nextValue) => browser.setFilter(filter.key, nextValue),
        labelText: filter.label,
        emptyLabel: '— All —',
      );
    }

    if (lookup == null) {
      return TextFormField(
        key: ValueKey('filter-${resource.key}-${filter.key}-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: filter.label),
        onFieldSubmitted: (nextValue) => browser.setFilter(filter.key, nextValue),
      );
    }

    final lookupAsync = ref.watch(adminLookupProvider(lookup));
    return lookupAsync.when(
      loading: () => SearchableSelectFormField(
        key: ValueKey('filter-${resource.key}-${filter.key}-$value-loading'),
        value: value,
        options: [
          if (value.isNotEmpty) SearchableSelectOption(value: value, label: value),
        ],
        onChanged: null,
        labelText: filter.label,
        emptyLabel: '— All —',
        helperText: 'Loading options...',
        enabled: false,
      ),
      error: (_, __) => TextFormField(
        key: ValueKey('filter-${resource.key}-${filter.key}-$value-error'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: filter.label,
          helperText: 'Lookup failed; paste id manually',
        ),
        onFieldSubmitted: (nextValue) => browser.setFilter(filter.key, nextValue),
      ),
      data: (rows) {
        final options = <SearchableSelectOption>[];
        var hasCurrentValue = value.isEmpty;

        for (final row in rows) {
          final id = row[lookup.idKey]?.toString();
          if (id == null || id.isEmpty) continue;
          hasCurrentValue = hasCurrentValue || id == value;
          options.add(SearchableSelectOption(value: id, label: _lookupLabel(lookup, row)));
        }

        if (!hasCurrentValue) {
          options.add(SearchableSelectOption(value: value, label: value));
        }

        return SearchableSelectFormField(
          key: ValueKey('filter-${resource.key}-${filter.key}-$value'),
          value: value,
          options: options,
          onChanged: (nextValue) => browser.setFilter(filter.key, nextValue),
          labelText: filter.label,
          emptyLabel: '— All —',
        );
      },
    );
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({
    required this.resource,
    required this.listAsync,
  });

  final AdminResourceDefinition resource;
  final AsyncValue<ResourceListResponse> listAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final browser = ref.read(resourceBrowserProvider(resource.key).notifier);
    final lookupLabelsByColumn = <String, Map<String, String>>{
      for (final column in resource.columns)
        if (column.lookup != null)
          column.key: ref.watch(adminLookupProvider(column.lookup!)).maybeWhen(
            data: (rows) => _lookupLabelMap(column.lookup!, rows),
            orElse: () => const <String, String>{},
          ),
    };
    final filtersKey = _filtersStorageKey(browserState.filters);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(error: error),
          data: (response) {
            if (response.items.isEmpty) {
              return const Center(child: Text('No rows found'));
            }

            return Column(
              children: [
                Expanded(
                  child: HorizontalScrollArea(
                    child: SizedBox(
                      width: adminRowNumberColumnWidth + resource.columns.fold<double>(0, (sum, col) => sum + (col.flex * 180.0)),
                      child: ListView.separated(
                        key: PageStorageKey<String>(
                          'resource-list-${resource.key}-${browserState.query}-$filtersKey-${browserState.offset}-${browserState.limit}',
                        ),
                        itemCount: response.items.length + 1,
                        separatorBuilder: (_, index) => index == 0
                            ? const Divider(height: 2)
                            : const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  const AdminRowNumberHeader(),
                                  for (final column in resource.columns)
                                    AdminTableHeaderCell(
                                      label: column.label,
                                      flex: column.flex,
                                    ),
                                ],
                              ),
                            );
                          }

                          final rowIndex = index - 1;
                          final row = response.items[rowIndex];
                          final rowId = row['id']?.toString();
                          final isSelected = browserState.selectedId == rowId;
                          return InkWell(
                            onTap: () => browser.select(rowId),
                            child: Container(
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  AdminRowNumberCell(index: rowIndex, offset: browserState.offset),
                                  for (final column in resource.columns)
                                    AdminTableValueCell(
                                      value: _displayValue(
                                        row[column.key],
                                        lookupLabels: lookupLabelsByColumn[column.key],
                                      ),
                                      flex: column.flex,
                                      strong: column.isPrimary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AdminListFooter(
                  offset: browserState.offset,
                  limit: browserState.limit,
                  pageItemCount: response.items.length,
                  total: response.total,
                  onPrevious: browserState.offset == 0 ? null : browser.previousPage,
                  onNext: adminListHasNextPage(
                    offset: browserState.offset,
                    limit: browserState.limit,
                    pageItemCount: response.items.length,
                    total: response.total,
                  )
                      ? browser.nextPage
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailsCard extends ConsumerStatefulWidget {
  const _DetailsCard({
    required this.resource,
    required this.detailsAsync,
  });

  final AdminResourceDefinition resource;
  final AsyncValue<Map<String, dynamic>?> detailsAsync;

  @override
  ConsumerState<_DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends ConsumerState<_DetailsCard> {
  bool _showCatalogItemTree = false;

  @override
  void didUpdateWidget(covariant _DetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.key != widget.resource.key) {
      _showCatalogItemTree = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final repository = ref.read(resourceRepositoryProvider);

    return widget.detailsAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (data) {
        if (browserState.selectedId == null) {
          return const Card(
            child: Center(
              child: Text('Select a row to inspect details'),
            ),
          );
        }

        if (data == null) {
          return const Card(
            child: Center(
              child: Text('No details found for this row'),
            ),
          );
        }

        final canShowCatalogItemTree =
            resource.key == 'catalog_item_relations' || resource.key == 'catalog_items';
        final rootCatalogItemId = _catalogItemTreeRootId(resource.key, data, browserState.selectedId);
        final mediaFiles = _mediaFileRefsFor(resource, data);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _showCatalogItemTree && canShowCatalogItemTree ? 'Dependency tree' : 'Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (resource.detailActions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _DetailActionsMenu(
                          actions: resource.detailActions,
                          data: data,
                          onSelected: (action) => _openDetailAction(ref, action, data),
                        ),
                      ),
                    if (resource.key == 'quotes')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => loadQuoteToWorkspace(context, ref, data),
                          icon: const Icon(Icons.upload_file_outlined, size: 18),
                          label: const Text('Load to Workspace'),
                        ),
                      ),
                    if (resource.key == 'users')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final password = await showDialog<String>(
                              context: context,
                              builder: (_) => const _SetUserPasswordDialog(),
                            );
                            if (password == null) return;
                            try {
                              await ref.read(apiClientProvider).postJson(
                                '/api/admin/users/${browserState.selectedId}/password',
                                body: {'password': password},
                              );
                              ref.invalidate(resourceListProvider(resource));
                              ref.invalidate(resourceDetailsProvider(resource));
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password changed')),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Password change failed: $error')),
                              );
                            }
                          },
                          icon: const Icon(Icons.password_rounded, size: 18),
                          label: const Text('Set password'),
                        ),
                      ),
                    if (canShowCatalogItemTree)
                      IconButton(
                        tooltip: _showCatalogItemTree ? 'Hide dependency tree' : 'Show dependency tree',
                        onPressed: rootCatalogItemId == null
                            ? null
                            : () => setState(() => _showCatalogItemTree = !_showCatalogItemTree),
                        icon: Icon(
                          _showCatalogItemTree
                              ? Icons.account_tree_rounded
                              : Icons.account_tree_outlined,
                        ),
                      ),
                    if (mediaFiles.isNotEmpty)
                      IconButton(
                        tooltip: 'Preview media',
                        onPressed: () => _showMediaPreview(context, repository, mediaFiles),
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                    if (mediaFiles.isNotEmpty)
                      IconButton(
                        tooltip: mediaFiles.length == 1 ? 'Download file' : 'Download files',
                        onPressed: () => _downloadMediaFiles(context, repository, mediaFiles),
                        icon: const Icon(Icons.download_outlined),
                      ),
                    if (resource.supportsEdit)
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () async {
                          final payload = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (_) => ResourceEditorDialog(
                              resource: resource,
                              repository: repository,
                              initialData: data,
                            ),
                          );
                          if (payload == null) return;
                          await repository.update(resource, browserState.selectedId!, payload);
                          ref.invalidate(resourceListProvider(resource));
                          ref.invalidate(resourceDetailsProvider(resource));
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (resource.supportsDelete)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () async {
                          await repository.delete(resource, browserState.selectedId!);
                          ref.read(resourceBrowserProvider(resource.key).notifier).select(null);
                          ref.invalidate(resourceListProvider(resource));
                          ref.invalidate(resourceDetailsProvider(resource));
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _showCatalogItemTree && canShowCatalogItemTree && rootCatalogItemId != null
                      ? CatalogItemDependencyTree(
                          key: ValueKey('catalog-item-tree-$rootCatalogItemId'),
                          repository: repository,
                          rootItemId: rootCatalogItemId,
                          onOpenCatalogItem: (catalogItemId) => _openCatalogItem(ref, catalogItemId),
                        )
                      : ListView(
                          children: [
                            Card(
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Main fields', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 12),
                                    for (final entry in data.entries.take(12))
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 180,
                                              child: Text(
                                                entry.key,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(child: Text(_displayValue(entry.value))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            JsonViewCard(title: 'Raw JSON', data: data),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


List<MediaFileRef> _mediaFileRefsFor(
  AdminResourceDefinition resource,
  Map<String, dynamic> data,
) {
  final refs = <MediaFileRef>[];
  final seen = <String>{};

  void addRef(String fieldKey, String label, Object? rawValue) {
    final fileId = rawValue?.toString().trim() ?? '';
    if (fileId.isEmpty || !_looksLikeUuid(fileId) || !seen.add(fileId)) {
      return;
    }
    refs.add(MediaFileRef(
      fieldKey: fieldKey,
      label: label,
      fileId: fileId,
    ));
  }

  if (resource.key == 'asset_files') {
    final label = data['original_filename']?.toString().trim();
    addRef('id', label == null || label.isEmpty ? 'Media file' : label, data['id']);
  }

  for (final field in resource.formFields) {
    if (field.type == AdminFieldType.file) {
      addRef(field.key, field.label, _valueAtPath(data, field.key));
    }
  }

  for (final entry in data.entries) {
    final key = entry.key;
    if (key == 'file_id' || key.endsWith('_file_id')) {
      addRef(key, _humanizeFileFieldKey(key), entry.value);
    }
  }

  return refs;
}

dynamic _valueAtPath(Map<String, dynamic> source, String key) {
  if (!key.contains('.')) return source[key];

  dynamic cursor = source;
  for (final part in key.split('.')) {
    if (cursor is Map<String, dynamic>) {
      cursor = cursor[part];
    } else if (cursor is Map) {
      cursor = cursor[part];
    } else {
      return null;
    }
  }
  return cursor;
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

String _humanizeFileFieldKey(String key) {
  final words = key
      .replaceAll('.', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (words.isEmpty) return 'Media file';
  return words[0].toUpperCase() + words.substring(1);
}

Future<void> _showMediaPreview(
  BuildContext context,
  AdminResourceRepository repository,
  List<MediaFileRef> files,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => MediaPreviewDialog(
      repository: repository,
      files: files,
    ),
  );
}

Future<void> _downloadMediaFiles(
  BuildContext context,
  AdminResourceRepository repository,
  List<MediaFileRef> files,
) async {
  try {
    for (final fileRef in files) {
      final data = await repository.fetchMediaFileUrl(fileRef.fileId);
      final file = Map<String, dynamic>.from((data['file'] as Map?) ?? const <String, dynamic>{});
      final url = data['url']?.toString() ?? file['public_url']?.toString() ?? '';
      if (url.isEmpty) {
        throw StateError('Media URL is empty for ${fileRef.label}');
      }
      downloadMediaUrl(
        url,
        filename: file['original_filename']?.toString(),
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(files.length == 1 ? 'File download started' : 'File downloads started: ${files.length}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File download failed: $error')),
    );
  }
}


String? _catalogItemTreeRootId(
  String resourceKey,
  Map<String, dynamic> data,
  String? selectedId,
) {
  if (resourceKey == 'catalog_item_relations') {
    return _extractRelationId(data['parent_catalog_item_id']?.toString() ?? '');
  }
  if (resourceKey == 'catalog_items') {
    return _extractRelationId(data['id']?.toString() ?? selectedId ?? '');
  }
  return null;
}

class _DetailActionsMenu extends StatelessWidget {
  const _DetailActionsMenu({
    required this.actions,
    required this.data,
    required this.onSelected,
  });

  final List<AdminDetailAction> actions;
  final Map<String, dynamic> data;
  final ValueChanged<AdminDetailAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasAvailableActions = actions.any((action) => _detailActionValue(action, data) != null);

    return PopupMenuButton<AdminDetailAction>(
      tooltip: 'Open related section',
      enabled: hasAvailableActions,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<AdminDetailAction>(
            value: action,
            enabled: _detailActionValue(action, data) != null,
            child: Row(
              children: [
                Icon(action.icon, size: 18),
                const SizedBox(width: 12),
                Flexible(child: Text(action.label)),
              ],
            ),
          ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: hasAvailableActions ? () {} : null,
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: const Text('Related'),
        ),
      ),
    );
  }
}

Future<void> loadQuoteToWorkspace(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final quoteId = data['id']?.toString();
  final quoteNo = data['quote_no']?.toString() ?? quoteId ?? 'selected quote';
  if (quoteId == null || quoteId.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Load quote to workspace?'),
      content: Text(
        'Quote "$quoteNo" will be loaded into Calculator Workspace. '
        'Current unsaved calculator input will be replaced.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Load to Workspace'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final loadedQuote = await ref.read(calculatorRepositoryProvider).loadQuoteForWorkspace(quoteId);
    ref.read(loadedQuoteProvider.notifier).set(loadedQuote);
    ref.read(calculatorDraftProvider.notifier).loadQuote(loadedQuote);

    final loadedResult = loadedQuote.resultJson == null
        ? null
        : CalculatorResult.fromJson(loadedQuote.resultJson!);
    if (loadedResult == null) {
      ref.read(calculatorResultProvider.notifier).clear();
    } else {
      ref.read(calculatorResultProvider.notifier).setData(loadedResult);
    }

    ref.read(selectedResourceProvider.notifier).select('calculator_workspace');

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded quote: ${loadedQuote.quoteNo}')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Load quote failed: $error')),
    );
  }
}

void _openDetailAction(WidgetRef ref, AdminDetailAction action, Map<String, dynamic> data) {
  final targetResource = findResourceByKey(action.targetResourceKey);
  final filterValue = _detailActionValue(action, data);
  if (filterValue == null) return;

  final filters = {action.filterKey: filterValue};
  final selectedId = action.selectTargetRow && action.filterKey == 'id' ? filterValue : null;
  ref.read(selectedResourceProvider.notifier).select(
    action.targetResourceKey,
    filters: filters,
  );
  ref
      .read(resourceBrowserProvider(action.targetResourceKey).notifier)
      .openWithFilters(
        filters,
        selectedId: selectedId,
        updateUrl: false,
      );
  ref.invalidate(resourceListProvider(targetResource));
  ref.invalidate(resourceDetailsProvider(targetResource));
}

void _openCatalogItem(WidgetRef ref, String catalogItemId) {
  final targetResource = findResourceByKey('catalog_items');
  final filters = {'id': catalogItemId};
  ref.read(selectedResourceProvider.notifier).select(
    'catalog_items',
    filters: filters,
  );
  ref
      .read(resourceBrowserProvider('catalog_items').notifier)
      .openWithFilters(
        filters,
        selectedId: catalogItemId,
        updateUrl: false,
      );
  ref.invalidate(resourceListProvider(targetResource));
  ref.invalidate(resourceDetailsProvider(targetResource));
}

class _SetUserPasswordDialog extends StatefulWidget {
  const _SetUserPasswordDialog();

  @override
  State<_SetUserPasswordDialog> createState() => _SetUserPasswordDialogState();
}

class _SetUserPasswordDialogState extends State<_SetUserPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set user password'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeatPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repeat new password'),
                validator: (value) {
                  final requiredMessage = _required(value);
                  if (requiredMessage != null) return requiredMessage;
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_passwordController.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }
    return null;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(error.toString()),
      ),
    );
  }
}

String? _detailActionValue(AdminDetailAction action, Map<String, dynamic> data) {
  final value = data[action.sourceValueKey]?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return _extractRelationId(value);
}

String? _extractRelationId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  final matches = uuidPattern.allMatches(trimmed).toList(growable: false);
  if (matches.isNotEmpty) {
    return matches.last.group(0)!;
  }
  return trimmed;
}

String _filtersStorageKey(Map<String, String> filters) {
  if (filters.isEmpty) return 'nofilters';
  final entries = filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}=${entry.value}').join('&');
}

Map<String, String> _lookupLabelMap(AdminLookup lookup, List<Map<String, dynamic>> rows) {
  return {
    for (final row in rows)
      if ((row[lookup.idKey]?.toString().trim() ?? '').isNotEmpty)
        row[lookup.idKey]!.toString(): _lookupCompactLabel(lookup, row),
  };
}

List<String> _lookupLabelParts(AdminLookup lookup, Map<String, dynamic> row) {
  final labels = <String>[];
  for (final key in lookup.labelKeys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      labels.add(value.toString());
    }
  }
  return labels;
}

String _lookupCompactLabel(AdminLookup lookup, Map<String, dynamic> row) {
  final labels = _lookupLabelParts(lookup, row);
  if (labels.isNotEmpty) return labels.join(' · ');
  return row[lookup.idKey]?.toString() ?? '';
}

String _lookupLabel(AdminLookup lookup, Map<String, dynamic> row) {
  final compactLabel = _lookupCompactLabel(lookup, row);
  final id = row[lookup.idKey]?.toString() ?? '';
  if (compactLabel.isEmpty) return id;
  if (id.isEmpty || !lookup.showIdInDropdown) return compactLabel;
  return '$compactLabel ($id)';
}

String _displayValue(Object? value, {Map<String, String>? lookupLabels}) {
  if (value == null) return '—';
  if (lookupLabels != null) {
    final key = value.toString();
    final label = lookupLabels[key];
    if (label != null && label.isNotEmpty) {
      return label;
    }
  }
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(value);
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  return '$value';
}

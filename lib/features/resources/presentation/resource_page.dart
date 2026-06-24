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
                  try {
                    await repository.create(widget.resource, payload);
                    ref.invalidate(resourceListProvider(widget.resource));
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Create failed: $error')),
                    );
                  }
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

  static const double _previewColumnWidth = 64;
  static const double _rowHorizontalPadding = 12;

  final AdminResourceDefinition resource;
  final AsyncValue<ResourceListResponse> listAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final browser = ref.read(resourceBrowserProvider(resource.key).notifier);
    final repository = ref.read(resourceRepositoryProvider);
    final useCompactLayout = _usesCompactListLayout(resource);
    final hasLeadingPreview = _hasLeadingPreviewColumn(resource);
    final visibleColumns = resource.columns
        .where((column) => !_hideListColumn(resource, column))
        .toList(growable: false);
    final lookupLabelsByColumn = <String, Map<String, String>>{
      for (final column in visibleColumns)
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

            final tableContentWidth = useCompactLayout
                ? adminRowNumberColumnWidth
                    + (hasLeadingPreview ? _previewColumnWidth : 0)
                    + visibleColumns.fold<double>(
                        0,
                        (sum, column) => sum + _compactColumnWidth(resource.key, column),
                      )
                : adminRowNumberColumnWidth
                    + visibleColumns.fold<double>(0, (sum, col) => sum + (col.flex * 180.0));
            final tableWidth = tableContentWidth + (_rowHorizontalPadding * 2);

            return Column(
              children: [
                Expanded(
                  child: HorizontalScrollArea(
                    child: SizedBox(
                      width: tableWidth,
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
                                  if (hasLeadingPreview)
                                    const AdminTableHeaderCell(
                                      label: 'Media',
                                      width: _previewColumnWidth,
                                      align: TextAlign.left,
                                    ),
                                  for (final column in visibleColumns)
                                    AdminTableHeaderCell(
                                      label: column.label,
                                      width: useCompactLayout
                                          ? _compactColumnWidth(resource.key, column)
                                          : null,
                                      flex: useCompactLayout ? null : column.flex,
                                      align: TextAlign.left,
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  AdminRowNumberCell(index: rowIndex, offset: browserState.offset),
                                  if (hasLeadingPreview)
                                    _MediaPreviewListCell(
                                      repository: repository,
                                      mediaRef: _leadingListMediaRef(resource, row),
                                      width: _previewColumnWidth,
                                    ),
                                  for (final column in visibleColumns)
                                    _buildListValueCell(
                                      resource: resource,
                                      repository: repository,
                                      row: row,
                                      column: column,
                                      lookupLabels: lookupLabelsByColumn[column.key],
                                      useCompactLayout: useCompactLayout,
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

Widget _buildListValueCell({
  required AdminResourceDefinition resource,
  required AdminResourceRepository repository,
  required Map<String, dynamic> row,
  required AdminColumn column,
  required Map<String, String>? lookupLabels,
  required bool useCompactLayout,
}) {
  final width = useCompactLayout ? _compactColumnWidth(resource.key, column) : null;

  if (_isInlinePreviewColumn(resource, column)) {
    return _MediaPreviewListCell(
      repository: repository,
      mediaRef: _inlineListMediaRef(resource, row, column),
      width: width ?? _ListCard._previewColumnWidth,
    );
  }

  return AdminTableValueCell(
    value: _displayListValue(
      resource: resource,
      row: row,
      column: column,
      lookupLabels: lookupLabels,
    ),
    width: width,
    flex: useCompactLayout ? null : column.flex,
    strong: column.isPrimary,
  );
}

bool _usesCompactListLayout(AdminResourceDefinition resource) {
  return resource.key == 'catalog_media'
      || resource.key == 'catalog_items'
      || resource.key == 'catalog_variants'
      || resource.key == 'asset_files';
}

bool _hasLeadingPreviewColumn(AdminResourceDefinition resource) {
  return resource.key == 'catalog_items'
      || resource.key == 'catalog_variants'
      || resource.key == 'asset_files';
}

bool _hideListColumn(AdminResourceDefinition resource, AdminColumn column) {
  return resource.key == 'catalog_variants' && column.key == 'image_file_id';
}

bool _isInlinePreviewColumn(AdminResourceDefinition resource, AdminColumn column) {
  return resource.key == 'catalog_media' && column.key == 'kind';
}

double _compactColumnWidth(String resourceKey, AdminColumn column) {
  final key = column.key;

  if (resourceKey == 'asset_files') {
    return switch (key) {
      'original_filename' => 260,
      'mime_type' => 110,
      'size_bytes' => 80,
      'bucket_name' => 170,
      'storage_key' => 360,
      _ => 140,
    };
  }

  if (resourceKey == 'catalog_media') {
    return switch (key) {
      'kind' => 64,
      'use_type' => 96,
      'catalog_item_id' => 260,
      'catalog_variant_id' => 260,
      'file_id' => 260,
      'is_primary' => 80,
      _ => 140,
    };
  }

  if (resourceKey == 'catalog_items') {
    return switch (key) {
      'base_code' => 140,
      'name' => 300,
      'product_family_id' => 180,
      'item_type_id' => 190,
      'category_code' => 120,
      'system_code' => 120,
      'measure_type_code' => 90,
      'default_sales_unit_code' => 110,
      'purchase_price_fixed' => 120,
      'is_active' => 80,
      _ => 130,
    };
  }

  if (resourceKey == 'catalog_variants') {
    return switch (key) {
      'variant_sku' => 240,
      'catalog_item_id' => 260,
      'article_no' => 120,
      'color_name' => 130,
      'length_mm' => 90,
      'glass_type_code' => 100,
      'coating_price_per_meter' => 120,
      'purchase_price_fixed' => 120,
      'is_active' => 80,
      _ => 130,
    };
  }

  return column.flex * 180.0;
}

String _displayListValue({
  required AdminResourceDefinition resource,
  required Map<String, dynamic> row,
  required AdminColumn column,
  required Map<String, String>? lookupLabels,
}) {
  if (resource.key == 'catalog_media' && column.key == 'file_id') {
    final filename = row['file_original_filename']?.toString().trim();
    if (filename != null && filename.isNotEmpty) return filename;
  }

  return _displayValue(
    row[column.key],
    lookupLabels: lookupLabels,
  );
}

MediaFileRef? _leadingListMediaRef(
  AdminResourceDefinition resource,
  Map<String, dynamic> row,
) {
  if (resource.key == 'catalog_items') {
    return _mediaRefFromRow(
      row: row,
      fileIdKey: 'icon_media_file_id',
      filenameKey: 'icon_media_filename',
      fallbackLabel: 'Catalog item icon',
    );
  }

  if (resource.key == 'catalog_variants') {
    return _mediaRefFromRow(
          row: row,
          fileIdKey: 'icon_media_file_id',
          filenameKey: 'icon_media_filename',
          fallbackLabel: 'Catalog variant icon',
        ) ??
        _mediaRefFromRow(
          row: row,
          fileIdKey: 'image_file_id',
          filenameKey: 'image_original_filename',
          fallbackLabel: 'Catalog variant image',
        );
  }

  if (resource.key == 'asset_files') {
    final mimeType = row['mime_type']?.toString().trim() ?? '';
    if (!mimeType.toLowerCase().startsWith('image/')) return null;
    return _mediaRefFromRow(
      row: row,
      fileIdKey: 'id',
      filenameKey: 'original_filename',
      fallbackLabel: 'Media file',
    );
  }

  return null;
}

MediaFileRef? _inlineListMediaRef(
  AdminResourceDefinition resource,
  Map<String, dynamic> row,
  AdminColumn column,
) {
  if (resource.key == 'catalog_media' && column.key == 'kind') {
    final kind = row['kind']?.toString().trim().toLowerCase() ?? '';
    final mimeType = row['file_mime_type']?.toString().trim().toLowerCase() ?? '';
    if (kind != 'image' && !mimeType.startsWith('image/')) return null;
    return _mediaRefFromRow(
      row: row,
      fileIdKey: 'file_id',
      filenameKey: 'file_original_filename',
      fallbackLabel: 'Catalog media',
    );
  }
  return null;
}

MediaFileRef? _mediaRefFromRow({
  required Map<String, dynamic> row,
  required String fileIdKey,
  required String filenameKey,
  required String fallbackLabel,
}) {
  final fileId = row[fileIdKey]?.toString().trim() ?? '';
  if (fileId.isEmpty || !_looksLikeUuid(fileId)) return null;

  final filename = row[filenameKey]?.toString().trim();
  return MediaFileRef(
    fileId: fileId,
    fieldKey: fileIdKey,
    label: filename == null || filename.isEmpty ? fallbackLabel : filename,
  );
}

class _MediaPreviewListCell extends StatelessWidget {
  const _MediaPreviewListCell({
    required this.repository,
    required this.mediaRef,
    required this.width,
  });

  final AdminResourceRepository repository;
  final MediaFileRef? mediaRef;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fileRef = mediaRef;
    if (fileRef == null) {
      return SizedBox(
        width: width,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text('—'),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: fileRef.label,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showMediaPreview(context, repository, [fileRef]),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<Map<String, dynamic>>(
                future: repository.fetchMediaFileUrl(fileRef.fileId),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final file = Map<String, dynamic>.from((data?['file'] as Map?) ?? const <String, dynamic>{});
                  final url = data?['url']?.toString() ?? file['public_url']?.toString() ?? '';

                  if (snapshot.connectionState == ConnectionState.waiting && url.isEmpty) {
                    return const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  if (url.isEmpty) {
                    return const Icon(Icons.image_not_supported_outlined, size: 20);
                  }

                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Image.network(
                        url,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
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
                    if (_hasDetailImageButton(resource))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: mediaFiles.isEmpty
                              ? null
                              : () => _showMediaPreview(context, repository, mediaFiles),
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('View image'),
                        ),
                      ),
                    if (resource.key == 'quotes')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _QuoteDocumentsMenu(
                          repository: repository,
                          quote: data,
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
                    if (!_hasDetailImageButton(resource) && mediaFiles.isNotEmpty)
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
                          try {
                            await repository.update(
                              resource,
                              browserState.selectedId!,
                              payload,
                            );
                            ref.invalidate(resourceListProvider(resource));
                            ref.invalidate(resourceDetailsProvider(resource));
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: $error')),
                            );
                          }
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (resource.supportsDelete)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () async {
                          final selectedId = browserState.selectedId;
                          if (selectedId == null) return;

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete row?'),
                              content: const Text('Delete this record?'),
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
                            await repository.delete(resource, selectedId);
                            ref.read(resourceBrowserProvider(resource.key).notifier).select(null);
                            ref.invalidate(resourceListProvider(resource));
                            ref.invalidate(resourceDetailsProvider(resource));
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $error')),
                            );
                          }
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


bool _hasDetailImageButton(AdminResourceDefinition resource) {
  return resource.key == 'catalog_items' || resource.key == 'catalog_variants';
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

  if (resource.key == 'catalog_items' || resource.key == 'catalog_variants') {
    final detailLabel = data['detail_media_filename']?.toString().trim();
    final iconLabel = data['icon_media_filename']?.toString().trim();
    addRef(
      'detail_media_file_id',
      detailLabel == null || detailLabel.isEmpty ? 'Large media' : detailLabel,
      data['detail_media_file_id'],
    );
    if (refs.isEmpty) {
      addRef(
        'icon_media_file_id',
        iconLabel == null || iconLabel.isEmpty ? 'Icon media' : iconLabel,
        data['icon_media_file_id'],
      );
    }
    if (refs.isEmpty && resource.key == 'catalog_variants') {
      final imageLabel = data['image_original_filename']?.toString().trim();
      addRef(
        'image_file_id',
        imageLabel == null || imageLabel.isEmpty ? 'Catalog variant image' : imageLabel,
        data['image_file_id'],
      );
    }
    return refs;
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

class _QuoteDocumentMenuAction {
  const _QuoteDocumentMenuAction({
    required this.fileId,
    required this.label,
  });

  final String fileId;
  final String label;
}

class _QuoteDocumentsMenu extends StatelessWidget {
  const _QuoteDocumentsMenu({
    required this.repository,
    required this.quote,
  });

  final AdminResourceRepository repository;
  final Map<String, dynamic> quote;

  @override
  Widget build(BuildContext context) {
    final quoteId = quote['id']?.toString().trim() ?? '';
    if (quoteId.isEmpty) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: const Text('View documents'),
      );
    }

    return FutureBuilder<ResourceListResponse>(
      future: repository.fetchList(
        findResourceByKey('generated_documents'),
        limit: 20,
        filters: {'quote_id': quoteId},
      ),
      builder: (context, snapshot) {
        final rows = snapshot.data?.items ?? const <Map<String, dynamic>>[];
        final actions = rows
            .map(_quoteDocumentMenuAction)
            .whereType<_QuoteDocumentMenuAction>()
            .toList(growable: false);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final isEnabled = actions.isNotEmpty && !isLoading;

        return PopupMenuButton<_QuoteDocumentMenuAction>(
          tooltip: 'View generated quote documents',
          enabled: isEnabled,
          onSelected: (action) => _openQuoteGeneratedDocument(context, repository, action),
          itemBuilder: (context) => [
            for (final action in actions)
              PopupMenuItem<_QuoteDocumentMenuAction>(
                value: action,
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: isEnabled ? () {} : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('View documents'),
            ),
          ),
        );
      },
    );
  }
}

_QuoteDocumentMenuAction? _quoteDocumentMenuAction(Map<String, dynamic> row) {
  final fileId = _firstText(row['file_id'], row['asset_file_id']);
  if (fileId == null) return null;

  final filename = _firstText(row['output_filename'], row['original_filename']) ?? 'document.pdf';
  final typeLabel = _generatedDocumentTypeLabel(row);
  final createdAt = _firstText(row['created_at']);
  final shortDate = createdAt == null || createdAt.length < 10 ? null : createdAt.substring(0, 10);

  return _QuoteDocumentMenuAction(
    fileId: fileId,
    label: [
      typeLabel,
      if (shortDate != null) shortDate,
      filename,
    ].join(' · '),
  );
}

String _generatedDocumentTypeLabel(Map<String, dynamic> row) {
  final metadata = _mapValue(row['metadata_json']);
  final label = _firstText(
    row['document_type_label'],
    metadata['documentTypeLabel'],
    metadata['document_type_label'],
  );
  if (label != null) return label;

  final code = _firstText(row['document_type_code'], metadata['document_type_code']) ?? 'Document';
  return _humanizeFileFieldKey(code);
}

Future<void> _openQuoteGeneratedDocument(
  BuildContext context,
  AdminResourceRepository repository,
  _QuoteDocumentMenuAction action,
) async {
  try {
    final data = await repository.fetchMediaFileUrl(action.fileId);
    final file = Map<String, dynamic>.from((data['file'] as Map?) ?? const <String, dynamic>{});
    final url = data['url']?.toString() ?? file['public_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw StateError('Generated document URL is empty');
    }
    openMediaUrl(url);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open document failed: $error')),
    );
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _firstText(Object? first, [Object? second, Object? third, Object? fourth]) {
  for (final value in [first, second, third, fourth]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
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

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/http/api_client.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/models/admin_state.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/admin_list_table.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/media_file_actions.dart';
import '../../../core/ui/media_file_picker.dart';
import '../../../core/ui/media_preview_dialog.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/scrollable_areas.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../../../core/ui/searchable_select_form_field.dart';
import '../../calculator/data/calculator_models.dart';
import '../../calculator/data/roof_geometry_calculation.dart';
import '../../calculator/presentation/calculator_providers.dart';
import '../../calculator/presentation/model_geometry_preview.dart';
import 'catalog_item_dependency_tree.dart';
import 'organization_relation_tree.dart';

final _uiDateTimeFormat = DateFormat('dd.MM.yy HH:mm');
final _quoteEuroFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');

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
                onPressed: () => _createResource(context, repository),
                icon: Icon(widget.resource.key == 'asset_files' ? Icons.upload_file_outlined : Icons.add),
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

  Future<void> _createResource(
    BuildContext context,
    AdminResourceRepository repository,
  ) async {
    if (widget.resource.key == 'asset_files') {
      final picked = await pickMediaFile();
      if (picked == null) return;

      try {
        final uploaded = await repository.uploadMediaFile(
          filename: picked.filename,
          contentType: picked.mimeType,
          dataBase64: picked.base64Data,
          purpose: 'media_library',
          metadata: {
            'resource_key': widget.resource.key,
            'field_key': 'media_library_create',
            'file_size_bytes': picked.sizeBytes,
          },
        );
        final uploadedId = uploaded['id']?.toString().trim() ?? '';
        if (uploadedId.isNotEmpty) {
          ref.read(resourceBrowserProvider(widget.resource.key).notifier).select(uploadedId);
        }
        ref.invalidate(resourceListProvider(widget.resource));
        ref.invalidate(resourceDetailsProvider(widget.resource));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded media file: ${picked.filename}')),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $error')),
        );
      }
      return;
    }

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ResourceEditorDialog(
        resource: widget.resource,
        repository: repository,
        initialData: _createInitialData(widget.resource, widget.browserState.filters),
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
  static const double _rowHorizontalPadding = 8;
  static const double _rowVerticalPadding = 6;

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

            final baseColumnWidths = _listColumnWidths(
              resource: resource,
              columns: visibleColumns,
              useCompactLayout: useCompactLayout,
            );
            final fixedContentWidth = adminRowNumberColumnWidth +
                (hasLeadingPreview ? _previewColumnWidth : 0);
            final baseTableContentWidth = fixedContentWidth +
                visibleColumns.fold<double>(
                  0,
                  (sum, column) => sum + (baseColumnWidths[column.key] ?? 0),
                );
            final baseTableWidth = baseTableContentWidth + (_rowHorizontalPadding * 2);

            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewportWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : baseTableWidth;
                      final tableWidth = math.max(baseTableWidth, viewportWidth);
                      final columnWidths = _expandListColumnWidths(
                        columns: visibleColumns,
                        baseWidths: baseColumnWidths,
                        extraWidth: tableWidth - baseTableWidth,
                      );

                      return HorizontalScrollArea(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _rowHorizontalPadding,
                                    vertical: _rowVerticalPadding,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
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
                                          width: useCompactLayout ? columnWidths[column.key] : null,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _rowHorizontalPadding,
                                    vertical: _rowVerticalPadding,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
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
                                          width: useCompactLayout ? columnWidths[column.key] : null,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
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
  required double? width,
}) {

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
  return true;
}

Map<String, double> _listColumnWidths({
  required AdminResourceDefinition resource,
  required List<AdminColumn> columns,
  required bool useCompactLayout,
}) {
  return <String, double>{
    for (final column in columns)
      column.key: useCompactLayout
          ? _compactColumnWidth(resource.key, column)
          : column.flex * 180.0,
  };
}

Map<String, double> _expandListColumnWidths({
  required List<AdminColumn> columns,
  required Map<String, double> baseWidths,
  required double extraWidth,
}) {
  if (extraWidth <= 0 || columns.isEmpty) return baseWidths;

  final totalFlex = columns.fold<int>(
    0,
    (sum, column) => sum + math.max(1, column.flex),
  );
  if (totalFlex <= 0) return baseWidths;

  return <String, double>{
    for (final column in columns)
      column.key: (baseWidths[column.key] ?? 0) +
          extraWidth * (math.max(1, column.flex) / totalFlex),
  };
}

bool _hasLeadingPreviewColumn(AdminResourceDefinition resource) {
  return resource.key == 'catalog_items'
      || resource.key == 'catalog_variants'
      || resource.key == 'asset_files'
      || resource.key == 'organization_branding'
      || resource.key == 'roof_models';
}

bool _hideListColumn(AdminResourceDefinition resource, AdminColumn column) {
  if (resource.key == 'catalog_variants' && column.key == 'image_file_id') return true;
  if (resource.key == 'organization_branding' && column.key == 'logo_file_id') return true;
  return false;
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
      'scope_code' => 120,
      'use_type' => 96,
      'catalog_item_id' => 240,
      'catalog_variant_id' => 240,
      'roof_model_id' => 240,
      'file_id' => 260,
      'is_primary' => 80,
      'is_active' => 80,
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

  if (resourceKey == 'organization_branding') {
    return switch (key) {
      'brand_name' => 220,
      'organization_id' => 240,
      'email_from_name' => 180,
      'is_default' => 80,
      'is_active' => 80,
      _ => 130,
    };
  }

  if (resourceKey == 'roof_models') {
    return switch (key) {
      'code' => 140,
      'name' => 260,
      'product_family_id' => 200,
      'configurator_template_id' => 240,
      'sort_order' => 80,
      'is_active' => 80,
      _ => 130,
    };
  }

  if (resourceKey == 'quotes') {
    return switch (key) {
      'created_at' => 138,
      'quote_no' => 128,
      'quote_no_external' => 170,
      'status_code' => 96,
      'order_type_code' => 104,
      'buyer_organization_id' => 180,
      'configurator_template_id' => 180,
      'calculated_amount_eur' => 130,
      _ => 130,
    };
  }

  return _defaultCompactColumnWidth(column);
}

double _defaultCompactColumnWidth(AdminColumn column) {
  final key = column.key.toLowerCase();
  final label = column.label.toLowerCase();

  if (key == 'id') return 150;
  if (key.endsWith('_id')) return column.lookup == null ? 150 : 180;
  if (key.contains('json')) return 260;
  if (key.contains('date') ||
      key.contains('time') ||
      key.contains('created') ||
      key.contains('updated') ||
      key.contains('expires') ||
      key.contains('valid_from') ||
      key.contains('valid_to')) {
    return 128;
  }
  if (key.startsWith('is_') || key.startsWith('has_') || label == 'active') {
    return 76;
  }
  if (key.contains('price') ||
      key.contains('amount') ||
      key.contains('cost') ||
      key.contains('total') ||
      key.contains('rate')) {
    return 120;
  }
  if (key.contains('name') ||
      key.contains('title') ||
      key.contains('description') ||
      key.contains('notes') ||
      key.contains('label')) {
    return column.flex >= 3 ? 260 : 210;
  }
  if (key.contains('code') ||
      key.contains('type') ||
      key.contains('status') ||
      key.contains('kind') ||
      key.contains('unit') ||
      key.contains('currency')) {
    return 110;
  }

  if (column.flex <= 1) return 120;
  if (column.flex == 2) return 150;
  if (column.flex == 3) return 180;
  return 210;
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

  if (resource.key == 'quotes' && column.key == 'calculated_amount_eur') {
    return _quoteAmountEurDisplay(row);
  }

  if (resource.key == 'quote_events' && column.key == 'quote_id') {
    final quoteNo = row['quote_no']?.toString().trim();
    if (quoteNo != null && quoteNo.isNotEmpty) {
      final parts = <String>[quoteNo];
      final status = row['quote_status_code']?.toString().trim();
      if (status != null && status.isNotEmpty) parts.add(status);

      final createdAt = row['quote_created_at'];
      final createdAtText = createdAt == null ? null : _displayValue(createdAt);
      if (createdAtText != null && createdAtText != '—') parts.add(createdAtText);

      return parts.join(' · ');
    }
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

  if (resource.key == 'organization_branding') {
    return _mediaRefFromRow(
      row: row,
      fileIdKey: 'logo_file_id',
      filenameKey: 'logo_original_filename',
      fallbackLabel: 'Branding logo',
    );
  }

  if (resource.key == 'roof_models') {
    return _mediaRefFromRow(
      row: row,
      fileIdKey: 'preview_media_file_id',
      filenameKey: 'preview_media_filename',
      fallbackLabel: 'Roof model preview',
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
              child: FutureBuilder<ApiBinaryResponse>(
                future: repository.viewMediaFile(fileRef.fileId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final response = snapshot.data;
                  if (snapshot.hasError || response == null || response.bytes.isEmpty) {
                    return const Icon(Icons.image_not_supported_outlined, size: 20);
                  }

                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Image.memory(
                        response.bytes,
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
  bool _showOrganizationTree = false;

  @override
  void didUpdateWidget(covariant _DetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.key != widget.resource.key) {
      _showCatalogItemTree = false;
      _showOrganizationTree = false;
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
        final canShowOrganizationTree =
            resource.key == 'organization_relations' || resource.key == 'organizations';
        final rootCatalogItemId = _catalogItemTreeRootId(resource.key, data, browserState.selectedId);
        final rootOrganizationId = _organizationTreeRootId(resource.key, data, browserState.selectedId);
        final mediaFiles = _mediaFileRefsFor(resource, data);
        final detailLookupLabelsByKey = _detailLookupLabelsByKey(ref, resource);
        final enrichedData = _withReadableRelationFields(resource, data, detailLookupLabelsByKey);
        final quotePreviewContext = resource.key == 'quotes' ? ref.watch(calculatorContextProvider) : null;
        final roofModelLabelsByCode = resource.key == 'quotes'
            ? ref.watch(adminLookupProvider(roofModelLookup)).maybeWhen(
                  data: _roofModelLabelsByCode,
                  orElse: () => const <String, String>{},
                )
            : const <String, String>{};

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _showCatalogItemTree && canShowCatalogItemTree
                          ? 'Dependency tree'
                          : _showOrganizationTree && canShowOrganizationTree
                              ? 'Organization tree'
                              : 'Details',
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
                            : () => setState(() {
                                  _showCatalogItemTree = !_showCatalogItemTree;
                                  if (_showCatalogItemTree) _showOrganizationTree = false;
                                }),
                        icon: Icon(
                          _showCatalogItemTree
                              ? Icons.account_tree_rounded
                              : Icons.account_tree_outlined,
                        ),
                      ),
                    if (canShowOrganizationTree)
                      IconButton(
                        tooltip: _showOrganizationTree ? 'Hide organization tree' : 'Show organization tree',
                        onPressed: rootOrganizationId == null
                            ? null
                            : () => setState(() {
                                  _showOrganizationTree = !_showOrganizationTree;
                                  if (_showOrganizationTree) _showCatalogItemTree = false;
                                }),
                        icon: Icon(
                          _showOrganizationTree
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
                      : _showOrganizationTree && canShowOrganizationTree && rootOrganizationId != null
                          ? OrganizationRelationTree(
                              key: ValueKey('organization-tree-$rootOrganizationId'),
                              repository: repository,
                              rootOrganizationId: rootOrganizationId,
                              onOpenOrganization: (organizationId) => _openOrganization(ref, organizationId),
                            )
                          : _ResourceDetailsContent(
                              resource: resource,
                              data: data,
                              enrichedData: enrichedData,
                              lookupLabelsByKey: detailLookupLabelsByKey,
                              repository: repository,
                              quotePreviewContext: quotePreviewContext,
                              roofModelLabelsByCode: roofModelLabelsByCode,
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


class _ResourceDetailsContent extends StatelessWidget {
  const _ResourceDetailsContent({
    required this.resource,
    required this.data,
    required this.enrichedData,
    required this.lookupLabelsByKey,
    required this.repository,
    required this.quotePreviewContext,
    required this.roofModelLabelsByCode,
  });

  final AdminResourceDefinition resource;
  final Map<String, dynamic> data;
  final Map<String, dynamic> enrichedData;
  final Map<String, Map<String, String>> lookupLabelsByKey;
  final AdminResourceRepository repository;
  final AsyncValue<CalculatorContext>? quotePreviewContext;
  final Map<String, String> roofModelLabelsByCode;

  @override
  Widget build(BuildContext context) {
    if (resource.key == 'quotes') {
      return DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QuoteDetailsSummaryCard(rows: _quoteDetailsSummaryRows()),
            const SizedBox(height: 12),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Preview'),
                Tab(text: 'Details'),
                Tab(text: 'Raw JSON'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _SavedQuoteGeometryPreviewTab(
                    data: data,
                    repository: repository,
                    calculatorContext: quotePreviewContext,
                    roofModelLabelsByCode: roofModelLabelsByCode,
                  ),
                  _detailsListView(context),
                  ListView(children: [JsonViewCard(title: 'Raw JSON', data: enrichedData)]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (resource.key == 'quote_lines') {
      return DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'Raw JSON'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _detailsListView(context),
                  ListView(children: [JsonViewCard(title: 'Raw JSON', data: enrichedData)]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        _MainFieldsCard(
          resource: resource,
          data: data,
          lookupLabelsByKey: lookupLabelsByKey,
        ),
        const SizedBox(height: 16),
        JsonViewCard(title: 'Raw JSON', data: data),
      ],
    );
  }

  List<_DetailRowData> _quoteDetailsSummaryRows() {
    final buyerValue = data['buyer_organization_id'] ?? data['buyerOrganizationId'];

    return [
      _DetailRowData('Quote no', data['quote_no'] ?? data['quoteNo']),
      _DetailRowData(
        'Buyer',
        _displayValue(
          buyerValue,
          lookupLabels: lookupLabelsByKey['buyer_organization_id'],
        ),
      ),
      _DetailRowData('Quote date', data['quote_date'] ?? data['quoteDate']),
      _DetailRowData('Quote type', data['order_type_code'] ?? data['orderTypeCode']),
      _DetailRowData('Amount EUR', _quoteAmountEurDisplay(data)),
    ];
  }

  Widget _detailsListView(BuildContext context) {
    return ListView(
      children: [
        _MainFieldsCard(
          resource: resource,
          data: data,
          lookupLabelsByKey: lookupLabelsByKey,
        ),
      ],
    );
  }
}

class _MainFieldsCard extends StatelessWidget {
  const _MainFieldsCard({
    required this.resource,
    required this.data,
    required this.lookupLabelsByKey,
  });

  final AdminResourceDefinition resource;
  final Map<String, dynamic> data;
  final Map<String, Map<String, String>> lookupLabelsByKey;

  @override
  Widget build(BuildContext context) {
    final rows = _detailRowsFor(resource, data, lookupLabelsByKey);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Main fields', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Expanded(child: SelectableText(_displayValue(row.value))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData(this.label, this.value);

  final String label;
  final Object? value;
}

class _QuoteDetailsSummaryCard extends StatelessWidget {
  const _QuoteDetailsSummaryCard({required this.rows});

  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: [
          for (final row in rows)
            SizedBox(
              width: 190,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    _displayValue(row.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedQuoteGeometryPreviewTab extends StatelessWidget {
  const _SavedQuoteGeometryPreviewTab({
    required this.data,
    required this.repository,
    required this.calculatorContext,
    required this.roofModelLabelsByCode,
  });

  final Map<String, dynamic> data;
  final AdminResourceRepository repository;
  final AsyncValue<CalculatorContext>? calculatorContext;
  final Map<String, String> roofModelLabelsByCode;

  @override
  Widget build(BuildContext context) {
    final draft = _quoteDraftFromDetails(data);
    final modelCode = draft.modelCode?.trim() ?? '';
    final hasModel = modelCode.isNotEmpty;
    final modelLabel = roofModelLabelsByCode[modelCode] ?? modelCode;
    final contextData = calculatorContext?.asData?.value;
    final selectedTemplate = contextData?.templates
        .where((template) => template.id == draft.templateId)
        .cast<CalculatorTemplateOption?>()
        .firstOrNull;
    final resultJson = _mapFromJsonLike(data['result_json'] ?? data['resultJson']);
    final resultSources = _mapFromJsonLike(resultJson['sources']);
    final resultWeights = _mapFromJsonLike(resultJson['weights']);
    final buyerContact = contextData?.buyerContactFor(draft) ?? const CalculatorBuyerContact();
    final handoverName = contextData == null
        ? draft.handoverTypeCode
        : _quoteReferenceLabelFor(contextData, 'handover_types', draft.handoverTypeCode);
    final savedRoofCalculation = roofGeometryCalculationFromSources(resultSources);
    final roofCalculation = savedRoofCalculation ?? (
      contextData == null
          ? null
          : calculateRoofGeometryForDraft(
              draft: draft,
              template: selectedTemplate,
              model: null,
            )
    );
    final colorPreview = calculatorContext?.maybeWhen(
      data: (contextData) => _quoteColorPreviewDataFor(contextData, draft.colorCode),
      orElse: () => _fallbackQuoteColorPreviewData(draft.colorCode),
    ) ?? _fallbackQuoteColorPreviewData(draft.colorCode);
    final coveringName = calculatorContext?.maybeWhen(
      data: (contextData) => _quoteCoveringNameFor(contextData, draft.coveringCode),
      orElse: () => draft.coveringCode,
    ) ?? draft.coveringCode;
    final slope = _savedQuoteSlopePreviewData(data, draft);
    final quoteNo = _quoteTextField(data, 'quote_no', 'quoteNo');
    final quoteNoExternal = _quoteTextField(data, 'quote_no_external', 'quoteNoExternal');
    final externalNotes = _quoteTextField(data, 'external_notes', 'externalNotes');
    final moduleRoles = roofCalculation?.modules.isNotEmpty == true
        ? roofCalculation!.modules.map((module) => module.role).toList(growable: false)
        : draft.setContents.map((module) => module.moduleRole).toList(growable: false);

    return ListView(
      children: [
        if (quoteNoExternal != null || externalNotes != null) ...[
          Text('Customer data', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _QuotePreviewInfoCard(
            rows: [
              if (quoteNoExternal != null) _DetailRowData('Kommission name', quoteNoExternal),
              if (externalNotes != null) _DetailRowData('Quote notes', externalNotes),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text('Roof type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (hasModel)
          _QuotePreviewInfoCard(
            rows: [
              _DetailRowData('Model', modelLabel.isNotEmpty ? modelLabel : modelCode),
              _DetailRowData('Code', modelCode),
            ],
          )
        else
          const _DetailsHintCard(
            icon: Icons.view_in_ar_outlined,
            title: 'No roof type selected',
            text: 'The saved calculation does not contain a selected roof model.',
          ),
        if (hasModel) ...[
          const SizedBox(height: 12),
          ModelGeometryPreview(
            modelCode: modelCode,
            modelLabel: modelLabel,
            mediaRepository: repository,
            widthMm: draft.widthMm,
            depthMm: draft.depthMm,
            heightMm: draft.heightMm,
            geometryParams: geometryPreviewParamsFromDraft(draft),
            modules: draft.setContents,
            moduleRoles: moduleRoles,
            calculatedModules: roofCalculation?.modules ?? const [],
            calculationNumber: quoteNo,
            buyerName: buyerContact.organizationName,
            buyerContactName: buyerContact.contactName,
            buyerEmail: buyerContact.email,
            buyerPhone: buyerContact.phone,
            weights: resultWeights,
            deliveryName: handoverName,
            completionWeek: draft.completionWeek,
            colorCode: colorPreview?.displayCode,
            colorSwatchColor: colorPreview?.color,
            coveringName: coveringName,
            wallMounted: draft.wallMounted,
            postCount: roofCalculation?.postCount ?? 0,
            roofAngleDeg: roofCalculation?.angleDeg ?? slope.angleDeg,
            rearHeightMm: slope.rearHeightMm,
            frontHeightMm: roofCalculation?.frontHeightMm ?? slope.frontHeightMm,
          ),
        ],
      ],
    );
  }
}


String? _quoteReferenceLabelFor(
  CalculatorContext contextData,
  String domain,
  String? rawCode,
) {
  final code = rawCode?.trim();
  if (code == null || code.isEmpty) return null;
  for (final option in contextData.references[domain] ?? const <CalculatorOption>[]) {
    if (option.code == code || option.id == code) return option.label;
  }
  return code;
}

String? _quoteCoveringNameFor(CalculatorContext contextData, String? rawCode) {
  final code = rawCode?.trim();
  if (code == null || code.isEmpty) return null;
  final options = contextData.references['tds_glass_covering'] ?? const <CalculatorOption>[];
  for (final option in options) {
    if (option.code == code || option.id == code) return option.label;
  }
  return code;
}

_SavedQuoteSlopePreviewData _savedQuoteSlopePreviewData(
  Map<String, dynamic> data,
  CalculatorDraft draft,
) {
  final input = _mapFromJsonLike(data['input_json'] ?? data['inputJson']);
  final roof = _mapFromJsonLike(input['roof']);
  final roofSlope = _mapFromJsonLike(input['roof_slope'] ?? input['roofSlope']);

  int? readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  var angle = draft.roofAngleDeg ??
      readInt(roof['angle_deg'] ?? roof['angleDeg']) ??
      readInt(roofSlope['angle_deg'] ?? roofSlope['angleDeg']) ??
      readInt(input['roof_angle_deg'] ?? input['roofAngleDeg'] ?? input['angle_deg']);
  var rear = draft.roofRearHeightMm ??
      readInt(roof['rear_height_mm'] ?? roof['rearHeightMm']) ??
      readInt(roofSlope['rear_height_mm'] ?? roofSlope['rearHeightMm']) ??
      readInt(input['rear_height_mm'] ?? input['rearHeightMm']) ??
      draft.heightMm;
  var front = draft.roofFrontHeightMm ??
      readInt(roof['front_height_mm'] ?? roof['frontHeightMm']) ??
      readInt(roofSlope['front_height_mm'] ?? roofSlope['frontHeightMm']) ??
      readInt(input['front_height_mm'] ?? input['frontHeightMm']);
  final depth = draft.depthMm;

  if (angle == null && rear != null && front != null && depth != null && depth > 0 && rear >= front) {
    angle = (math.atan((rear - front) / depth) * 180 / math.pi).round();
  }
  if (front == null && angle != null && rear != null && depth != null && depth > 0) {
    front = (rear - math.tan(angle * math.pi / 180) * depth).round();
  }
  if (rear == null && angle != null && front != null && depth != null && depth > 0) {
    rear = (front + math.tan(angle * math.pi / 180) * depth).round();
  }

  if (rear != null && front != null && front > rear) {
    front = rear;
  }

  return _SavedQuoteSlopePreviewData(
    angleDeg: angle,
    rearHeightMm: rear,
    frontHeightMm: front,
  );
}

class _SavedQuoteSlopePreviewData {
  const _SavedQuoteSlopePreviewData({
    required this.angleDeg,
    required this.rearHeightMm,
    required this.frontHeightMm,
  });

  final int? angleDeg;
  final int? rearHeightMm;
  final int? frontHeightMm;
}


String? _quoteTextField(Map<String, dynamic> data, String dbKey, String camelKey) {
  String? normalized(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  final direct = normalized(data[dbKey] ?? data[camelKey]);
  if (direct != null) return direct;

  final input = _mapFromJsonLike(data['input_json'] ?? data['inputJson']);
  return normalized(input[dbKey] ?? input[camelKey]);
}

class _DetailsHintCard extends StatelessWidget {
  const _DetailsHintCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(text, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _QuotePreviewInfoCard extends StatelessWidget {
  const _QuotePreviewInfoCard({required this.rows});

  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      _displayValue(row.value),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuoteColorPreviewData {
  const _QuoteColorPreviewData({
    required this.displayCode,
    required this.color,
  });

  final String displayCode;
  final Color? color;
}



bool _hasDetailImageButton(AdminResourceDefinition resource) {
  return resource.key == 'catalog_items' || resource.key == 'catalog_variants' || resource.key == 'roof_models';
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
      final response = await repository.downloadMediaFile(fileRef.fileId);
      downloadMediaBytes(
        response.bytes,
        filename: response.filename ?? fileRef.label,
        contentType: response.contentType,
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

String? _organizationTreeRootId(
  String resourceKey,
  Map<String, dynamic> data,
  String? selectedId,
) {
  if (resourceKey == 'organization_relations') {
    return _extractRelationId(data['parent_organization_id']?.toString() ?? '');
  }
  if (resourceKey == 'organizations') {
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
    final response = await repository.viewMediaFile(action.fileId);
    openMediaBytes(
      response.bytes,
      filename: response.filename ?? action.label,
      contentType: response.contentType,
    );
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

Map<String, dynamic>? _createInitialData(
  AdminResourceDefinition resource,
  Map<String, String> filters,
) {
  if (resource.key != 'reference_domains') return null;

  final hasTableOwner = (filters['object_name'] ?? '').isNotEmpty ||
      (filters['parent_id'] ?? '').isNotEmpty;
  return {
    if (hasTableOwner) 'scope_code': 'table' else 'scope_code': filters['scope_code'] ?? 'system',
    if ((filters['object_name'] ?? '').isNotEmpty) 'object_name': filters['object_name'],
    if ((filters['parent_id'] ?? '').isNotEmpty) 'parent_id': filters['parent_id'],
    if (hasTableOwner) 'code': 'parameters',
    if (hasTableOwner) 'is_system': false,
    'is_active': true,
  };
}

void _openDetailAction(WidgetRef ref, AdminDetailAction action, Map<String, dynamic> data) {
  final targetResource = findResourceByKey(action.targetResourceKey);
  final filterValue = _detailActionValue(action, data);
  if (filterValue == null) return;

  final filters = {
    action.filterKey: filterValue,
    ...action.extraFilters,
  };
  final selectedId = action.selectTargetRow && action.filterKey == 'id' ? filterValue : null;
  ref.read(selectedResourceProvider.notifier).select(
    action.targetResourceKey,
    updateUrl: false,
  );
  ref
      .read(resourceBrowserProvider(action.targetResourceKey).notifier)
      .openWithFilters(
        filters,
        selectedId: selectedId,
      );
  ref.invalidate(resourceListProvider(targetResource));
  ref.invalidate(resourceDetailsProvider(targetResource));
}

void _openCatalogItem(WidgetRef ref, String catalogItemId) {
  final targetResource = findResourceByKey('catalog_items');
  final filters = {'id': catalogItemId};
  ref.read(selectedResourceProvider.notifier).select(
    'catalog_items',
    updateUrl: false,
  );
  ref
      .read(resourceBrowserProvider('catalog_items').notifier)
      .openWithFilters(
        filters,
        selectedId: catalogItemId,
      );
  ref.invalidate(resourceListProvider(targetResource));
  ref.invalidate(resourceDetailsProvider(targetResource));
}

void _openOrganization(WidgetRef ref, String organizationId) {
  final targetResource = findResourceByKey('organizations');
  final filters = {'id': organizationId};
  ref.read(selectedResourceProvider.notifier).select(
    'organizations',
    updateUrl: false,
  );
  ref
      .read(resourceBrowserProvider('organizations').notifier)
      .openWithFilters(
        filters,
        selectedId: organizationId,
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

Map<String, Map<String, String>> _detailLookupLabelsByKey(
  WidgetRef ref,
  AdminResourceDefinition resource,
) {
  if (!_usesReadableDetails(resource)) return const <String, Map<String, String>>{};
  final lookups = _detailRelationLookupsByKey(resource);
  return {
    for (final entry in lookups.entries)
      entry.key: ref.watch(adminLookupProvider(entry.value)).maybeWhen(
            data: (rows) => _lookupLabelMap(entry.value, rows),
            orElse: () => const <String, String>{},
          ),
  };
}

bool _usesReadableDetails(AdminResourceDefinition resource) {
  return resource.key == 'quotes' ||
      resource.key == 'quote_lines' ||
      resource.key == 'roof_models' ||
      resource.key == 'organization_relations';
}

Map<String, AdminLookup> _detailRelationLookupsByKey(AdminResourceDefinition resource) {
  if (resource.key == 'quotes' || resource.key == 'quote_lines') {
    return _quoteRelationLookupsByKey(resource.key);
  }
  return {
    for (final field in resource.formFields)
      if (field.lookup != null) field.key: field.lookup!,
  };
}

Map<String, AdminLookup> _quoteRelationLookupsByKey(String resourceKey) {
  final base = <String, AdminLookup>{
    'quote_id': quoteLookup,
    'base_quote_id': quoteLookup,
    'parent_quote_id': quoteLookup,
    'seller_organization_id': organizationLookup,
    'buyer_organization_id': organizationLookup,
    'ship_to_organization_id': organizationLookup,
    'organization_id': organizationLookup,
    'created_by_user_id': userLookup,
    'updated_by_user_id': userLookup,
    'actor_user_id': userLookup,
    'configurator_template_id': configuratorTemplateLookup,
    'template_id': configuratorTemplateLookup,
    'price_list_id': priceListLookup,
    'sales_price_list_id': salesPriceListLookup,
    'product_family_id': productFamilyLookup,
    'catalog_item_id': catalogItemLookup,
    'catalog_variant_id': catalogVariantLookup,
    'document_template_id': documentTemplateLookup,
  };

  if (resourceKey == 'quote_lines') {
    return {
      'quote_id': quoteLookup,
      'catalog_item_id': catalogItemLookup,
      'catalog_variant_id': catalogVariantLookup,
      'created_by_user_id': userLookup,
      'updated_by_user_id': userLookup,
    };
  }
  return base;
}

List<_DetailRowData> _detailRowsFor(
  AdminResourceDefinition resource,
  Map<String, dynamic> data,
  Map<String, Map<String, String>> lookupLabelsByKey,
) {
  if (!_usesReadableDetails(resource)) {
    return data.entries
        .take(12)
        .map((entry) => _DetailRowData(entry.key, entry.value))
        .toList(growable: false);
  }

  final rows = <_DetailRowData>[];
  final usedKeys = <String>{};

  void addRow(String label, String key, Object? value) {
    if (value == null) return;
    final text = value.toString().trim();
    if (text.isEmpty) return;
    rows.add(_DetailRowData(label, value));
    usedKeys.add(key);
  }

  addRow('ID', 'id', data['id']);

  for (final field in resource.formFields) {
    if (field.type == AdminFieldType.json) continue;
    if (field.key == 'id') continue;
    final value = data[field.key];
    if (field.lookup != null) {
      final label = _readableRelationValue(field.key, value, lookupLabelsByKey);
      addRow(field.label, field.key, label);
      continue;
    }
    if (_isForeignIdKey(field.key)) continue;
    addRow(field.label, field.key, value);
  }

  for (final key in ['created_at', 'updated_at', 'created_by_user_id', 'updated_by_user_id']) {
    if (usedKeys.contains(key) || !data.containsKey(key)) continue;
    final value = _isForeignIdKey(key)
        ? _readableRelationValue(key, data[key], lookupLabelsByKey)
        : data[key];
    addRow(_humanizeKey(key), key, value);
  }

  return rows;
}

Map<String, dynamic> _withReadableRelationFields(
  AdminResourceDefinition resource,
  Map<String, dynamic> data,
  Map<String, Map<String, String>> lookupLabelsByKey,
) {
  if (!_usesReadableDetails(resource)) return data;
  final allLookups = _detailRelationLookupsByKey(resource);
  return _enrichReadableRelations(data, allLookups, lookupLabelsByKey) as Map<String, dynamic>;
}

Object? _enrichReadableRelations(
  Object? value,
  Map<String, AdminLookup> lookupsByKey,
  Map<String, Map<String, String>> lookupLabelsByKey,
) {
  if (value is List) {
    return value
        .map((entry) => _enrichReadableRelations(entry, lookupsByKey, lookupLabelsByKey))
        .toList();
  }
  if (value is! Map) return value;

  final result = <String, dynamic>{};
  value.forEach((rawKey, rawValue) {
    final key = rawKey.toString();
    result[key] = _enrichReadableRelations(rawValue, lookupsByKey, lookupLabelsByKey);

    final relationKey = _relationLookupKeyFor(key, lookupsByKey);
    if (relationKey == null) return;
    final relationLabel = _readableRelationValue(relationKey, rawValue, lookupLabelsByKey);
    if (relationLabel == null || relationLabel.isEmpty) return;

    final nameKey = _relationNameKey(key);
    if (!result.containsKey(nameKey)) {
      result[nameKey] = relationLabel;
    }
  });
  return result;
}

String? _relationLookupKeyFor(String key, Map<String, AdminLookup> lookupsByKey) {
  if (lookupsByKey.containsKey(key)) return key;
  if (key == 'template_id' && lookupsByKey.containsKey('configurator_template_id')) {
    return 'configurator_template_id';
  }
  if (key == 'organization_id' && lookupsByKey.containsKey('organization_id')) {
    return 'organization_id';
  }
  if (key == 'model_id' && lookupsByKey.containsKey('model_id')) {
    return 'model_id';
  }
  return null;
}

String _relationNameKey(String key) {
  if (key.endsWith('_id')) return '${key.substring(0, key.length - 3)}_name';
  return '${key}_name';
}

String? _readableRelationValue(
  String key,
  Object? rawValue,
  Map<String, Map<String, String>> lookupLabelsByKey,
) {
  if (rawValue == null) return null;
  final relationId = _extractRelationId(rawValue.toString());
  if (relationId == null || relationId.isEmpty) return null;
  final label = lookupLabelsByKey[key]?[relationId];
  if (label != null && label.isNotEmpty) return label;
  return rawValue.toString();
}

bool _isForeignIdKey(String key) {
  return key.endsWith('_id') && key != 'id';
}

String _humanizeKey(String key) {
  if (key.isEmpty) return key;
  final words = key.split('_').where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return key;
  return words
      .map((word) => word.length <= 1
          ? word.toUpperCase()
          : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Map<String, String> _roofModelLabelsByCode(List<Map<String, dynamic>> rows) {
  return {
    for (final row in rows)
      if ((row['code']?.toString().trim() ?? '').isNotEmpty)
        row['code']!.toString(): _lookupCompactLabel(roofModelLookup, row),
  };
}

CalculatorDraft _quoteDraftFromDetails(Map<String, dynamic> data) {
  final input = _mapFromJsonLike(data['input_json']);
  final productFamilyId = data['product_family_id']?.toString().trim();
  return CalculatorDraft.fromCalculationJson(
    input,
    productFamilyId: productFamilyId == null || productFamilyId.isEmpty ? null : productFamilyId,
  );
}

Map<String, dynamic> _mapFromJsonLike(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

_QuoteColorPreviewData? _quoteColorPreviewDataFor(
  CalculatorContext contextData,
  String? rawCode,
) {
  final code = _normalizeQuoteRalCode(rawCode);
  if (code == null) return null;

  final colorOptions = contextData.references['colors'] ?? const <CalculatorOption>[];
  final ralColorOptions = contextData.references['ral_colors'] ?? const <CalculatorOption>[];

  CalculatorOption? match;
  for (final option in [...colorOptions, ...ralColorOptions]) {
    if (_normalizeQuoteRalCode(option.code) == code) {
      match = option;
      break;
    }
  }

  final colorHex = _stringFromRaw(
    match?.raw['color_hex'] ??
        match?.raw['colorHex'] ??
        (match?.raw['metadata_json'] is Map ? match?.raw['metadata_json']['color_hex'] : null),
  );

  return _QuoteColorPreviewData(
    displayCode: RegExp(r'^\d{4}$').hasMatch(code) ? 'RAL $code' : code,
    color: _colorFromHex(colorHex),
  );
}

_QuoteColorPreviewData? _fallbackQuoteColorPreviewData(String? rawCode) {
  final code = _normalizeQuoteRalCode(rawCode);
  if (code == null) return null;
  return _QuoteColorPreviewData(
    displayCode: RegExp(r'^\d{4}$').hasMatch(code) ? 'RAL $code' : code,
    color: null,
  );
}

String? _normalizeQuoteRalCode(String? rawCode) {
  final value = rawCode?.trim();
  if (value == null || value.isEmpty) return null;
  final match = RegExp(r'(\d{4})').firstMatch(value);
  if (match != null) return match.group(1);
  return value.toUpperCase();
}

String _stringFromRaw(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

Color? _colorFromHex(String rawHex) {
  var hex = rawHex.trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((char) => '$char$char').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
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

String _quoteAmountEurDisplay(Map<String, dynamic> row) {
  final amount = _quoteAmountEur(row);
  return amount == null ? '—' : _quoteEuroFormat.format(amount);
}

num? _quoteAmountEur(Map<String, dynamic> row) {
  final direct = _firstQuoteAmountIn(row);
  if (direct != null) return direct;

  for (final key in ['totals_json', 'totalsJson', 'result_json', 'resultJson']) {
    final source = _mapFromJsonLike(row[key]);
    if (source.isEmpty) continue;

    final amount = _firstQuoteAmountIn(source);
    if (amount != null) return amount;
  }

  return null;
}

num? _firstQuoteAmountIn(Map<String, dynamic> source) {
  final direct = _firstNumberValue(source, [
    'calculated_amount_eur',
    'amount_eur',
    'total_eur',
    'grand_total_eur',
    'total_amount_eur',
    'sales_total_eur',
    'salesTotalEur',
    'amount',
    'total_amount',
    'totalAmount',
    'grand_total',
    'grandTotal',
    'sales_total',
    'salesTotal',
    'gross',
    'net',
    'subtotal',
    'total',
  ]);
  if (direct != null) return direct;

  for (final key in ['price', 'totals', 'totals_json', 'totalsJson']) {
    final nested = _mapFromJsonLike(source[key]);
    if (nested.isEmpty) continue;

    final amount = _firstNumberValue(nested, [
      'amount_eur',
      'total_eur',
      'grand_total_eur',
      'total_amount_eur',
      'sales_total_eur',
      'salesTotalEur',
      'amount',
      'total_amount',
      'totalAmount',
      'grand_total',
      'grandTotal',
      'sales_total',
      'salesTotal',
      'gross',
      'net',
      'subtotal',
      'total',
      'value',
    ]);
    if (amount != null) return amount;
  }

  return null;
}

num? _firstNumberValue(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final parsed = _numFromRaw(source[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

num? _numFromRaw(Object? value) {
  if (value is num) return value;
  if (value is String) {
    var normalized = value
        .trim()
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '');

    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '.');
    }

    return num.tryParse(normalized);
  }
  return null;
}

String _formatUiDateTime(DateTime value) {
  return _uiDateTimeFormat.format(value.toLocal());
}

String? _formatUiDateString(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) return null;

  final normalized = trimmed.contains('T')
      ? trimmed
      : trimmed.replaceFirst(RegExp(r'\s+'), 'T');
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return null;

  return _formatUiDateTime(parsed);
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
  if (value is DateTime) return _formatUiDateTime(value);
  if (value is String) {
    final formattedDate = _formatUiDateString(value);
    if (formattedDate != null) return formattedDate;
  }
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  return '$value';
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/models/admin_state.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/scrollable_areas.dart';
import '../../../core/ui/resource_editor_dialog.dart';

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
      loading: () => DropdownButtonFormField<String>(
        key: ValueKey('filter-${resource.key}-${filter.key}-$value-loading'),
        initialValue: value.isEmpty ? '' : value,
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('— Not selected —')),
          if (value.isNotEmpty)
            DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: null,
        decoration: InputDecoration(
          labelText: filter.label,
          helperText: 'Loading options...',
        ),
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
        final options = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: '', child: Text('— All —')),
        ];
        var hasCurrentValue = value.isEmpty;

        for (final row in rows) {
          final id = row[lookup.idKey]?.toString();
          if (id == null || id.isEmpty) continue;
          hasCurrentValue = hasCurrentValue || id == value;
          options.add(
            DropdownMenuItem(
              value: id,
              child: Text(
                _lookupLabel(lookup, row),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

        if (!hasCurrentValue) {
          options.add(
            DropdownMenuItem(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          key: ValueKey('filter-${resource.key}-${filter.key}-$value'),
          initialValue: value.isEmpty ? '' : value,
          isExpanded: true,
          items: options,
          onChanged: (nextValue) => browser.setFilter(filter.key, nextValue),
          decoration: InputDecoration(labelText: filter.label),
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
                      width: resource.columns.fold<double>(0, (sum, col) => sum + (col.flex * 180.0)),
                      child: ListView.separated(
                        key: PageStorageKey<String>(
                          'resource-list-${resource.key}-${browserState.query}-$filtersKey-${browserState.offset}-${browserState.limit}',
                        ),
                        itemCount: response.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = response.items[index];
                          final rowId = row['id']?.toString();
                          final isSelected = browserState.selectedId == rowId;
                          return InkWell(
                            onTap: () => browser.select(rowId),
                            child: Container(
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  for (final column in resource.columns)
                                    Expanded(
                                      flex: column.flex,
                                      child: Text(
                                        _displayValue(
                                          row[column.key],
                                          lookupLabels: lookupLabelsByColumn[column.key],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: column.isPrimary
                                            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        )
                                            : null,
                                      ),
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
                Row(
                  children: [
                    Text('Rows: ${response.items.length} / total: ${response.total}'),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: browserState.offset == 0 ? null : browser.previousPage,
                      child: const Text('Prev'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: response.items.length < browserState.limit ? null : browser.nextPage,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({
    required this.resource,
    required this.detailsAsync,
  });

  final AdminResourceDefinition resource;
  final AsyncValue<Map<String, dynamic>?> detailsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final repository = ref.read(resourceRepositoryProvider);

    return detailsAsync.when(
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

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Details', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    for (final action in resource.detailActions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: _detailActionValue(action, data) == null
                              ? null
                              : () {
                            final targetResource = findResourceByKey(action.targetResourceKey);
                            final filterValue = _detailActionValue(action, data)!;
                            final filters = {action.filterKey: filterValue};
                            ref
                                .read(resourceBrowserProvider(action.targetResourceKey).notifier)
                                .setFilter(action.filterKey, filterValue);
                            ref.read(selectedResourceProvider.notifier).select(
                              action.targetResourceKey,
                              filters: filters,
                            );
                            ref.invalidate(resourceListProvider(targetResource));
                          },
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                        ),
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
                  child: ListView(
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
  return value;
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
  if (id.isEmpty) return compactLabel;
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

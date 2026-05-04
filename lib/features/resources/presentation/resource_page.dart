import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/models/admin_resource.dart';
import '../../../core/models/admin_state.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/ui/json_view_card.dart';
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
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _ListCard(resource: resource, listAsync: listAsync)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _DetailsCard(resource: resource, detailsAsync: detailsAsync)),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _ListCard(resource: resource, listAsync: listAsync)),
                    const SizedBox(height: 16),
                    Expanded(child: _DetailsCard(resource: resource, detailsAsync: detailsAsync)),
                  ],
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

    return Row(
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: resource.columns.fold<double>(0, (sum, col) => sum + (col.flex * 180.0)),
                      child: ListView.separated(
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
                                        _displayValue(row[column.key]),
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

String _displayValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(value);
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  return '$value';
}

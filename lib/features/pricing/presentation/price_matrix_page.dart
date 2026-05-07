import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/admin_list_table.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/scrollable_areas.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../data/price_matrix_repository.dart';
import 'price_matrix_providers.dart';

class PriceMatrixPage extends ConsumerWidget {
  const PriceMatrixPage({
    super.key,
    this.initialMode = PriceMatrixPageMode.matrices,
  });

  final PriceMatrixPageMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMatrixAsync = ref.watch(selectedPriceMatrixProvider);
    final cellsAsync = ref.watch(priceMatrixCellsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1360;

    return DefaultTabController(
      initialIndex: initialMode == PriceMatrixPageMode.cells ? 1 : 0,
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(),
          const SizedBox(height: 16),
          const _MatrixToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: isWide
                ? ResizableSplitPane(
                    axis: Axis.horizontal,
                    initialFraction: 0.4,
                    minFirstFraction: 0.25,
                    minSecondFraction: 0.35,
                    first: const _MatrixListCard(),
                    second: ResizableSplitPane(
                      axis: Axis.vertical,
                      initialFraction: 0.34,
                      minFirstFraction: 0.18,
                      minSecondFraction: 0.35,
                      first: _MatrixDetailsCard(detailsAsync: selectedMatrixAsync),
                      second: _CellsWorkspace(cellsAsync: cellsAsync),
                    ),
                  )
                : ResizableSplitPane(
                    axis: Axis.vertical,
                    initialFraction: 0.35,
                    minFirstFraction: 0.2,
                    minSecondFraction: 0.35,
                    first: const _MatrixListCard(),
                    second: ResizableSplitPane(
                      axis: Axis.vertical,
                      initialFraction: 0.34,
                      minFirstFraction: 0.18,
                      minSecondFraction: 0.35,
                      first: _MatrixDetailsCard(detailsAsync: selectedMatrixAsync),
                      second: _CellsWorkspace(cellsAsync: cellsAsync),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

enum PriceMatrixPageMode { matrices, cells }

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_on_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Price Matrices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Специализированный экран для матриц цен и их ячеек. '
          'Слева — список матриц, справа — детали, ячейки и grid-preview.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MatrixToolbar extends ConsumerStatefulWidget {
  const _MatrixToolbar();

  @override
  ConsumerState<_MatrixToolbar> createState() => _MatrixToolbarState();
}

class _MatrixToolbarState extends ConsumerState<_MatrixToolbar> {
  late final TextEditingController _matrixSearchController;
  late final TextEditingController _cellSearchController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(priceMatrixBrowserProvider);
    _matrixSearchController = TextEditingController(text: state.matrixQuery);
    _cellSearchController = TextEditingController(text: state.cellQuery);
  }

  @override
  void dispose() {
    _matrixSearchController.dispose();
    _cellSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.read(priceMatrixBrowserProvider.notifier);
    final repository = ref.read(priceMatrixRepositoryProvider);
    final adminResourceRepository = ref.read(resourceRepositoryProvider);
    final matrixResource = findResourceByKey('price_matrices');
    final browserState = ref.watch(priceMatrixBrowserProvider);
    final selectedMatrixId = browserState.selectedMatrixId;
    final priceListOptions = ref.watch(adminLookupProvider(priceListLookup));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _matrixSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search matrix code / name / section',
            ),
            onSubmitted: browser.setMatrixQuery,
          ),
        ),
        SizedBox(
          width: 300,
          child: _PriceListFilter(
            value: browserState.priceListId,
            options: priceListOptions,
            onChanged: browser.setPriceListFilter,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => browser.setMatrixQuery(_matrixSearchController.text.trim()),
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('Apply matrix filter'),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _cellSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.grid_view_rounded),
              hintText: 'Filter cells by cell ref',
            ),
            onSubmitted: browser.setCellQuery,
          ),
        ),
        OutlinedButton.icon(
          onPressed: selectedMatrixId == null
              ? null
              : () => browser.setCellQuery(_cellSearchController.text.trim()),
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Apply cell filter'),
        ),
        IconButton(
          tooltip: 'Refresh matrices and cells',
          onPressed: () {
            ref.invalidate(priceMatrixListProvider);
            ref.invalidate(selectedPriceMatrixProvider);
            ref.invalidate(priceMatrixCellsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: () async {
            final payload = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => ResourceEditorDialog(
                resource: matrixResource,
                repository: adminResourceRepository,
              ),
            );
            if (payload == null) return;
            await repository.createMatrix(payload);
            ref.invalidate(priceMatrixListProvider);
          },
          icon: const Icon(Icons.add),
          label: const Text('Create matrix'),
        ),
      ],
    );
  }
}


class _PriceListFilter extends StatelessWidget {
  const _PriceListFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final AsyncValue<List<Map<String, dynamic>>> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return options.when(
      loading: () => DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? '' : value,
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('— All price lists —')),
          if (value.isNotEmpty) DropdownMenuItem(value: value, child: Text(value)),
        ],
        onChanged: null,
        decoration: const InputDecoration(
          labelText: 'Price list',
          helperText: 'Loading options...',
        ),
      ),
      error: (_, __) => TextFormField(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Price list',
          helperText: 'Lookup failed; paste id manually',
        ),
        onFieldSubmitted: onChanged,
      ),
      data: (rows) {
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: '', child: Text('— All price lists —')),
        ];
        var hasValue = value.isEmpty;
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;
          hasValue = hasValue || id == value;
          items.add(
            DropdownMenuItem(
              value: id,
              child: Text(_priceListLabel(row), overflow: TextOverflow.ellipsis),
            ),
          );
        }
        if (!hasValue) {
          items.add(DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis)));
        }

        return DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? '' : value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(labelText: 'Price list'),
        );
      },
    );
  }
}

class _MatrixListCard extends ConsumerWidget {
  const _MatrixListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(priceMatrixListProvider);
    final browserState = ref.watch(priceMatrixBrowserProvider);
    final browser = ref.read(priceMatrixBrowserProvider.notifier);
    final priceListLabels = ref.watch(adminLookupProvider(priceListLookup)).maybeWhen(
      data: _lookupLabelMap,
      orElse: () => const <String, String>{},
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(error: error),
          data: (response) {
            if (response.items.isEmpty) {
              return const Center(child: Text('No price matrices found'));
            }

            if (browserState.selectedMatrixId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                browser.selectMatrix(response.items.first.id);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matrices', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    key: const PageStorageKey<String>('price-matrix-list'),
                    itemCount: response.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              AdminRowNumberHeader(),
                              AdminTableHeaderCell(label: 'Matrix code', flex: 3),
                              AdminTableHeaderCell(label: 'Name', flex: 4),
                              AdminTableHeaderCell(label: 'Price list', flex: 3),
                              AdminTableHeaderCell(label: 'Parser / sheet', flex: 4),
                              AdminTableHeaderCell(label: 'Status', flex: 2),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final matrix = response.items[rowIndex];
                      final priceListName = _lookupLabelForId(matrix.priceListId, priceListLabels);
                      final isSelected = browserState.selectedMatrixId == matrix.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => browser.selectMatrix(matrix.id),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminRowNumberCell(index: rowIndex, offset: browserState.offset),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      matrix.matrixCode,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  _StatusChip(
                                    label: matrix.isActive ? 'Active' : 'Inactive',
                                    active: matrix.isActive,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(matrix.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (priceListName.isNotEmpty)
                                    _MetaChip(icon: Icons.request_quote_outlined, label: priceListName),
                                  _MetaChip(icon: Icons.tune, label: matrix.parserKind),
                                  _MetaChip(icon: Icons.table_chart_outlined, label: matrix.sourceSheetName),
                                  if ((matrix.sectionCode ?? '').isNotEmpty)
                                    _MetaChip(icon: Icons.segment_rounded, label: matrix.sectionCode!),
                                ],
                              ),
                                  ],
                                ),
                              ),
                            ],
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

class _MatrixDetailsCard extends ConsumerWidget {
  const _MatrixDetailsCard({required this.detailsAsync});

  final AsyncValue<PriceMatrix?> detailsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(priceMatrixRepositoryProvider);
    final adminResourceRepository = ref.read(resourceRepositoryProvider);
    final browser = ref.read(priceMatrixBrowserProvider.notifier);
    final selectedMatrixId = ref.watch(priceMatrixBrowserProvider.select((value) => value.selectedMatrixId));
    final matrixResource = findResourceByKey('price_matrices');
    final priceListLabels = ref.watch(adminLookupProvider(priceListLookup)).maybeWhen(
      data: _lookupLabelMap,
      orElse: () => const <String, String>{},
    );

    return detailsAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (matrix) {
        if (selectedMatrixId == null) {
          return const Card(child: Center(child: Text('Select a matrix to inspect details')));
        }
        if (matrix == null) {
          return const Card(child: Center(child: Text('Matrix details not found')));
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(matrix.matrixCode, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(matrix.name),
                        ],
                      ),
                    ),
                    _StatusChip(label: matrix.isActive ? 'Active' : 'Inactive', active: matrix.isActive),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit matrix',
                      onPressed: () async {
                        final payload = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => ResourceEditorDialog(
                            resource: matrixResource,
                            repository: adminResourceRepository,
                            initialData: matrix.raw,
                          ),
                        );
                        if (payload == null) return;
                        await repository.updateMatrix(matrix.id, payload);
                        ref.invalidate(priceMatrixListProvider);
                        ref.invalidate(selectedPriceMatrixProvider);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete matrix',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete matrix?'),
                                content: Text('Delete ${matrix.matrixCode} and refresh the list?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (!confirmed) return;
                        await repository.deleteMatrix(matrix.id);
                        browser.selectMatrix(null);
                        ref.invalidate(priceMatrixListProvider);
                        ref.invalidate(selectedPriceMatrixProvider);
                        ref.invalidate(priceMatrixCellsProvider);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _InfoTile(label: 'Parser', value: matrix.parserKind),
                          _InfoTile(label: 'Section', value: matrix.sectionCode ?? matrix.sectionLabel ?? '—'),
                          _InfoTile(label: 'Sheet', value: matrix.sourceSheetName),
                          _InfoTile(
                            label: 'Source anchor',
                            value: 'row ${matrix.sourceRowNo ?? '—'} / col ${matrix.sourceColNo ?? '—'}',
                          ),
                          _InfoTile(
                            label: 'Price list',
                            value: _lookupLabelForId(matrix.priceListId, priceListLabels).ifEmpty('—'),
                          ),
                          _InfoTile(label: 'Sort order', value: '${matrix.sortOrder ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if ((matrix.phaseLabel ?? '').isNotEmpty ||
                          (matrix.productLabel ?? '').isNotEmpty ||
                          (matrix.subtitleLabel ?? '').isNotEmpty)
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Labels', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 12),
                                _DetailRow(label: 'Phase', value: matrix.phaseLabel ?? '—'),
                                _DetailRow(label: 'Product', value: matrix.productLabel ?? '—'),
                                _DetailRow(label: 'Subtitle', value: matrix.subtitleLabel ?? '—'),
                                _DetailRow(label: 'Section label', value: matrix.sectionLabel ?? '—'),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      JsonViewCard(title: 'Header JSON', data: matrix.headerJson ?? const {}),
                      const SizedBox(height: 16),
                      JsonViewCard(title: 'Metadata JSON', data: matrix.metadataJson ?? const {}),
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

class _CellsWorkspace extends StatelessWidget {
  const _CellsWorkspace({required this.cellsAsync});

  final AsyncValue<PriceMatrixCellListResponse?> cellsAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matrix cells', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Cells table'),
                Tab(text: 'Grid preview'),
                Tab(text: 'Raw JSON'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _CellsTableTab(cellsAsync: cellsAsync),
                  _CellsGridTab(cellsAsync: cellsAsync),
                  _CellsJsonTab(cellsAsync: cellsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CellsTableTab extends ConsumerWidget {
  const _CellsTableTab({required this.cellsAsync});

  final AsyncValue<PriceMatrixCellListResponse?> cellsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(priceMatrixRepositoryProvider);
    final browser = ref.read(priceMatrixBrowserProvider.notifier);
    final browserState = ref.watch(priceMatrixBrowserProvider);
    final cellResource = findResourceByKey('price_matrix_cells');

    return cellsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (response) {
        if (browserState.selectedMatrixId == null) {
          return const Center(child: Text('Select a matrix to load cells'));
        }
        if (response == null || response.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No cells for selected matrix'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final payload = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => ResourceEditorDialog(
                        resource: cellResource,
                        initialData: {
                          'price_matrix_id': browserState.selectedMatrixId,
                          'row_no': 1,
                          'col_no': 1,
                          'unit_price': 0,
                          'dimensions_json': const <String, dynamic>{},
                          'metadata_json': const <String, dynamic>{},
                        },
                      ),
                    );
                    if (payload == null) return;
                    await repository.createCell(payload);
                    ref.invalidate(priceMatrixCellsProvider);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add first cell'),
                ),
              ],
            ),
          );
        }

        final selectedCell = response.items.firstWhere(
          (cell) => cell.id == browserState.selectedCellId,
          orElse: () => response.items.first,
        );

        if (browserState.selectedCellId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            browser.selectCell(selectedCell.id);
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1080;
            final table = _CellTable(
              cells: response.items,
              selectedCellId: browserState.selectedCellId,
              onSelect: browser.selectCell,
            );
            final details = _CellDetailsCard(
              cell: selectedCell,
              onEdit: () async {
                final payload = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => ResourceEditorDialog(
                    resource: cellResource,
                    initialData: selectedCell.raw,
                  ),
                );
                if (payload == null) return;
                await repository.updateCell(selectedCell.id, payload);
                ref.invalidate(priceMatrixCellsProvider);
              },
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete cell?'),
                        content: Text('Delete ${selectedCell.cellRef}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (!confirmed) return;
                await repository.deleteCell(selectedCell.id);
                browser.selectCell(null);
                ref.invalidate(priceMatrixCellsProvider);
              },
            );

            final createButton = Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  final payload = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ResourceEditorDialog(
                      resource: cellResource,
                      initialData: {
                        'price_matrix_id': browserState.selectedMatrixId,
                        'row_no': 1,
                        'col_no': 1,
                        'unit_price': 0,
                        'dimensions_json': const <String, dynamic>{},
                        'metadata_json': const <String, dynamic>{},
                      },
                    ),
                  );
                  if (payload == null) return;
                  await repository.createCell(payload);
                  ref.invalidate(priceMatrixCellsProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add cell'),
              ),
            );

            if (isWide) {
              return Column(
                children: [
                  createButton,
                  const SizedBox(height: 12),
                  Expanded(
                    child: ResizableSplitPane(
                      axis: Axis.horizontal,
                      initialFraction: 0.6,
                      minFirstFraction: 0.35,
                      minSecondFraction: 0.25,
                      first: table,
                      second: details,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                createButton,
                const SizedBox(height: 12),
                Expanded(
                  child: ResizableSplitPane(
                    axis: Axis.vertical,
                    initialFraction: 0.6,
                    minFirstFraction: 0.35,
                    minSecondFraction: 0.25,
                    first: table,
                    second: details,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CellTable extends StatelessWidget {
  const _CellTable({
    required this.cells,
    required this.selectedCellId,
    required this.onSelect,
  });

  final List<PriceMatrixCell> cells;
  final String? selectedCellId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cells table', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: HorizontalScrollArea(
                child: SizedBox(
                  width: adminRowNumberColumnWidth + 980,
                  child: ListView.separated(
                    key: PageStorageKey<String>(
                      'price-matrix-cell-list-${cells.isEmpty ? "empty" : cells.first.priceMatrixId}',
                    ),
                    itemCount: cells.length + 1,
                    separatorBuilder: (_, index) => index == 0
                        ? const Divider(height: 2)
                        : const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              AdminRowNumberHeader(),
                              AdminTableHeaderCell(width: 90, label: 'Cell'),
                              AdminTableHeaderCell(width: 80, label: 'Row'),
                              AdminTableHeaderCell(width: 80, label: 'Col'),
                              AdminTableHeaderCell(width: 120, label: 'Width mm'),
                              AdminTableHeaderCell(width: 120, label: 'Height mm'),
                              AdminTableHeaderCell(width: 120, label: 'Depth mm'),
                              AdminTableHeaderCell(width: 100, label: 'Width bucket'),
                              AdminTableHeaderCell(width: 80, label: 'Beams'),
                              AdminTableHeaderCell(width: 80, label: 'Posts'),
                              AdminTableHeaderCell(width: 140, label: 'Unit price'),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final cell = cells[rowIndex];
                      final isSelected = selectedCellId == cell.id;
                      return InkWell(
                        onTap: () => onSelect(cell.id),
                        child: Container(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              AdminRowNumberCell(index: rowIndex),
                              _TableValue(width: 90, value: cell.cellRef, strong: true),
                              _TableValue(width: 80, value: '${cell.rowNo}'),
                              _TableValue(width: 80, value: '${cell.colNo}'),
                              _TableValue(width: 120, value: _formatNumber(cell.widthMm)),
                              _TableValue(width: 120, value: _formatNumber(cell.heightMm)),
                              _TableValue(width: 120, value: _formatNumber(cell.depthMm)),
                              _TableValue(width: 100, value: cell.widthBucketCode ?? '—'),
                              _TableValue(width: 80, value: _formatNumber(cell.beamCount)),
                              _TableValue(width: 80, value: _formatNumber(cell.postCount)),
                              _TableValue(width: 140, value: _formatPrice(cell.unitPrice)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableValue extends StatelessWidget {
  const _TableValue({
    required this.width,
    required this.value,
    this.strong = false,
  });

  final double width;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: strong
            ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
            : null,
      ),
    );
  }
}

class _CellDetailsCard extends StatelessWidget {
  const _CellDetailsCard({
    required this.cell,
    required this.onEdit,
    required this.onDelete,
  });

  final PriceMatrixCell? cell;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (cell == null) {
      return const Card(child: Center(child: Text('Select a cell to inspect details')));
    }

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(cell!.cellRef, style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Row / col', value: '${cell!.rowNo} / ${cell!.colNo}'),
            _DetailRow(label: 'Width mm', value: _formatNumber(cell!.widthMm)),
            _DetailRow(label: 'Height mm', value: _formatNumber(cell!.heightMm)),
            _DetailRow(label: 'Depth mm', value: _formatNumber(cell!.depthMm)),
            _DetailRow(label: 'Depth m', value: cell!.depthM?.toStringAsFixed(3) ?? '—'),
            _DetailRow(label: 'Width bucket', value: cell!.widthBucketCode ?? '—'),
            _DetailRow(label: 'Beam count', value: _formatNumber(cell!.beamCount)),
            _DetailRow(label: 'Post count', value: _formatNumber(cell!.postCount)),
            _DetailRow(label: 'Unit price', value: _formatPrice(cell!.unitPrice)),
            const SizedBox(height: 16),
            JsonViewCard(title: 'Dimensions JSON', data: cell!.dimensionsJson ?? const {}),
            const SizedBox(height: 16),
            JsonViewCard(title: 'Metadata JSON', data: cell!.metadataJson ?? const {}),
          ],
        ),
      ),
    );
  }
}

class _CellsGridTab extends StatelessWidget {
  const _CellsGridTab({required this.cellsAsync});

  final AsyncValue<PriceMatrixCellListResponse?> cellsAsync;

  @override
  Widget build(BuildContext context) {
    return cellsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (response) {
        if (response == null || response.items.isEmpty) {
          return const Center(child: Text('No cells to preview'));
        }

        final maxRow = response.items.fold<int>(0, (max, cell) => cell.rowNo > max ? cell.rowNo : max);
        final maxCol = response.items.fold<int>(0, (max, cell) => cell.colNo > max ? cell.colNo : max);
        final byRef = <String, PriceMatrixCell>{
          for (final cell in response.items) '${cell.rowNo}:${cell.colNo}': cell,
        };

        return BidirectionalScrollArea(
          child: DataTable(
              columnSpacing: 18,
              columns: [
                const DataColumn(label: Text('Row \\ Col')),
                for (var col = 1; col <= maxCol; col++) DataColumn(label: Text('C$col')),
              ],
              rows: [
                for (var row = 1; row <= maxRow; row++)
                  DataRow(
                    cells: [
                      DataCell(Text('R$row')),
                      for (var col = 1; col <= maxCol; col++)
                        DataCell(
                          _GridCell(
                            cell: byRef['$row:$col'],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({this.cell});

  final PriceMatrixCell? cell;

  @override
  Widget build(BuildContext context) {
    if (cell == null) {
      return const SizedBox(width: 90, child: Text('—'));
    }

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cell!.cellRef,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(_formatPrice(cell!.unitPrice)),
          if (cell!.widthMm != null || cell!.depthMm != null)
            Text('w ${_formatNumber(cell!.widthMm)} / d ${_formatNumber(cell!.depthMm)}'),
        ],
      ),
    );
  }
}

class _CellsJsonTab extends StatelessWidget {
  const _CellsJsonTab({required this.cellsAsync});

  final AsyncValue<PriceMatrixCellListResponse?> cellsAsync;

  @override
  Widget build(BuildContext context) {
    return cellsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (response) {
        if (response == null) {
          return const Center(child: Text('No matrix selected'));
        }

        return ListView(
          children: [
            JsonViewCard(
              title: 'Cells JSON',
              data: {
                'total': response.total,
                'items': response.items.map((cell) => cell.raw).toList(),
              },
            ),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: active ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
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


Map<String, String> _lookupLabelMap(List<Map<String, dynamic>> rows) {
  return {
    for (final row in rows)
      if ((row['id']?.toString().trim() ?? '').isNotEmpty) row['id']!.toString(): _priceListLabel(row),
  };
}

String _priceListLabel(Map<String, dynamic> row) {
  final name = row['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final code = row['code']?.toString().trim();
  if (code != null && code.isNotEmpty) return code;
  return row['id']?.toString() ?? '';
}

String _lookupLabelForId(String? id, Map<String, String> labels) {
  final safeId = id?.trim() ?? '';
  if (safeId.isEmpty) return '';
  return labels[safeId] ?? safeId;
}

extension _EmptyStringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

String _formatNumber(Object? value) {
  if (value == null) return '—';
  if (value is num) return NumberFormat.decimalPattern('de_DE').format(value);
  return value.toString();
}

String _formatPrice(num value) {
  return '${NumberFormat.decimalPattern('de_DE').format(value)} €';
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/admin_registry.dart';
import '../../../core/ui/admin_list_table.dart';
import '../../../core/ui/header_focus_icon_button.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../data/rule_set_repository.dart';
import 'rule_workspace_providers.dart';

class RuleWorkspacePage extends ConsumerWidget {
  const RuleWorkspacePage({
    super.key,
    this.initialMode = RuleWorkspaceMode.rows,
  });

  final RuleWorkspaceMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRuleSetAsync = ref.watch(selectedRuleSetProvider);
    final selectedRuleMatrixAsync = ref.watch(selectedRuleMatrixProvider);
    final matricesAsync = ref.watch(ruleMatricesProvider);
    final rowsAsync = ref.watch(ruleMatrixRowsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1440;
    final focusDependentLayer = ref.watch(ruleDependentLayerFocusProvider);

    return DefaultTabController(
      initialIndex: switch (initialMode) {
        RuleWorkspaceMode.rows => 0,
        RuleWorkspaceMode.matrices => 1,
        RuleWorkspaceMode.ruleSets => 2,
      },
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(),
          const SizedBox(height: 16),
          const _RuleSetToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: isWide
                ? ResizableSplitPane(
                    axis: Axis.horizontal,
                    initialFraction: focusDependentLayer ? 0.0 : 0.3,
                    minFirstFraction: focusDependentLayer ? 0.0 : 0.2,
                    minSecondFraction: 0.45,
                    first: const _RuleSetListCard(),
                    second: ResizableSplitPane(
                      axis: Axis.vertical,
                      initialFraction: focusDependentLayer ? 0.12 : 0.32,
                      minFirstFraction: focusDependentLayer ? 0.10 : 0.18,
                      minSecondFraction: 0.35,
                      first: _RuleSetDetailsCard(detailsAsync: selectedRuleSetAsync),
                      second: _RuleWorkspace(
                      selectedRuleSetAsync: selectedRuleSetAsync,
                      selectedRuleMatrixAsync: selectedRuleMatrixAsync,
                      matricesAsync: matricesAsync,
                      rowsAsync: rowsAsync,
                    ),
                    ),
                  )
                : ResizableSplitPane(
                    axis: Axis.vertical,
                    initialFraction: focusDependentLayer ? 0.0 : 0.3,
                    minFirstFraction: focusDependentLayer ? 0.0 : 0.2,
                    minSecondFraction: 0.45,
                    first: const _RuleSetListCard(),
                    second: ResizableSplitPane(
                      axis: Axis.vertical,
                      initialFraction: focusDependentLayer ? 0.12 : 0.32,
                      minFirstFraction: focusDependentLayer ? 0.10 : 0.18,
                      minSecondFraction: 0.35,
                      first: _RuleSetDetailsCard(detailsAsync: selectedRuleSetAsync),
                      second: _RuleWorkspace(
                      selectedRuleSetAsync: selectedRuleSetAsync,
                      selectedRuleMatrixAsync: selectedRuleMatrixAsync,
                      matricesAsync: matricesAsync,
                      rowsAsync: rowsAsync,
                    ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

enum RuleWorkspaceMode { ruleSets, matrices, rows }

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rule Sets workspace', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Управление версиями правил, матрицами правил и строками key/result из live-imported workbook logic.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _RuleSetToolbar extends ConsumerStatefulWidget {
  const _RuleSetToolbar();

  @override
  ConsumerState<_RuleSetToolbar> createState() => _RuleSetToolbarState();
}

class _RuleSetToolbarState extends ConsumerState<_RuleSetToolbar> {
  late final TextEditingController _ruleSetQueryController;

  @override
  void initState() {
    super.initState();
    _ruleSetQueryController = TextEditingController();
  }

  @override
  void dispose() {
    _ruleSetQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.read(ruleWorkspaceProvider.notifier);
    final repository = ref.read(ruleSetRepositoryProvider);
    final ruleSetResource = findResourceByKey('rule_sets');

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _ruleSetQueryController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search rule sets',
              hintText: 'version, workbook, notes, status...',
            ),
            onSubmitted: browser.setRuleSetQuery,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => browser.setRuleSetQuery(_ruleSetQueryController.text.trim()),
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Apply filter'),
        ),
        IconButton(
          tooltip: 'Refresh rule sets / matrices / rows',
          onPressed: () {
            ref.invalidate(ruleSetListProvider);
            ref.invalidate(selectedRuleSetProvider);
            ref.invalidate(ruleMatricesProvider);
            ref.invalidate(selectedRuleMatrixProvider);
            ref.invalidate(ruleMatrixRowsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: () async {
            final payload = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => ResourceEditorDialog(resource: ruleSetResource),
            );
            if (payload == null) return;
            await repository.createRuleSet(payload);
            ref.invalidate(ruleSetListProvider);
          },
          icon: const Icon(Icons.add),
          label: const Text('Create rule set'),
        ),
      ],
    );
  }
}

class _RuleSetListCard extends ConsumerWidget {
  const _RuleSetListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(ruleSetListProvider);
    final browserState = ref.watch(ruleWorkspaceProvider);
    final browser = ref.read(ruleWorkspaceProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(error: error),
          data: (response) {
            if (response.items.isEmpty) {
              return const Center(child: Text('No rule sets found'));
            }

            if (browserState.selectedRuleSetId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                browser.selectRuleSet(response.items.first.id);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rule sets', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    key: const PageStorageKey<String>('rule-set-list'),
                    itemCount: response.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              AdminRowNumberHeader(),
                              AdminTableHeaderCell(label: 'Version', flex: 2),
                              AdminTableHeaderCell(label: 'Template / notes', flex: 5),
                              AdminTableHeaderCell(label: 'Valid from', flex: 3),
                              AdminTableHeaderCell(label: 'Status', flex: 2),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final ruleSet = response.items[rowIndex];
                      final isSelected = browserState.selectedRuleSetId == ruleSet.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => browser.selectRuleSet(ruleSet.id),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AdminRowNumberCell(index: rowIndex, offset: browserState.offset),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'v${ruleSet.version}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  _StatusChip(label: ruleSet.statusCode, active: ruleSet.statusCode == 'published'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ruleSet.notes?.isNotEmpty == true
                                    ? ruleSet.notes!
                                    : 'Template ${ruleSet.configuratorTemplateId}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    icon: Icons.calendar_month_outlined,
                                    label: _dateLabel(ruleSet.validFrom),
                                  ),
                                  _MetaChip(
                                    icon: Icons.rule_folder_outlined,
                                    label: 'Template ${_shortId(ruleSet.configuratorTemplateId)}',
                                  ),
                                ],
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

class _RuleSetDetailsCard extends ConsumerWidget {
  const _RuleSetDetailsCard({required this.detailsAsync});

  final AsyncValue<RuleSet?> detailsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(ruleSetRepositoryProvider);
    final browser = ref.read(ruleWorkspaceProvider.notifier);
    final selectedRuleSetId = ref.watch(ruleWorkspaceProvider.select((value) => value.selectedRuleSetId));
    final ruleSetResource = findResourceByKey('rule_sets');
    final focusDependentLayer = ref.watch(ruleDependentLayerFocusProvider);

    return detailsAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (ruleSet) {
        if (selectedRuleSetId == null) {
          return const Card(child: Center(child: Text('Select a rule set to inspect details')));
        }
        if (ruleSet == null) {
          return const Card(child: Center(child: Text('Rule set details not found')));
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeaderFocusIconButton(
                      focused: focusDependentLayer,
                      onPressed: () => ref.read(ruleDependentLayerFocusProvider.notifier).toggle(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rule set v${ruleSet.version}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Template ${ruleSet.configuratorTemplateId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(
                      label: ruleSet.statusCode,
                      active: ruleSet.statusCode == 'published',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit rule set',
                      onPressed: () async {
                        final payload = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => ResourceEditorDialog(
                            resource: ruleSetResource,
                            initialData: ruleSet.raw,
                          ),
                        );
                        if (payload == null) return;
                        await repository.updateRuleSet(ruleSet.id, payload);
                        ref.invalidate(ruleSetListProvider);
                        ref.invalidate(selectedRuleSetProvider);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete rule set',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete rule set?'),
                                content: Text('Delete rule set v${ruleSet.version}?'),
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
                        await repository.deleteRuleSet(ruleSet.id);
                        browser.selectRuleSet(null);
                        ref.invalidate(ruleSetListProvider);
                        ref.invalidate(selectedRuleSetProvider);
                        ref.invalidate(ruleMatricesProvider);
                        ref.invalidate(selectedRuleMatrixProvider);
                        ref.invalidate(ruleMatrixRowsProvider);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                if (!focusDependentLayer) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _InfoTile(label: 'Status', value: ruleSet.statusCode),
                          _InfoTile(label: 'Valid from', value: _dateLabel(ruleSet.validFrom)),
                          _InfoTile(label: 'Valid to', value: _dateLabel(ruleSet.validTo)),
                          _InfoTile(label: 'Template', value: ruleSet.configuratorTemplateId),
                          _InfoTile(label: 'Created', value: _dateTimeLabel(ruleSet.createdAt)),
                          _InfoTile(label: 'Updated', value: _dateTimeLabel(ruleSet.updatedAt)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Notes',
                        child: Text(ruleSet.notes?.isNotEmpty == true ? ruleSet.notes! : 'No notes'),
                      ),
                      ],
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

class _RuleWorkspace extends ConsumerWidget {
  const _RuleWorkspace({
    required this.selectedRuleSetAsync,
    required this.selectedRuleMatrixAsync,
    required this.matricesAsync,
    required this.rowsAsync,
  });

  final AsyncValue<RuleSet?> selectedRuleSetAsync;
  final AsyncValue<RuleMatrix?> selectedRuleMatrixAsync;
  final AsyncValue<RuleMatrixListResponse?> matricesAsync;
  final AsyncValue<RuleMatrixRowListResponse?> rowsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 1320;
    return Column(
      children: [
        const _RuleWorkspaceToolbar(),
        const SizedBox(height: 12),
        Expanded(
          child: isWide
              ? ResizableSplitPane(
                  axis: Axis.horizontal,
                  initialFraction: 0.34,
                  minFirstFraction: 0.25,
                  minSecondFraction: 0.4,
                  first: _RuleMatrixListCard(matricesAsync: matricesAsync),
                  second: Column(
                        children: [
                          const Material(
                            color: Colors.transparent,
                            child: TabBar(
                              isScrollable: true,
                              tabs: [
                                Tab(icon: Icon(Icons.reorder_rounded), text: 'Rows'),
                                Tab(icon: Icon(Icons.grid_on_rounded), text: 'Matrix detail'),
                                Tab(icon: Icon(Icons.code_rounded), text: 'Rule JSON'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _RuleRowsTab(rowsAsync: rowsAsync),
                                _RuleMatrixDetailTab(detailsAsync: selectedRuleMatrixAsync),
                                _RuleSetJsonTab(ruleSetAsync: selectedRuleSetAsync),
                              ],
                            ),
                          ),
                        ],
                      ),
                )
              : ResizableSplitPane(
                  axis: Axis.vertical,
                  initialFraction: 0.45,
                  minFirstFraction: 0.25,
                  minSecondFraction: 0.3,
                  first: _RuleMatrixListCard(matricesAsync: matricesAsync),
                  second: Column(
                        children: [
                          const Material(
                            color: Colors.transparent,
                            child: TabBar(
                              isScrollable: true,
                              tabs: [
                                Tab(icon: Icon(Icons.reorder_rounded), text: 'Rows'),
                                Tab(icon: Icon(Icons.grid_on_rounded), text: 'Matrix detail'),
                                Tab(icon: Icon(Icons.code_rounded), text: 'Rule JSON'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _RuleRowsTab(rowsAsync: rowsAsync),
                                _RuleMatrixDetailTab(detailsAsync: selectedRuleMatrixAsync),
                                _RuleSetJsonTab(ruleSetAsync: selectedRuleSetAsync),
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
        ),
      ],
    );
  }
}

class _RuleWorkspaceToolbar extends ConsumerStatefulWidget {
  const _RuleWorkspaceToolbar();

  @override
  ConsumerState<_RuleWorkspaceToolbar> createState() => _RuleWorkspaceToolbarState();
}

class _RuleWorkspaceToolbarState extends ConsumerState<_RuleWorkspaceToolbar> {
  late final TextEditingController _matrixQueryController;
  late final TextEditingController _rowQueryController;

  @override
  void initState() {
    super.initState();
    _matrixQueryController = TextEditingController();
    _rowQueryController = TextEditingController();
  }

  @override
  void dispose() {
    _matrixQueryController.dispose();
    _rowQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(ruleWorkspaceProvider);
    final browser = ref.read(ruleWorkspaceProvider.notifier);
    final repository = ref.read(ruleSetRepositoryProvider);
    final ruleMatrixResource = findResourceByKey('rule_matrices');
    final ruleMatrixRowResource = findResourceByKey('rule_matrix_rows');

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _matrixQueryController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Filter matrices',
            ),
            onSubmitted: browser.setMatrixQuery,
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _rowQueryController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Filter rows',
            ),
            onSubmitted: browser.setRowQuery,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            browser.setMatrixQuery(_matrixQueryController.text.trim());
            browser.setRowQuery(_rowQueryController.text.trim());
          },
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('Apply'),
        ),
        FilledButton.icon(
          onPressed: browserState.selectedRuleSetId == null
              ? null
              : () async {
                  final payload = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ResourceEditorDialog(
                      resource: ruleMatrixResource,
                      initialData: {'rule_set_id': browserState.selectedRuleSetId},
                    ),
                  );
                  if (payload == null) return;
                  payload.putIfAbsent('rule_set_id', () => browserState.selectedRuleSetId!);
                  await repository.createRuleMatrix(payload);
                  ref.invalidate(ruleMatricesProvider);
                },
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('Create matrix'),
        ),
        OutlinedButton.icon(
          onPressed: browserState.selectedRuleMatrixId == null
              ? null
              : () async {
                  final payload = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ResourceEditorDialog(
                      resource: ruleMatrixRowResource,
                      initialData: {'rule_matrix_id': browserState.selectedRuleMatrixId},
                    ),
                  );
                  if (payload == null) return;
                  payload.putIfAbsent('rule_matrix_id', () => browserState.selectedRuleMatrixId!);
                  await repository.createRuleMatrixRow(payload);
                  ref.invalidate(ruleMatrixRowsProvider);
                },
          icon: const Icon(Icons.add_link_outlined),
          label: const Text('Create row'),
        ),
      ],
    );
  }
}

class _RuleMatrixListCard extends ConsumerWidget {
  const _RuleMatrixListCard({required this.matricesAsync});

  final AsyncValue<RuleMatrixListResponse?> matricesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(ruleWorkspaceProvider);
    final browser = ref.read(ruleWorkspaceProvider.notifier);

    return matricesAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (response) {
        if (browserState.selectedRuleSetId == null) {
          return const Card(child: Center(child: Text('Select a rule set first')));
        }
        if (response == null || response.items.isEmpty) {
          return const Card(child: Center(child: Text('No rule matrices for selected rule set')));
        }

        if (browserState.selectedRuleMatrixId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            browser.selectRuleMatrix(response.items.first.id);
          });
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rule matrices', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    key: PageStorageKey<String>(
                      'rule-matrix-list-${browserState.selectedRuleSetId ?? "none"}',
                    ),
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
                              AdminTableHeaderCell(label: 'Sheet / axes', flex: 4),
                              AdminTableHeaderCell(label: 'Status', flex: 2),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final matrix = response.items[rowIndex];
                      final isSelected = browserState.selectedRuleMatrixId == matrix.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => browser.selectRuleMatrix(matrix.id),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AdminRowNumberCell(index: rowIndex),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      matrix.matrixCode,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  _StatusChip(label: matrix.isActive ? 'Active' : 'Inactive', active: matrix.isActive),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(matrix.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if ((matrix.sourceSheetName ?? '').isNotEmpty)
                                    _MetaChip(icon: Icons.table_chart_outlined, label: matrix.sourceSheetName!),
                                  if ((matrix.axisXCode ?? '').isNotEmpty)
                                    _MetaChip(icon: Icons.swap_horiz_rounded, label: matrix.axisXCode!),
                                  if ((matrix.axisYCode ?? '').isNotEmpty)
                                    _MetaChip(icon: Icons.swap_vert_rounded, label: matrix.axisYCode!),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _RuleRowsTab extends ConsumerWidget {
  const _RuleRowsTab({required this.rowsAsync});

  final AsyncValue<RuleMatrixRowListResponse?> rowsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browser = ref.read(ruleWorkspaceProvider.notifier);
    final selectedRowId = ref.watch(ruleWorkspaceProvider.select((value) => value.selectedRowId));
    final repository = ref.read(ruleSetRepositoryProvider);
    final rowResource = findResourceByKey('rule_matrix_rows');

    return rowsAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (response) {
        final matrixId = ref.watch(ruleWorkspaceProvider.select((value) => value.selectedRuleMatrixId));
        if (matrixId == null) {
          return const Card(child: Center(child: Text('Select a rule matrix to inspect rows')));
        }
        if (response == null || response.items.isEmpty) {
          return const Card(child: Center(child: Text('No rows for selected rule matrix')));
        }

        RuleMatrixRow? selectedRow;
        if (selectedRowId != null) {
          for (final row in response.items) {
            if (row.id == selectedRowId) {
              selectedRow = row;
              break;
            }
          }
        }
        selectedRow ??= response.items.first;
        if (selectedRowId == null || selectedRow.id != selectedRowId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            browser.selectRow(selectedRow!.id);
          });
        }

        return ResizableSplitPane(
          axis: Axis.horizontal,
          initialFraction: 0.4,
          minFirstFraction: 0.25,
          minSecondFraction: 0.3,
          first: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rows', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Rows in matrix: ${response.items.length}'),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          key: PageStorageKey<String>(
                            //'rule-row-list-${matrixId ?? "none"}',
                            'rule-row-list-$matrixId',
                          ),
                          itemCount: response.items.length + 1,
                          separatorBuilder: (_, index) => index == 0
                              ? const Divider(height: 2)
                              : const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    AdminRowNumberHeader(),
                                    AdminTableHeaderCell(label: 'Row no', flex: 2),
                                    AdminTableHeaderCell(label: 'Key JSON', flex: 5),
                                    AdminTableHeaderCell(label: 'Result JSON', flex: 4),
                                  ],
                                ),
                              );
                            }

                            final rowIndex = index - 1;
                            final row = response.items[rowIndex];
                            final isSelected = row.id == selectedRow!.id;
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: AdminRowNumberCell(index: rowIndex),
                              title: Text('Row ${row.rowNo}'),
                              subtitle: Text(
                                _jsonSummary(row.keyJson),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _jsonSummary(row.resultJson),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => browser.selectRow(row.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          second: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Row ${selectedRow.rowNo}', style: Theme.of(context).textTheme.titleLarge),
                          ),
                          IconButton(
                            tooltip: 'Edit row',
                            onPressed: () async {
                              final currentSelectedRow = selectedRow;
                              if (currentSelectedRow == null) return;
                              final payload = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (_) => ResourceEditorDialog(
                                  resource: rowResource,
                                  initialData: currentSelectedRow.raw,
                                ),
                              );
                              if (payload == null) return;
                              await repository.updateRuleMatrixRow(currentSelectedRow.id, payload);
                              ref.invalidate(ruleMatrixRowsProvider);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete row',
                            onPressed: () async {
                              final currentSelectedRow = selectedRow;
                              if (currentSelectedRow == null) return;
                              final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete row?'),
                                      content: Text('Delete row ${currentSelectedRow.rowNo}?'),
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
                              await repository.deleteRuleMatrixRow(currentSelectedRow.id);
                              browser.selectRow(null);
                              ref.invalidate(ruleMatrixRowsProvider);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _InfoTile(label: 'Created', value: _dateTimeLabel(selectedRow.createdAt)),
                          _InfoTile(label: 'Updated', value: _dateTimeLabel(selectedRow.updatedAt)),
                          _InfoTile(label: 'Notes', value: selectedRow.notes ?? '—'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            JsonViewCard(title: 'Key JSON', data: selectedRow.keyJson),
                            const SizedBox(height: 12),
                            JsonViewCard(title: 'Result JSON', data: selectedRow.resultJson),
                            if ((selectedRow.notes ?? '').isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SectionCard(title: 'Notes', child: Text(selectedRow.notes!)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }
}

class _RuleMatrixDetailTab extends ConsumerWidget {
  const _RuleMatrixDetailTab({required this.detailsAsync});

  final AsyncValue<RuleMatrix?> detailsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(ruleSetRepositoryProvider);
    final matrixResource = findResourceByKey('rule_matrices');
    final browser = ref.read(ruleWorkspaceProvider.notifier);

    return detailsAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (matrix) {
        if (matrix == null) {
          return const Card(child: Center(child: Text('Select a rule matrix to inspect details')));
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
                            initialData: matrix.raw,
                          ),
                        );
                        if (payload == null) return;
                        await repository.updateRuleMatrix(matrix.id, payload);
                        ref.invalidate(ruleMatricesProvider);
                        ref.invalidate(selectedRuleMatrixProvider);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete matrix',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete rule matrix?'),
                                content: Text('Delete ${matrix.matrixCode}?'),
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
                        await repository.deleteRuleMatrix(matrix.id);
                        browser.selectRuleMatrix(null);
                        ref.invalidate(ruleMatricesProvider);
                        ref.invalidate(selectedRuleMatrixProvider);
                        ref.invalidate(ruleMatrixRowsProvider);
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
                          _InfoTile(label: 'Sheet', value: matrix.sourceSheetName ?? '—'),
                          _InfoTile(label: 'Range', value: matrix.sourceRange ?? '—'),
                          _InfoTile(label: 'Axis X', value: matrix.axisXCode ?? '—'),
                          _InfoTile(label: 'Axis Y', value: matrix.axisYCode ?? '—'),
                          _InfoTile(label: 'Sort order', value: '${matrix.sortOrder ?? 0}'),
                          _InfoTile(label: 'Updated', value: _dateTimeLabel(matrix.updatedAt)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (matrix.headerJson != null) ...[
                        JsonViewCard(title: 'Header JSON', data: matrix.headerJson!),
                        const SizedBox(height: 12),
                      ],
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

class _RuleSetJsonTab extends StatelessWidget {
  const _RuleSetJsonTab({required this.ruleSetAsync});

  final AsyncValue<RuleSet?> ruleSetAsync;

  @override
  Widget build(BuildContext context) {
    return ruleSetAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (ruleSet) {
        if (ruleSet == null) {
          return const Card(child: Center(child: Text('Select a rule set to inspect rules JSON')));
        }
        return ListView(
          children: [
            JsonViewCard(title: 'Rules JSON', data: ruleSet.rulesJson),
            const SizedBox(height: 12),
            JsonViewCard(title: 'Raw record', data: ruleSet.raw),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(
              'Request failed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            SelectableText(
              '$error',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _jsonSummary(Map<String, dynamic> value) {
  if (value.isEmpty) return '—';
  final entries = value.entries.take(3).map((entry) => '${entry.key}: ${_shortValue(entry.value)}').join(' · ');
  return entries.length > 96 ? '${entries.substring(0, 96)}…' : entries;
}

String _shortValue(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  if (value is List) return 'List(${value.length})';
  if (value is Map) return 'Map(${value.length})';
  return jsonEncode(value);
}

String _shortId(String value) => value.length <= 8 ? value : value.substring(0, 8);

String _dateLabel(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('yyyy-MM-dd').format(parsed);
}

String _dateTimeLabel(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
}

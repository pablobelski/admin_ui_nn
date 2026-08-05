import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../../../core/ui/admin_list_table.dart';
import '../../../core/ui/header_focus_icon_button.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/scrollable_areas.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../data/reference_repository.dart';
import 'reference_workspace_providers.dart';

class ReferenceWorkspacePage extends ConsumerWidget {
  const ReferenceWorkspacePage({
    super.key,
    this.initialMode = ReferenceWorkspaceMode.domains,
  });

  final ReferenceWorkspaceMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDomainAsync = ref.watch(selectedReferenceDomainProvider);
    final valuesAsync = ref.watch(referenceValuesProvider);
    final domainResource = findResourceByKey('reference_domains');
    final navigationFilters = _referenceDomainNavigationFilters(currentAdminResourceFilters(domainResource));
    final workspaceFilters = ref.watch(
      referenceWorkspaceProvider.select((state) => state.activeFilters),
    );
    if (!_sameStringMap(navigationFilters, workspaceFilters)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(referenceWorkspaceProvider.notifier).applyNavigationFilters(navigationFilters);
      });
    }
    final isWide = MediaQuery.sizeOf(context).width >= 1360;
    final focusDependentLayer = ref.watch(referenceDependentLayerFocusProvider);

    return DefaultTabController(
      initialIndex: 0,
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(),
          const SizedBox(height: 16),
          const _ReferenceToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: isWide
                ? ResizableSplitPane(
                    axis: Axis.horizontal,
                    initialFraction: focusDependentLayer ? 0.0 : 0.4,
                    minFirstFraction: focusDependentLayer ? 0.0 : 0.25,
                    minSecondFraction: 0.35,
                    first: const _DomainListCard(),
                    second: ResizableSplitPane(
                      axis: Axis.vertical,
                      initialFraction: focusDependentLayer ? 0.12 : 0.34,
                      minFirstFraction: focusDependentLayer ? 0.10 : 0.18,
                      minSecondFraction: 0.35,
                      first: _DomainDetailsCard(detailsAsync: selectedDomainAsync),
                      second: _ValuesWorkspace(valuesAsync: valuesAsync),
                    ),
                  )
                : ResizableSplitPane(
                    axis: Axis.vertical,
                    initialFraction: focusDependentLayer ? 0.0 : 0.35,
                    minFirstFraction: focusDependentLayer ? 0.0 : 0.2,
                    minSecondFraction: 0.35,
                    first: const _DomainListCard(),
                    second: ResizableSplitPane(
                      axis: Axis.vertical,
                      initialFraction: focusDependentLayer ? 0.12 : 0.34,
                      minFirstFraction: focusDependentLayer ? 0.10 : 0.18,
                      minSecondFraction: 0.35,
                      first: _DomainDetailsCard(detailsAsync: selectedDomainAsync),
                      second: _ValuesWorkspace(valuesAsync: valuesAsync),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

enum ReferenceWorkspaceMode { domains, referenceValues }

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.library_books_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text('Reference Domains & Values', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Workspace for reference domains and their values. '
          'Domains are listed on the left; the selected domain and its reference values are shown on the right.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ReferenceToolbar extends ConsumerStatefulWidget {
  const _ReferenceToolbar();

  @override
  ConsumerState<_ReferenceToolbar> createState() => _ReferenceToolbarState();
}

class _ReferenceToolbarState extends ConsumerState<_ReferenceToolbar> {
  late final TextEditingController _domainSearchController;
  late final TextEditingController _valueSearchController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(referenceWorkspaceProvider);
    _domainSearchController = TextEditingController(text: state.domainQuery);
    _valueSearchController = TextEditingController(text: state.valueQuery);
  }

  @override
  void dispose() {
    _domainSearchController.dispose();
    _valueSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.read(referenceWorkspaceProvider.notifier);
    final repository = ref.read(referenceRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final domainResource = findResourceByKey('reference_domains');
    final state = ref.watch(referenceWorkspaceProvider);
    final selectedDomainId = state.selectedDomainId;
    final ownerRecordAsync = state.objectName.isNotEmpty && state.parentId.isNotEmpty
        ? ref.watch(referenceOwnerRecordLabelProvider(
            ReferenceOwnerRecordKey(objectName: state.objectName, parentId: state.parentId),
          ))
        : null;
    final ownerFilterLabel = _ownerFilterLabel(state, ownerRecordAsync);

    final createButton = FilledButton.icon(
      onPressed: () async {
        final payload = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => ResourceEditorDialog(
            resource: domainResource,
            repository: adminRepository,
            initialData: _createDomainInitialData(state.activeFilters),
          ),
        );
        if (payload == null) return;
        await repository.createDomain(payload);
        ref.invalidate(referenceDomainListProvider);
      },
      icon: const Icon(Icons.add),
      label: const Text('Create domain'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _domainSearchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search domain code / name',
                ),
                onSubmitted: browser.setDomainQuery,
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                key: ValueKey('reference-scope-${state.scopeCode}'),
                initialValue: _scopeDropdownValue(state.scopeCode),
                decoration: const InputDecoration(
                  labelText: 'Scope',
                  prefixIcon: Icon(Icons.filter_list_outlined),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '', child: Text('All scopes')),
                  DropdownMenuItem(value: 'system', child: Text('System/global')),
                  DropdownMenuItem(value: 'table', child: Text('Table records')),
                ],
                onChanged: browser.setScopeFilter,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => browser.setDomainQuery(_domainSearchController.text.trim()),
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Apply domain filter'),
            ),
            OutlinedButton.icon(
              onPressed: state.domainQuery.isNotEmpty || state.activeFilters.isNotEmpty
                  ? () {
                      _domainSearchController.clear();
                      browser.resetDomainFilters();
                    }
                  : null,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filters'),
            ),
            if (ownerFilterLabel != null)
              InputChip(
                avatar: const Icon(Icons.account_tree_outlined, size: 18),
                label: Text(ownerFilterLabel),
                onDeleted: browser.clearOwnerFilters,
              ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _valueSearchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.data_object_outlined),
                  hintText: 'Filter values by code / label',
                ),
                onSubmitted: browser.setValueQuery,
              ),
            ),
            OutlinedButton.icon(
              onPressed: selectedDomainId == null
                  ? null
                  : () => browser.setValueQuery(_valueSearchController.text.trim()),
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('Apply value filter'),
            ),
            OutlinedButton.icon(
              onPressed: state.valueQuery.isNotEmpty
                  ? () {
                      _valueSearchController.clear();
                      browser.resetValueFilters();
                    }
                  : null,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filters'),
            ),
            IconButton(
              tooltip: 'Refresh domains and values',
              onPressed: () {
                ref.invalidate(referenceDomainListProvider);
                ref.invalidate(selectedReferenceDomainProvider);
                ref.invalidate(referenceValuesProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: createButton,
        ),
      ],
    );
  }
}

class _DomainListCard extends ConsumerWidget {
  const _DomainListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(referenceDomainListProvider);
    final state = ref.watch(referenceWorkspaceProvider);
    final browser = ref.read(referenceWorkspaceProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(error: error),
          data: (response) {
            if (response.items.isEmpty) {
              return const Center(child: Text('No reference domains found'));
            }

            if (state.selectedDomainId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                browser.selectDomain(response.items.first.id);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Domains', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    key: PageStorageKey<String>(
                      'reference-domain-list-${state.domainQuery}-${state.scopeCode}-${state.objectName}-${state.parentId}-${state.offset}-${state.limit}',
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
                              AdminTableHeaderCell(label: 'Code', flex: 3),
                              AdminTableHeaderCell(label: 'Name', flex: 4),
                              AdminTableHeaderCell(label: 'Kind', flex: 2),
                              AdminTableHeaderCell(label: 'Status', flex: 2),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final domain = response.items[rowIndex];
                      final isSelected = state.selectedDomainId == domain.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => browser.selectDomain(domain.id),
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
                                  AdminRowNumberCell(index: rowIndex, offset: state.offset),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      domain.code,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  _StatusChip(label: domain.isActive ? 'Active' : 'Inactive', active: domain.isActive),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(domain.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    icon: domain.scopeCode == 'table'
                                        ? Icons.account_tree_outlined
                                        : Icons.public_outlined,
                                    label: domain.scopeCode == 'table' ? 'Table scope' : 'System scope',
                                  ),
                                  _MetaChip(
                                    icon: domain.isSystem ? Icons.lock_outline : Icons.edit_outlined,
                                    label: domain.isSystem ? 'Protected' : 'Editable',
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
                  offset: state.offset,
                  limit: state.limit,
                  pageItemCount: response.items.length,
                  total: response.total,
                  onPrevious: state.offset == 0 ? null : browser.previousPage,
                  onNext: adminListHasNextPage(
                    offset: state.offset,
                    limit: state.limit,
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

class _DomainDetailsCard extends ConsumerWidget {
  const _DomainDetailsCard({required this.detailsAsync});

  final AsyncValue<ReferenceDomain?> detailsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(referenceRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final selectedDomainId = ref.watch(referenceWorkspaceProvider.select((value) => value.selectedDomainId));
    final domainResource = findResourceByKey('reference_domains');
    final focusDependentLayer = ref.watch(referenceDependentLayerFocusProvider);

    return detailsAsync.when(
      loading: () => const Card(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Card(child: _ErrorState(error: error)),
      data: (domain) {
        if (selectedDomainId == null) {
          return const Card(child: Center(child: Text('Select a domain to inspect details')));
        }
        if (domain == null) {
          return const Card(child: Center(child: Text('Domain details not found')));
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
                      onPressed: () => ref.read(referenceDependentLayerFocusProvider.notifier).toggle(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            domain.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(domain.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    _StatusChip(label: domain.isActive ? 'Active' : 'Inactive', active: domain.isActive),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit domain',
                      onPressed: () async {
                        final payload = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => ResourceEditorDialog(
                            resource: domainResource,
                            repository: adminRepository,
                            initialData: domain.raw,
                          ),
                        );
                        if (payload == null) return;
                        await repository.updateDomain(domain.id, payload);
                        ref.invalidate(referenceDomainListProvider);
                        ref.invalidate(selectedReferenceDomainProvider);
                      },
                      icon: const Icon(Icons.edit_outlined),
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
                          _InfoTile(label: 'Domain id', value: domain.id),
                          _InfoTile(label: 'Scope', value: domain.scopeCode ?? 'system'),
                          _InfoTile(label: 'Object name', value: domain.objectName ?? '—'),
                          _InfoTile(label: 'Parent id', value: domain.parentId ?? '—'),
                          _InfoTile(label: 'System/protected', value: domain.isSystem ? 'Yes' : 'No'),
                          _InfoTile(label: 'Created', value: domain.createdAt ?? '—'),
                          _InfoTile(label: 'Updated', value: domain.updatedAt ?? '—'),
                        ],
                      ),
                      if ((domain.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Description', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(domain.description!),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      JsonViewCard(title: 'Domain JSON', data: domain.raw),
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

class _ValuesWorkspace extends StatelessWidget {
  const _ValuesWorkspace({required this.valuesAsync});

  final AsyncValue<ReferenceValueListResponse?> valuesAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reference values', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Values table'),
                Tab(text: 'Raw JSON'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _ValuesTableTab(valuesAsync: valuesAsync),
                  _ValuesJsonTab(valuesAsync: valuesAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValuesTableTab extends ConsumerWidget {
  const _ValuesTableTab({required this.valuesAsync});

  final AsyncValue<ReferenceValueListResponse?> valuesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(referenceRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final browser = ref.read(referenceWorkspaceProvider.notifier);
    final state = ref.watch(referenceWorkspaceProvider);
    final valueResource = findResourceByKey('reference_values');

    return valuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (response) {
        if (state.selectedDomainId == null) {
          return const Center(child: Text('Select a domain to load values'));
        }
        if (response == null || response.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No values for selected domain'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final payload = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => ResourceEditorDialog(
                        resource: valueResource,
                        repository: adminRepository,
                        initialData: {
                          'domain_id': state.selectedDomainId,
                          'sort_order': 0,
                          'metadata_json': const <String, dynamic>{},
                          'is_active': true,
                        },
                      ),
                    );
                    if (payload == null) return;
                    await repository.createValue(payload);
                    ref.invalidate(referenceValuesProvider);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add first value'),
                ),
              ],
            ),
          );
        }

        final selectedValue = response.items.firstWhere(
          (value) => value.id == state.selectedValueId,
          orElse: () => response.items.first,
        );

        if (state.selectedValueId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            browser.selectValue(selectedValue.id);
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1080;
            final table = _ValueTable(
              values: response.items,
              selectedValueId: state.selectedValueId,
              onSelect: browser.selectValue,
            );
            final details = _ValueDetailsCard(
              value: selectedValue,
              onEdit: () async {
                final payload = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => ResourceEditorDialog(
                    resource: valueResource,
                    repository: adminRepository,
                    initialData: selectedValue.raw,
                  ),
                );
                if (payload == null) return;
                await repository.updateValue(selectedValue.id, payload);
                ref.invalidate(referenceValuesProvider);
              },
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete reference value?'),
                        content: Text('Delete ${selectedValue.code}?'),
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
                await repository.deleteValue(selectedValue.id);
                browser.selectValue(null);
                ref.invalidate(referenceValuesProvider);
              },
            );

            final createButton = Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  final payload = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ResourceEditorDialog(
                      resource: valueResource,
                      repository: adminRepository,
                      initialData: {
                        'domain_id': state.selectedDomainId,
                        'sort_order': response.items.length + 1,
                        'metadata_json': const <String, dynamic>{},
                        'is_active': true,
                      },
                    ),
                  );
                  if (payload == null) return;
                  await repository.createValue(payload);
                  ref.invalidate(referenceValuesProvider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add value'),
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

class _ValueTable extends StatelessWidget {
  const _ValueTable({
    required this.values,
    required this.selectedValueId,
    required this.onSelect,
  });

  final List<ReferenceValue> values;
  final String? selectedValueId;
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
            Text('Values table', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: HorizontalScrollArea(
                child: SizedBox(
                  width: adminRowNumberColumnWidth + 1060,
                  child: ListView.separated(
                    key: PageStorageKey<String>(
                      'reference-value-list-${values.isEmpty ? "empty" : values.first.domainId}',
                    ),
                    itemCount: values.length + 1,
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
                              AdminTableHeaderCell(width: 70, label: 'Sort'),
                              AdminTableHeaderCell(width: 180, label: 'Code'),
                              AdminTableHeaderCell(width: 220, label: 'Label'),
                              AdminTableHeaderCell(width: 160, label: 'Alt label'),
                              AdminTableHeaderCell(width: 180, label: 'Text value'),
                              AdminTableHeaderCell(width: 120, label: 'Color HEX'),
                              AdminTableHeaderCell(width: 90, label: 'Status'),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final value = values[rowIndex];
                      final isSelected = selectedValueId == value.id;
                      return InkWell(
                        onTap: () => onSelect(value.id),
                        child: Container(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              AdminRowNumberCell(index: rowIndex),
                              _TableValue(width: 70, value: '${value.sortOrder}'),
                              _TableValue(width: 180, value: value.code, strong: true),
                              _TableValue(width: 220, value: value.label),
                              _TableValue(width: 160, value: value.altLabel ?? '—'),
                              _TableValue(width: 180, value: value.textValue ?? '—'),
                              _TableValue(width: 120, value: value.colorHex ?? '—'),
                              _TableValue(width: 90, value: value.isActive ? 'Active' : 'Inactive'),
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

class _ValueDetailsCard extends StatelessWidget {
  const _ValueDetailsCard({
    required this.value,
    required this.onEdit,
    required this.onDelete,
  });

  final ReferenceValue? value;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Card(child: Center(child: Text('Select a value to inspect details')));
    }

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(child: Text(value!.code, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Label', value: value!.label),
            _DetailRow(label: 'Alt label', value: value!.altLabel ?? '—'),
            _DetailRow(label: 'Sort order', value: '${value!.sortOrder}'),
            _DetailRow(label: 'Color HEX', value: value!.colorHex ?? '—'),
            _DetailRow(label: 'Numeric value', value: value!.numericValue?.toString() ?? '—'),
            _DetailRow(label: 'Text value', value: value!.textValue ?? '—'),
            _DetailRow(label: 'Active', value: value!.isActive ? 'Yes' : 'No'),
            const SizedBox(height: 16),
            JsonViewCard(title: 'Metadata JSON', data: value!.metadataJson ?? const {}),
            const SizedBox(height: 16),
            JsonViewCard(title: 'Value JSON', data: value!.raw),
          ],
        ),
      ),
    );
  }
}

class _ValuesJsonTab extends StatelessWidget {
  const _ValuesJsonTab({required this.valuesAsync});

  final AsyncValue<ReferenceValueListResponse?> valuesAsync;

  @override
  Widget build(BuildContext context) {
    return valuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (response) {
        if (response == null) {
          return const Center(child: Text('No domain selected'));
        }

        return ListView(
          children: [
            JsonViewCard(
              title: 'Values JSON',
              data: {
                'total': response.total,
                'items': response.items.map((value) => value.raw).toList(),
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
              SelectableText(
                value,
                maxLines: 2,
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
        style: strong ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700) : null,
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


String _scopeDropdownValue(String value) {
  return value == 'system' || value == 'table' ? value : '';
}

String? _ownerFilterLabel(
  ReferenceWorkspaceState state,
  AsyncValue<ReferenceOwnerRecord?>? ownerRecordAsync,
) {
  if (state.objectName.isEmpty && state.parentId.isEmpty) return null;
  final object = state.objectName.isEmpty ? 'table' : state.objectName;
  if (state.parentId.isEmpty) return object;

  final ownerLabel = ownerRecordAsync?.maybeWhen(
    data: (record) => record?.label.trim(),
    orElse: () => null,
  );
  final displayValue = ownerLabel == null || ownerLabel.isEmpty ? state.parentId : ownerLabel;
  return '$object · $displayValue';
}

Map<String, dynamic> _createDomainInitialData(Map<String, String> filters) {
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

Map<String, String> _referenceDomainNavigationFilters(Map<String, String> filters) {
  return <String, String>{
    if ((filters['scope_code'] ?? '').isNotEmpty) 'scope_code': filters['scope_code']!,
    if ((filters['object_name'] ?? '').isNotEmpty) 'object_name': filters['object_name']!,
    if ((filters['parent_id'] ?? '').isNotEmpty) 'parent_id': filters['parent_id']!,
  };
}

bool _sameStringMap(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
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

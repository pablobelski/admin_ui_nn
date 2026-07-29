import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/admin_resource.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../../../core/ui/admin_list_table.dart';
import '../../../core/ui/header_focus_icon_button.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/resizable_split_pane.dart';
import '../../../core/ui/resource_editor_dialog.dart';
import '../../../core/ui/searchable_select_form_field.dart';
import '../data/configurator_template_repository.dart';
import 'template_workspace_providers.dart';

class TemplateWorkspacePage extends ConsumerWidget {
  const TemplateWorkspacePage({
    super.key,
    this.initialMode = TemplateWorkspaceMode.templates,
  });

  final TemplateWorkspaceMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTemplateAsync = ref.watch(selectedConfiguratorTemplateProvider);
    final selectedModuleAsync = ref.watch(selectedTemplateModuleProvider);
    final templateResource = findResourceByKey('configurator_templates');
    final navigationFilters = _templateNavigationFilters(currentAdminResourceFilters(templateResource));
    final workspaceFilters = ref.watch(
      templateWorkspaceProvider.select((state) => state.activeFilters),
    );
    if (!_sameStringMap(navigationFilters, workspaceFilters)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(templateWorkspaceProvider.notifier).applyNavigationFilters(navigationFilters);
      });
    }
    final isWide = MediaQuery.sizeOf(context).width >= 1360;
    final focusDependentLayer = ref.watch(templateDependentLayerFocusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(),
        const SizedBox(height: 16),
        const _TemplateToolbar(),
        const SizedBox(height: 16),
        Expanded(
          child: isWide
              ? ResizableSplitPane(
                  axis: Axis.horizontal,
                  initialFraction: focusDependentLayer ? 0.0 : 0.4,
                  minFirstFraction: focusDependentLayer ? 0.0 : 0.25,
                  minSecondFraction: 0.35,
                  first: const _TemplateListCard(),
                  second: ResizableSplitPane(
                    axis: Axis.vertical,
                    initialFraction: focusDependentLayer ? 0.12 : 0.32,
                    minFirstFraction: focusDependentLayer ? 0.10 : 0.18,
                    minSecondFraction: 0.35,
                    first: _TemplateDetailsCard(detailsAsync: selectedTemplateAsync),
                    second: _TemplateModuleWorkspace(
                      initialMode: initialMode,
                      selectedTemplateAsync: selectedTemplateAsync,
                      selectedModuleAsync: selectedModuleAsync,
                    ),
                  ),
                )
              : ResizableSplitPane(
                  axis: Axis.vertical,
                  initialFraction: focusDependentLayer ? 0.0 : 0.35,
                  minFirstFraction: focusDependentLayer ? 0.0 : 0.2,
                  minSecondFraction: 0.35,
                  first: const _TemplateListCard(),
                  second: ResizableSplitPane(
                    axis: Axis.vertical,
                    initialFraction: focusDependentLayer ? 0.12 : 0.32,
                    minFirstFraction: focusDependentLayer ? 0.10 : 0.18,
                    minSecondFraction: 0.35,
                    first: _TemplateDetailsCard(detailsAsync: selectedTemplateAsync),
                    second: _TemplateModuleWorkspace(
                      initialMode: initialMode,
                      selectedTemplateAsync: selectedTemplateAsync,
                      selectedModuleAsync: selectedModuleAsync,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

enum TemplateWorkspaceMode { templates, modules }

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.webhook_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Configurator Templates',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Специализированный экран для live-export шаблонов конфигуратора и их модулей. '
          'Слева — список шаблонов, справа — детали, UI schema, defaults и связанные workbook-модули.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _TemplateToolbar extends ConsumerStatefulWidget {
  const _TemplateToolbar();

  @override
  ConsumerState<_TemplateToolbar> createState() => _TemplateToolbarState();
}

class _TemplateToolbarState extends ConsumerState<_TemplateToolbar> {
  late final TextEditingController _templateSearchController;
  late final TextEditingController _moduleSearchController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(templateWorkspaceProvider);
    _templateSearchController = TextEditingController(text: state.templateQuery);
    _moduleSearchController = TextEditingController(text: state.moduleQuery);
  }

  @override
  void dispose() {
    _templateSearchController.dispose();
    _moduleSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.read(templateWorkspaceProvider.notifier);
    final repository = ref.read(configuratorTemplateRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final templateResource = findResourceByKey('configurator_templates');
    final workspaceState = ref.watch(templateWorkspaceProvider);
    final selectedTemplateId = workspaceState.selectedTemplateId;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _templateSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search code / workbook / status',
            ),
            onSubmitted: browser.setTemplateQuery,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => browser.setTemplateQuery(_templateSearchController.text.trim()),
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('Apply template filter'),
        ),
        OutlinedButton.icon(
          onPressed: workspaceState.templateQuery.isNotEmpty ||
                  workspaceState.activeFilters.isNotEmpty
              ? () {
                  _templateSearchController.clear();
                  browser.clearTemplateFilters();
                }
              : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Reset filters'),
        ),
        SizedBox(
          width: 280,
          child: _TemplateLookupFilterField(
            lookup: productFamilyLookup,
            value: workspaceState.productFamilyId,
            labelText: 'Product family',
            onChanged: (value) => browser.setTemplateFilter('product_family_id', value),
          ),
        ),
        SizedBox(
          width: 280,
          child: _TemplateLookupFilterField(
            lookup: roofModelLookup,
            value: workspaceState.roofModelId,
            labelText: 'Roof model',
            onChanged: (value) => browser.setTemplateFilter('roof_model_id', value),
          ),
        ),
        SizedBox(
          width: 280,
          child: TextField(
            controller: _moduleSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.widgets_outlined),
              hintText: 'Filter modules by code / sheet / type',
            ),
            onSubmitted: browser.setModuleQuery,
          ),
        ),
        OutlinedButton.icon(
          onPressed: selectedTemplateId == null
              ? null
              : () => browser.setModuleQuery(_moduleSearchController.text.trim()),
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Apply module filter'),
        ),
        OutlinedButton.icon(
          onPressed: workspaceState.moduleQuery.isNotEmpty
              ? () {
                  _moduleSearchController.clear();
                  browser.resetModuleFilters();
                }
              : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Reset filters'),
        ),
        IconButton(
          tooltip: 'Refresh templates and modules',
          onPressed: () {
            ref.invalidate(configuratorTemplateListProvider);
            ref.invalidate(selectedConfiguratorTemplateProvider);
            ref.invalidate(templateModulesProvider);
            ref.invalidate(selectedTemplateModuleProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: () async {
            final payload = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => ResourceEditorDialog(
                resource: templateResource,
                repository: adminRepository,
              ),
            );
            if (payload == null) return;
            await repository.createTemplate(payload);
            ref.invalidate(configuratorTemplateListProvider);
          },
          icon: const Icon(Icons.add),
          label: const Text('Create template'),
        ),
      ],
    );
  }
}


class _TemplateLookupFilterField extends ConsumerWidget {
  const _TemplateLookupFilterField({
    required this.lookup,
    required this.value,
    required this.labelText,
    required this.onChanged,
  });

  final AdminLookup lookup;
  final String value;
  final String labelText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupAsync = ref.watch(adminLookupProvider(lookup));
    return lookupAsync.when(
      loading: () => SearchableSelectFormField(
        key: ValueKey('template-filter-$labelText-$value-loading'),
        value: value,
        options: [
          if (value.isNotEmpty) SearchableSelectOption(value: value, label: value),
        ],
        onChanged: null,
        labelText: labelText,
        emptyLabel: '— All —',
        helperText: 'Loading options...',
        enabled: false,
      ),
      error: (_, __) => TextFormField(
        key: ValueKey('template-filter-$labelText-$value-error'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: labelText,
          helperText: 'Lookup failed; paste id manually',
        ),
        onFieldSubmitted: (nextValue) => onChanged(nextValue),
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
          key: ValueKey('template-filter-$labelText-$value'),
          value: value,
          options: options,
          onChanged: onChanged,
          labelText: labelText,
          emptyLabel: '— All —',
        );
      },
    );
  }
}

class _TemplateListCard extends ConsumerWidget {
  const _TemplateListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(configuratorTemplateListProvider);
    final browserState = ref.watch(templateWorkspaceProvider);
    final browser = ref.read(templateWorkspaceProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(error: error),
          data: (response) {
            if (response.items.isEmpty) {
              return const Center(child: Text('No configurator templates found'));
            }

            if (browserState.selectedTemplateId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                browser.selectTemplate(response.items.first.id);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Templates', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    key: const PageStorageKey<String>('template-list'),
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
                              AdminTableHeaderCell(label: 'Workbook / family', flex: 4),
                              AdminTableHeaderCell(label: 'Status', flex: 2),
                            ],
                          ),
                        );
                      }

                      final rowIndex = index - 1;
                      final template = response.items[rowIndex];
                      final isSelected = browserState.selectedTemplateId == template.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => browser.selectTemplate(template.id),
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
                                      template.code,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  _StatusChip(label: template.statusCode),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(template.name, style: Theme.of(context).textTheme.bodyLarge),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    icon: Icons.layers_outlined,
                                    label: 'v${template.version}',
                                  ),
                                  _MetaChip(
                                    icon: Icons.grid_view_rounded,
                                    label: template.sourceSheetName ?? 'no sheet',
                                  ),
                                  _MetaChip(
                                    icon: Icons.category_outlined,
                                    label: _shortId(template.productFamilyId),
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

class _TemplateDetailsCard extends ConsumerWidget {
  const _TemplateDetailsCard({required this.detailsAsync});

  final AsyncValue<ConfiguratorTemplate?> detailsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(configuratorTemplateRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final templateResource = findResourceByKey('configurator_templates');
    final focusDependentLayer = ref.watch(templateDependentLayerFocusProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: detailsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(error: error),
          data: (template) {
            if (template == null) {
              return const Center(child: Text('Select a configurator template'));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeaderFocusIconButton(
                      focused: focusDependentLayer,
                      onPressed: () => ref.read(templateDependentLayerFocusProvider.notifier).toggle(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            template.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _TemplateRelatedMenu(template: template),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final payload = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => ResourceEditorDialog(
                            resource: templateResource,
                            repository: adminRepository,
                            initialData: template.raw,
                          ),
                        );
                        if (payload == null) return;
                        await repository.updateTemplate(template.id, payload);
                        ref.invalidate(configuratorTemplateListProvider);
                        ref.invalidate(selectedConfiguratorTemplateProvider);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit template'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await _confirmDelete(
                          context,
                          'Delete template ${template.code}?',
                          'The linked modules will usually need to be removed first on backend side.',
                        );
                        if (!confirmed) return;
                        await repository.deleteTemplate(template.id);
                        ref.read(templateWorkspaceProvider.notifier).selectTemplate(null);
                        ref.invalidate(configuratorTemplateListProvider);
                        ref.invalidate(selectedConfiguratorTemplateProvider);
                        ref.invalidate(templateModulesProvider);
                        ref.invalidate(selectedTemplateModuleProvider);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
                if (!focusDependentLayer) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                    _MetaChip(icon: Icons.layers_outlined, label: 'Version ${template.version}'),
                    _StatusChip(label: template.statusCode),
                    _MetaChip(
                      icon: Icons.grid_view_rounded,
                      label: template.sourceSheetName ?? 'no source sheet',
                    ),
                    _MetaChip(
                      icon: Icons.category_outlined,
                      label: 'Family ${_shortId(template.productFamilyId)}',
                    ),
                    if (template.roofModelId != null)
                      _MetaChip(
                        icon: Icons.roofing_outlined,
                        label: 'Roof ${_shortId(template.roofModelId!)}',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _DetailLine(label: 'Template id', value: template.id),
                      _DetailLine(label: 'Code', value: template.code),
                      _DetailLine(label: 'Name', value: template.name),
                      _DetailLine(label: 'Product family', value: template.productFamilyId),
                      _DetailLine(label: 'Roof model', value: template.roofModelId ?? '—'),
                      _DetailLine(label: 'Source sheet', value: template.sourceSheetName ?? '—'),
                      _DetailLine(label: 'Source range', value: template.sourceRange ?? '—'),
                      _DetailLine(label: 'Created', value: _dateTimeLabel(template.createdAt)),
                      _DetailLine(label: 'Updated', value: _dateTimeLabel(template.updatedAt)),
                      const SizedBox(height: 12),
                      JsonViewCard(title: 'Metadata JSON', data: template.metadataJson),
                    ],
                  ),
                ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}


class _TemplateRelatedMenu extends ConsumerWidget {
  const _TemplateRelatedMenu({required this.template});

  final ConfiguratorTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_TemplateRelatedAction>[
      _TemplateRelatedAction(
        label: 'Show product family',
        targetResourceKey: 'product_families',
        targetId: template.productFamilyId,
        icon: Icons.category_outlined,
      ),
      _TemplateRelatedAction(
        label: 'Show roof model',
        targetResourceKey: 'roof_models',
        targetId: template.roofModelId,
        icon: Icons.roofing_outlined,
      ),
    ];
    final hasAvailableActions = actions.any((action) => action.targetId != null && action.targetId!.isNotEmpty);

    return PopupMenuButton<_TemplateRelatedAction>(
      tooltip: 'Open related section',
      enabled: hasAvailableActions,
      onSelected: (action) => _openTemplateRelated(ref, action),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<_TemplateRelatedAction>(
            value: action,
            enabled: action.targetId != null && action.targetId!.isNotEmpty,
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

class _TemplateRelatedAction {
  const _TemplateRelatedAction({
    required this.label,
    required this.targetResourceKey,
    required this.targetId,
    required this.icon,
  });

  final String label;
  final String targetResourceKey;
  final String? targetId;
  final IconData icon;
}

void _openTemplateRelated(WidgetRef ref, _TemplateRelatedAction action) {
  final targetId = action.targetId?.trim();
  if (targetId == null || targetId.isEmpty) return;

  final filters = {'id': targetId};
  final targetResource = findResourceByKey(action.targetResourceKey);
  ref.read(selectedResourceProvider.notifier).select(
    action.targetResourceKey,
    filters: filters,
  );
  ref
      .read(resourceBrowserProvider(action.targetResourceKey).notifier)
      .openWithFilters(
        filters,
        selectedId: targetId,
        updateUrl: false,
      );
  ref.invalidate(resourceListProvider(targetResource));
  ref.invalidate(resourceDetailsProvider(targetResource));
}

class _TemplateModuleWorkspace extends ConsumerWidget {
  const _TemplateModuleWorkspace({
    required this.initialMode,
    required this.selectedTemplateAsync,
    required this.selectedModuleAsync,
  });

  final TemplateWorkspaceMode initialMode;
  final AsyncValue<ConfiguratorTemplate?> selectedTemplateAsync;
  final AsyncValue<TemplateModule?> selectedModuleAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 1500;
    final selectedTemplateId =
        ref.watch(templateWorkspaceProvider.select((value) => value.selectedTemplateId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selectedTemplateId == null
            ? const Center(child: Text('Select a template to inspect its workbook modules'))
            : DefaultTabController(
                initialIndex: initialMode == TemplateWorkspaceMode.modules ? 1 : 0,
                length: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Template modules', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                'Workbook ranges, editable sections and document blocks connected to the selected configurator template.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _ModuleToolbar(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isWide
                          ? ResizableSplitPane(
                              axis: Axis.horizontal,
                              initialFraction: 0.4,
                              minFirstFraction: 0.28,
                              minSecondFraction: 0.35,
                              first: const _ModuleListCard(),
                              second: Column(
                                    children: [
                                      const TabBar(
                                        isScrollable: true,
                                        tabs: [
                                          Tab(text: 'Template JSON'),
                                          Tab(text: 'Module detail'),
                                          Tab(text: 'UI config'),
                                          Tab(text: 'Default data'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            _TemplateJsonTab(templateAsync: selectedTemplateAsync),
                                            _ModuleDetailTab(moduleAsync: selectedModuleAsync),
                                            _ModuleUiConfigTab(moduleAsync: selectedModuleAsync),
                                            _ModuleDefaultDataTab(moduleAsync: selectedModuleAsync),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            )
                          : ResizableSplitPane(
                              axis: Axis.vertical,
                              initialFraction: 0.5,
                              minFirstFraction: 0.25,
                              minSecondFraction: 0.25,
                              first: const _ModuleListCard(),
                              second: Column(
                                    children: [
                                      const TabBar(
                                        isScrollable: true,
                                        tabs: [
                                          Tab(text: 'Template JSON'),
                                          Tab(text: 'Module detail'),
                                          Tab(text: 'UI config'),
                                          Tab(text: 'Default data'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            _TemplateJsonTab(templateAsync: selectedTemplateAsync),
                                            _ModuleDetailTab(moduleAsync: selectedModuleAsync),
                                            _ModuleUiConfigTab(moduleAsync: selectedModuleAsync),
                                            _ModuleDefaultDataTab(moduleAsync: selectedModuleAsync),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ModuleToolbar extends ConsumerStatefulWidget {
  const _ModuleToolbar();

  @override
  ConsumerState<_ModuleToolbar> createState() => _ModuleToolbarState();
}

class _ModuleToolbarState extends ConsumerState<_ModuleToolbar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = ref.read(templateWorkspaceProvider);
    _controller = TextEditingController(text: state.moduleQuery);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = ref.read(templateWorkspaceProvider).moduleQuery;
    if (_controller.text != query) {
      _controller.text = query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.read(templateWorkspaceProvider.notifier);
    final repository = ref.read(configuratorTemplateRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final moduleResource = findResourceByKey('template_modules');
    final templateId = ref.watch(templateWorkspaceProvider.select((value) => value.selectedTemplateId));
    final moduleQuery = ref.watch(templateWorkspaceProvider.select((value) => value.moduleQuery));
    if (_controller.text != moduleQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != moduleQuery) {
          _controller.text = moduleQuery;
        }
      });
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'module code / sheet / type',
            ),
            onSubmitted: browser.setModuleQuery,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => browser.setModuleQuery(_controller.text.trim()),
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('Apply module filter'),
        ),
        OutlinedButton.icon(
          onPressed: moduleQuery.isNotEmpty
              ? () {
                  _controller.clear();
                  browser.resetModuleFilters();
                }
              : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Reset filters'),
        ),
        FilledButton.icon(
          onPressed: templateId == null
              ? null
              : () async {
                  final payload = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => ResourceEditorDialog(
                      resource: moduleResource,
                      repository: adminRepository,
                      initialData: {'configurator_template_id': templateId},
                    ),
                  );
                  if (payload == null) return;
                  payload.putIfAbsent('configurator_template_id', () => templateId);
                  await repository.createModule(payload);
                  ref.invalidate(templateModulesProvider);
                },
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Create module'),
        ),
      ],
    );
  }
}

class _ModuleListCard extends ConsumerWidget {
  const _ModuleListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(templateModulesProvider);
    final browserState = ref.watch(templateWorkspaceProvider);
    final browser = ref.read(templateWorkspaceProvider.notifier);

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (response) {
        if (response == null || response.items.isEmpty) {
          return const Center(child: Text('No modules found for selected template'));
        }

        if (browserState.selectedModuleId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            browser.selectModule(response.items.first.id);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Rows: ${response.items.length} / total: ${response.total}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                key: PageStorageKey<String>(
                  'template-module-list-${browserState.selectedTemplateId ?? "none"}',
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
                          AdminTableHeaderCell(label: 'Module code', flex: 3),
                          AdminTableHeaderCell(label: 'Name', flex: 4),
                          AdminTableHeaderCell(label: 'Type / sheet', flex: 4),
                          AdminTableHeaderCell(label: 'Flags', flex: 3),
                        ],
                      ),
                    );
                  }

                  final rowIndex = index - 1;
                  final module = response.items[rowIndex];
                  final isSelected = browserState.selectedModuleId == module.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => browser.selectModule(module.id),
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
                                  module.moduleCode,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _StatusChip(label: module.moduleTypeCode),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(module.name, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          Text(
                            _jsonSummary(module.uiConfigJson),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(icon: Icons.sort_rounded, label: 'sort ${module.sortOrder}'),
                              if (module.sourceSheetName != null)
                                _MetaChip(
                                  icon: Icons.grid_view_rounded,
                                  label: module.sourceSheetName!,
                                ),
                              _BooleanChip(label: 'editable', active: module.isEditable),
                              _BooleanChip(label: 'resettable', active: module.isResettable),
                              _BooleanChip(label: 'active', active: module.isActive),
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
        );
      },
    );
  }
}

class _TemplateJsonTab extends StatelessWidget {
  const _TemplateJsonTab({required this.templateAsync});

  final AsyncValue<ConfiguratorTemplate?> templateAsync;

  @override
  Widget build(BuildContext context) {
    return templateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (template) {
        if (template == null) {
          return const Center(child: Text('Select a configurator template'));
        }
        return ListView(
          children: [
            JsonViewCard(title: 'UI Schema JSON', data: template.uiSchemaJson),
            const SizedBox(height: 12),
            JsonViewCard(title: 'Default Values JSON', data: template.defaultValuesJson),
            const SizedBox(height: 12),
            JsonViewCard(title: 'Raw template JSON', data: template.raw),
          ],
        );
      },
    );
  }
}

class _ModuleDetailTab extends ConsumerWidget {
  const _ModuleDetailTab({required this.moduleAsync});

  final AsyncValue<TemplateModule?> moduleAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(configuratorTemplateRepositoryProvider);
    final adminRepository = ref.read(resourceRepositoryProvider);
    final moduleResource = findResourceByKey('template_modules');

    return moduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (module) {
        if (module == null) {
          return const Center(child: Text('Select a template module'));
        }

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(module.moduleCode),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final payload = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => ResourceEditorDialog(
                        resource: moduleResource,
                        repository: adminRepository,
                        initialData: module.raw,
                      ),
                    );
                    if (payload == null) return;
                    await repository.updateModule(module.id, payload);
                    ref.invalidate(templateModulesProvider);
                    ref.invalidate(selectedTemplateModuleProvider);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit module'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await _confirmDelete(
                      context,
                      'Delete module ${module.moduleCode}?',
                      'This removes the template module from the selected configurator template.',
                    );
                    if (!confirmed) return;
                    await repository.deleteModule(module.id);
                    ref.read(templateWorkspaceProvider.notifier).selectModule(null);
                    ref.invalidate(templateModulesProvider);
                    ref.invalidate(selectedTemplateModuleProvider);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(label: module.moduleTypeCode),
                _MetaChip(icon: Icons.sort_rounded, label: 'Sort ${module.sortOrder}'),
                _BooleanChip(label: 'editable', active: module.isEditable),
                _BooleanChip(label: 'resettable', active: module.isResettable),
                _BooleanChip(label: 'active', active: module.isActive),
              ],
            ),
            const SizedBox(height: 16),
            _DetailLine(label: 'Module id', value: module.id),
            _DetailLine(label: 'Template id', value: module.configuratorTemplateId),
            _DetailLine(label: 'Module code', value: module.moduleCode),
            _DetailLine(label: 'Name', value: module.name),
            _DetailLine(label: 'Type', value: module.moduleTypeCode),
            _DetailLine(label: 'Source sheet', value: module.sourceSheetName ?? '—'),
            _DetailLine(label: 'Source range', value: module.sourceRange ?? '—'),
            _DetailLine(label: 'Target range', value: module.targetRange ?? '—'),
            _DetailLine(label: 'Reset source range', value: module.resetSourceRange ?? '—'),
            _DetailLine(label: 'Created', value: _dateTimeLabel(module.createdAt)),
            _DetailLine(label: 'Updated', value: _dateTimeLabel(module.updatedAt)),
            const SizedBox(height: 12),
            JsonViewCard(title: 'Raw module JSON', data: module.raw),
          ],
        );
      },
    );
  }
}

class _ModuleUiConfigTab extends StatelessWidget {
  const _ModuleUiConfigTab({required this.moduleAsync});

  final AsyncValue<TemplateModule?> moduleAsync;

  @override
  Widget build(BuildContext context) {
    return moduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (module) {
        if (module == null) {
          return const Center(child: Text('Select a template module'));
        }
        return ListView(
          children: [
            JsonViewCard(title: 'UI Config JSON', data: module.uiConfigJson),
          ],
        );
      },
    );
  }
}

class _ModuleDefaultDataTab extends StatelessWidget {
  const _ModuleDefaultDataTab({required this.moduleAsync});

  final AsyncValue<TemplateModule?> moduleAsync;

  @override
  Widget build(BuildContext context) {
    return moduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error),
      data: (module) {
        if (module == null) {
          return const Center(child: Text('Select a template module'));
        }
        return ListView(
          children: [
            JsonViewCard(title: 'Default Data JSON', data: module.defaultDataJson),
          ],
        );
      },
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
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
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
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
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = label.toLowerCase();
    final background = switch (normalized) {
      'published' => scheme.secondaryContainer,
      'draft' => scheme.tertiaryContainer,
      'archived' => scheme.surfaceContainerHighest,
      _ => scheme.surfaceContainerHighest,
    };

    return Chip(
      label: Text(label),
      backgroundColor: background,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _BooleanChip extends StatelessWidget {
  const _BooleanChip({
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text('Request failed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SelectableText('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
  );

  return result ?? false;
}

String _shortId(String value) => value.length <= 8 ? value : value.substring(0, 8);

String _dateTimeLabel(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('MM-dd-yy HH:mm').format(parsed.toLocal());
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



Map<String, String> _templateNavigationFilters(Map<String, String> filters) {
  return <String, String>{
    if ((filters['product_family_id'] ?? '').isNotEmpty)
      'product_family_id': filters['product_family_id']!,
    if ((filters['roof_model_id'] ?? '').isNotEmpty) 'roof_model_id': filters['roof_model_id']!,
  };
}

bool _sameStringMap(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

String _lookupLabel(AdminLookup lookup, Map<String, dynamic> row) {
  final labels = <String>[];
  for (final key in lookup.labelKeys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      labels.add(value.toString());
    }
  }
  if (labels.isEmpty) {
    return row[lookup.idKey]?.toString() ?? '—';
  }
  return labels.join(' · ');
}

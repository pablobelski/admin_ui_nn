import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/json_view_card.dart';
import '../data/calculator_models.dart';
import 'calculator_providers.dart';

const _steps = <_StepDefinition>[
  _StepDefinition('product', 'Product', Icons.inventory_2_outlined),
  _StepDefinition('template', 'Template', Icons.account_tree_outlined),
  _StepDefinition('model', 'Model', Icons.view_in_ar_outlined),
  _StepDefinition('dimensions', 'Dimensions', Icons.straighten_outlined),
  _StepDefinition('covering', 'Covering', Icons.layers_outlined),
  _StepDefinition('color', 'Color', Icons.palette_outlined),
  _StepDefinition('options', 'Options', Icons.tune_outlined),
  _StepDefinition('delivery', 'Delivery', Icons.local_shipping_outlined),
  _StepDefinition('summary', 'Summary', Icons.summarize_outlined),
];

final _moneyFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');

class CalculatorWorkspacePage extends ConsumerStatefulWidget {
  const CalculatorWorkspacePage({super.key});

  @override
  ConsumerState<CalculatorWorkspacePage> createState() => _CalculatorWorkspacePageState();
}

class _CalculatorWorkspacePageState extends ConsumerState<CalculatorWorkspacePage> {
  var _selectedStep = 0;

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(calculatorContextProvider);
    final draft = ref.watch(calculatorDraftProvider);
    final resultAsync = ref.watch(calculatorResultProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1280;

    return contextAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorCard(
        title: 'Calculator context failed',
        message: '$error',
        onRetry: () => ref.invalidate(calculatorContextProvider),
      ),
      data: (calculatorContext) {
        final selectedTemplate = calculatorContext.templates
            .where((entry) => entry.id == draft.templateId)
            .cast<CalculatorTemplateOption?>()
            .firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              onRefresh: () {
                ref.invalidate(calculatorContextProvider);
                ref.read(calculatorResultProvider.notifier).clear();
              },
              onCalculate: () => _calculate(context),
              canCalculate: draft.templateId != null && draft.widthMm != null && draft.depthMm != null,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 245,
                          child: _StepRail(
                            selectedIndex: _selectedStep,
                            draft: draft,
                            onSelect: (index) => setState(() => _selectedStep = index),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _StepCard(
                            selectedStep: _selectedStep,
                            calculatorContext: calculatorContext,
                            draft: draft,
                            selectedTemplate: selectedTemplate,
                            onNext: () => setState(() => _selectedStep = (_selectedStep + 1).clamp(0, _steps.length - 1).toInt()),
                            onBack: () => setState(() => _selectedStep = (_selectedStep - 1).clamp(0, _steps.length - 1).toInt()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _ResultPanel(resultAsync: resultAsync, draft: draft),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 88,
                          child: _StepScroller(
                            selectedIndex: _selectedStep,
                            onSelect: (index) => setState(() => _selectedStep = index),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _StepCard(
                            selectedStep: _selectedStep,
                            calculatorContext: calculatorContext,
                            draft: draft,
                            selectedTemplate: selectedTemplate,
                            onNext: () => setState(() => _selectedStep = (_selectedStep + 1).clamp(0, _steps.length - 1).toInt()),
                            onBack: () => setState(() => _selectedStep = (_selectedStep - 1).clamp(0, _steps.length - 1).toInt()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 310,
                          child: _ResultPanel(resultAsync: resultAsync, draft: draft),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _calculate(BuildContext context) async {
    final draft = ref.read(calculatorDraftProvider);
    if (draft.templateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a template first.')),
      );
      return;
    }

    final resultNotifier = ref.read(calculatorResultProvider.notifier);
    resultNotifier.setLoading();
    try {
      final result = await ref.read(calculatorRepositoryProvider).calculate(draft);
      resultNotifier.setData(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculation finished')),
      );
    } catch (error, stackTrace) {
      resultNotifier.setError(error, stackTrace);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onRefresh,
    required this.onCalculate,
    required this.canCalculate,
  });

  final VoidCallback onRefresh;
  final VoidCallback onCalculate;
  final bool canCalculate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.calculate_outlined, color: Theme.of(context).colorScheme.primary),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calculator Workspace', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Internal step-by-step configurator: Product → Template → Model → Dimensions → Covering → Color → Options → Delivery → Summary.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SpacerBox(width: 1),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh context'),
        ),
        FilledButton.icon(
          onPressed: canCalculate ? onCalculate : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Calculate'),
        ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.selectedIndex,
    required this.draft,
    required this.onSelect,
  });

  final int selectedIndex;
  final CalculatorDraft draft;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final step = _steps[index];
          final selected = index == selectedIndex;
          final complete = _isStepComplete(step.key, draft);
          return ListTile(
            dense: true,
            selected: selected,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(complete ? Icons.check_circle : step.icon),
            title: Text(step.title),
            subtitle: Text(_stepHint(step.key, draft), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _StepScroller extends StatelessWidget {
  const _StepScroller({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, index) {
        final step = _steps[index];
        return ChoiceChip(
          selected: index == selectedIndex,
          avatar: Icon(step.icon, size: 18),
          label: Text(step.title),
          onSelected: (_) => onSelect(index),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemCount: _steps.length,
    );
  }
}

class _StepCard extends ConsumerWidget {
  const _StepCard({
    required this.selectedStep,
    required this.calculatorContext,
    required this.draft,
    required this.selectedTemplate,
    required this.onNext,
    required this.onBack,
  });

  final int selectedStep;
  final CalculatorContext calculatorContext;
  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = _steps[selectedStep];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(step.icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(step.title, style: Theme.of(context).textTheme.titleLarge),
                ),
                Text('${selectedStep + 1}/${_steps.length}', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(context, ref, step.key),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: selectedStep == 0 ? null : onBack,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: selectedStep == _steps.length - 1 ? null : onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, WidgetRef ref, String key) {
    final notifier = ref.read(calculatorDraftProvider.notifier);
    switch (key) {
      case 'product':
        return _ProductStep(
          contextData: calculatorContext,
          draft: draft,
          onOrganizationChanged: notifier.setOrganization,
          onProductFamilyChanged: notifier.setProductFamily,
          onPriceModeChanged: notifier.setPriceMode,
        );
      case 'template':
        return _TemplateStep(
          contextData: calculatorContext,
          draft: draft,
          selectedTemplate: selectedTemplate,
          onTemplateChanged: notifier.setTemplate,
        );
      case 'model':
        return _SelectStep(
          title: 'Model / construction type',
          description: 'Uses reference domain skyview_models for now. Later this should come from ui_schema_json per template.',
          value: draft.modelCode,
          options: calculatorContext.references['skyview_models'] ?? const [],
          onChanged: notifier.setModel,
          emptyLabel: '— Model not selected —',
        );
      case 'dimensions':
        return _DimensionsStep(draft: draft, notifier: notifier);
      case 'covering':
        return _SelectStep(
          title: 'Covering / Eindeckung',
          description: 'For TDS/SkyView Glas the existing reference domain tds_glass_covering is used. Poly options should be moved into a dedicated domain or template schema.',
          value: draft.coveringCode,
          options: calculatorContext.references['tds_glass_covering'] ?? const [],
          onChanged: notifier.setCovering,
          emptyLabel: '— Covering not selected —',
        );
      case 'color':
        return _SelectStep(
          title: 'Frame color',
          description: 'Uses reference domain colors: 7016, 9006, 9007, 9010. Special colors should become a separate option group.',
          value: draft.colorCode,
          options: calculatorContext.references['colors'] ?? const [],
          onChanged: notifier.setColor,
          emptyLabel: '— Color not selected —',
        );
      case 'options':
        return _OptionsStep(draft: draft, notifier: notifier);
      case 'delivery':
        return _SelectStep(
          title: 'Delivery / handover',
          description: 'Uses handover_types. Delivery price can be calculated as an extra price mode or a separate delivery service line.',
          value: draft.handoverTypeCode,
          options: calculatorContext.references['handover_types'] ?? const [],
          onChanged: notifier.setHandover,
          emptyLabel: '— Delivery not selected —',
        );
      case 'summary':
      default:
        return _SummaryStep(draft: draft, selectedTemplate: selectedTemplate);
    }
  }
}

class _ProductStep extends StatelessWidget {
  const _ProductStep({
    required this.contextData,
    required this.draft,
    required this.onOrganizationChanged,
    required this.onProductFamilyChanged,
    required this.onPriceModeChanged,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final ValueChanged<String?> onOrganizationChanged;
  final ValueChanged<String?> onProductFamilyChanged;
  final ValueChanged<String?> onPriceModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calculation context', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Internal users may choose organization and price mode. Customer API must derive these values from the authenticated session.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _DropdownField(
          label: 'Organization',
          value: draft.organizationId,
          options: contextData.organizations,
          idSelector: (option) => option.id,
          onChanged: onOrganizationChanged,
          emptyLabel: '— No organization terms —',
        ),
        const SizedBox(height: 16),
        _DropdownField(
          label: 'Product family',
          value: draft.productFamilyId,
          options: contextData.productFamilies,
          idSelector: (option) => option.id,
          onChanged: onProductFamilyChanged,
          emptyLabel: '— All templates —',
        ),
        const SizedBox(height: 16),
        _DropdownField(
          label: 'Price mode',
          value: draft.priceMode,
          options: contextData.priceModes,
          idSelector: (option) => option.code,
          onChanged: onPriceModeChanged,
          emptyLabel: null,
        ),
      ],
    );
  }
}

class _TemplateStep extends StatelessWidget {
  const _TemplateStep({
    required this.contextData,
    required this.draft,
    required this.selectedTemplate,
    required this.onTemplateChanged,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;
  final ValueChanged<String?> onTemplateChanged;

  @override
  Widget build(BuildContext context) {
    final templates = draft.productFamilyId == null
        ? contextData.templates
        : contextData.templates.where((entry) => entry.productFamilyId == draft.productFamilyId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TemplateDropdown(
          value: draft.templateId,
          templates: templates,
          onChanged: onTemplateChanged,
        ),
        const SizedBox(height: 20),
        if (selectedTemplate == null)
          const _HintCard(
            icon: Icons.info_outline,
            title: 'Select a published configurator template',
            text: 'The backend will resolve the imported pricing product family, price list and matrix from this template.',
          )
        else
          _TemplateInfoCard(template: selectedTemplate!),
      ],
    );
  }
}

class _DimensionsStep extends StatefulWidget {
  const _DimensionsStep({
    required this.draft,
    required this.notifier,
  });

  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;

  @override
  State<_DimensionsStep> createState() => _DimensionsStepState();
}

class _DimensionsStepState extends State<_DimensionsStep> {
  late final TextEditingController _width;
  late final TextEditingController _depth;
  late final TextEditingController _height;

  @override
  void initState() {
    super.initState();
    _width = TextEditingController(text: widget.draft.widthMm?.toString() ?? '');
    _depth = TextEditingController(text: widget.draft.depthMm?.toString() ?? '');
    _height = TextEditingController(text: widget.draft.heightMm?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _DimensionsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_width, widget.draft.widthMm);
    _sync(_depth, widget.draft.depthMm);
    _sync(_height, widget.draft.heightMm);
  }

  void _sync(TextEditingController controller, int? value) {
    final text = value?.toString() ?? '';
    if (controller.text != text) controller.text = text;
  }

  @override
  void dispose() {
    _width.dispose();
    _depth.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dimensions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('MVP uses width/depth/height. CalculationService then matches price_matrix_cells by exact or next greater grid cell.'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _NumberField(label: 'Width mm', controller: _width, onChanged: widget.notifier.setWidth),
            _NumberField(label: 'Depth mm', controller: _depth, onChanged: widget.notifier.setDepth),
            _NumberField(label: 'Height mm', controller: _height, onChanged: widget.notifier.setHeight),
          ],
        ),
        const SizedBox(height: 20),
        const _HintCard(
          icon: Icons.grid_on_outlined,
          title: 'Matrix-aware matching',
          text: 'For roof_matrix: width + depth. For height_width_grid: width + height. This should later be driven by template.ui_schema_json.',
        ),
      ],
    );
  }
}

class _SelectStep extends StatelessWidget {
  const _SelectStep({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.emptyLabel,
  });

  final String title;
  final String description;
  final String? value;
  final List<CalculatorOption> options;
  final ValueChanged<String?> onChanged;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(description),
        const SizedBox(height: 20),
        _DropdownField(
          label: title,
          value: value,
          options: options,
          idSelector: (option) => option.code,
          onChanged: onChanged,
          emptyLabel: emptyLabel,
        ),
      ],
    );
  }
}

class _OptionsStep extends StatefulWidget {
  const _OptionsStep({
    required this.draft,
    required this.notifier,
  });

  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;

  @override
  State<_OptionsStep> createState() => _OptionsStepState();
}

class _OptionsStepState extends State<_OptionsStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options / accessories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('For the first integration pass, options can be entered by target_code. Later replace this with catalog item lookup grouped by category.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Option target_code',
                  hintText: 'Example: service_installation or accessory code',
                ),
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _add(_controller.text),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (widget.draft.options.isEmpty)
          const _HintCard(
            icon: Icons.tune_outlined,
            title: 'No options selected',
            text: 'The selected price matrix will still calculate the base system price.',
          )
        else
          Column(
            children: [
              for (var i = 0; i < widget.draft.options.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.extension_outlined),
                    title: Text(widget.draft.options[i].optionCode ?? widget.draft.options[i].catalogItemId ?? 'Option'),
                    subtitle: Text('Quantity: ${widget.draft.options[i].quantity}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => widget.notifier.removeOptionAt(i),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _add(String value) {
    widget.notifier.addOptionCode(value);
    _controller.clear();
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    required this.draft,
    required this.selectedTemplate,
  });

  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Input summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _SummaryRow('Template', selectedTemplate?.name ?? '—'),
        _SummaryRow('Price mode', draft.priceMode),
        _SummaryRow('Model', draft.modelCode ?? '—'),
        _SummaryRow('Dimensions', [
          if (draft.widthMm != null) '${draft.widthMm} mm W',
          if (draft.depthMm != null) '${draft.depthMm} mm D',
          if (draft.heightMm != null) '${draft.heightMm} mm H',
        ].join(' × ')),
        _SummaryRow('Covering', draft.coveringCode ?? '—'),
        _SummaryRow('Color', draft.colorCode ?? '—'),
        _SummaryRow('Delivery', draft.handoverTypeCode ?? '—'),
        _SummaryRow('Options', draft.options.isEmpty ? '—' : '${draft.options.length} selected'),
        const SizedBox(height: 16),
        const _HintCard(
          icon: Icons.play_arrow_outlined,
          title: 'Run calculation',
          text: 'Click Calculate in the top right. The right panel will show price, BOM preview, price sources and trace.',
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.resultAsync,
    required this.draft,
  });

  final AsyncValue<CalculatorResult?> resultAsync;
  final CalculatorDraft draft;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorCard(
          title: 'Calculation failed',
          message: '$error',
        ),
        data: (result) {
          if (result == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: _HintCard(
                icon: Icons.calculate_outlined,
                title: 'No calculation yet',
                text: 'Fill the steps and run Calculate. Internal result will include sources, BOM and trace.',
              ),
            );
          }
          return DefaultTabController(
            length: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: _PriceHeader(result: result),
                ),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Lines'),
                    Tab(text: 'BOM'),
                    Tab(text: 'Sources'),
                    Tab(text: 'Trace'),
                    Tab(text: 'JSON'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LinesTab(result: result),
                      _SimpleRowsTab(rows: result.bom, empty: 'No BOM lines yet.'),
                      JsonViewCard(title: 'Price sources', data: result.sources),
                      _SimpleRowsTab(rows: result.trace, empty: 'No trace.'),
                      JsonViewCard(title: 'Raw calculation result', data: result.raw),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({required this.result});

  final CalculatorResult result;

  @override
  Widget build(BuildContext context) {
    final net = _num(result.price['net']);
    final gross = _num(result.price['gross']);
    final margin = result.internalPrice['margin'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net price', style: Theme.of(context).textTheme.labelLarge),
                  Text(_moneyFormat.format(net), style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            Chip(
              avatar: Icon(result.status == 'valid' ? Icons.check_circle : Icons.warning_amber_rounded),
              label: Text(result.status),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(label: 'Gross', value: _moneyFormat.format(gross)),
            if (margin != null) _MetricChip(label: 'Margin', value: _moneyFormat.format(_num(margin))),
            _MetricChip(label: 'Currency', value: result.currency),
          ],
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('⚠ ${warning['message'] ?? warning['code']}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ],
    );
  }
}

class _LinesTab extends StatelessWidget {
  const _LinesTab({required this.result});

  final CalculatorResult result;

  @override
  Widget build(BuildContext context) {
    if (result.visibleLines.isEmpty) {
      return const Center(child: Text('No lines.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: result.visibleLines.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final line = result.visibleLines[index];
        return ListTile(
          title: Text('${line['label'] ?? 'Line'}'),
          subtitle: Text('Qty ${line['quantity'] ?? 1} ${line['unit'] ?? ''}'),
          trailing: Text(_moneyFormat.format(_num(line['amount']))),
        );
      },
    );
  }
}

class _SimpleRowsTab extends StatelessWidget {
  const _SimpleRowsTab({
    required this.rows,
    required this.empty,
  });

  final List<Map<String, dynamic>> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Center(child: Text(empty));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        final title = row['name'] ?? row['step'] ?? row['article_no'] ?? 'Row ${index + 1}';
        final subtitle = row.entries
            .where((entry) => !['name', 'step'].contains(entry.key))
            .take(4)
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · ');
        return ListTile(
          dense: true,
          title: Text('$title'),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.idSelector,
    required this.onChanged,
    this.emptyLabel,
  });

  final String label;
  final String? value;
  final List<CalculatorOption> options;
  final String Function(CalculatorOption option) idSelector;
  final ValueChanged<String?> onChanged;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final selectedValue = options.any((entry) => idSelector(entry) == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (emptyLabel != null) DropdownMenuItem(value: '', child: Text(emptyLabel!)),
        for (final option in options)
          DropdownMenuItem(
            value: idSelector(option),
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (next) => onChanged(next == '' ? null : next),
    );
  }
}

class _TemplateDropdown extends StatelessWidget {
  const _TemplateDropdown({
    required this.value,
    required this.templates,
    required this.onChanged,
  });

  final String? value;
  final List<CalculatorTemplateOption> templates;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = templates.any((entry) => entry.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Configurator template'),
      items: [
        const DropdownMenuItem(value: '', child: Text('— Select template —')),
        for (final template in templates)
          DropdownMenuItem(
            value: template.id,
            child: Text('${template.name} · ${template.productFamilyName}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (next) => onChanged(next == '' ? null : next),
    );
  }
}

class _TemplateInfoCard extends StatelessWidget {
  const _TemplateInfoCard({required this.template});

  final CalculatorTemplateOption template;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Code: ${template.code}'),
            Text('Template family: ${template.productFamilyCode} / ${template.productFamilyName}'),
            Text('Material variant: ${template.defaultValues['material_variant'] ?? '—'}'),
            const SizedBox(height: 12),
            const Text('CalculationService resolves imported pricing family codes like SKY / TD / FLT / VS when live templates are linked to legacy families.'),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: 'mm'),
        onChanged: onChanged,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _StepDefinition {
  const _StepDefinition(this.key, this.title, this.icon);

  final String key;
  final String title;
  final IconData icon;
}

class SpacerBox extends StatelessWidget {
  const SpacerBox({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}

bool _isStepComplete(String key, CalculatorDraft draft) {
  switch (key) {
    case 'product':
      return draft.priceMode.isNotEmpty;
    case 'template':
      return draft.templateId != null;
    case 'model':
      return draft.modelCode != null;
    case 'dimensions':
      return draft.widthMm != null && draft.depthMm != null;
    case 'covering':
      return draft.coveringCode != null;
    case 'color':
      return draft.colorCode != null;
    case 'options':
      return draft.options.isNotEmpty;
    case 'delivery':
      return draft.handoverTypeCode != null;
    case 'summary':
      return draft.templateId != null && draft.widthMm != null && draft.depthMm != null;
    default:
      return false;
  }
}

String _stepHint(String key, CalculatorDraft draft) {
  switch (key) {
    case 'product':
      return draft.priceMode;
    case 'template':
      return draft.templateId == null ? 'not selected' : 'selected';
    case 'model':
      return draft.modelCode ?? 'optional';
    case 'dimensions':
      return [draft.widthMm, draft.depthMm, draft.heightMm].whereType<int>().join(' × ');
    case 'covering':
      return draft.coveringCode ?? 'optional';
    case 'color':
      return draft.colorCode ?? 'optional';
    case 'options':
      return draft.options.isEmpty ? 'none' : '${draft.options.length} selected';
    case 'delivery':
      return draft.handoverTypeCode ?? 'optional';
    case 'summary':
      return 'review';
    default:
      return '';
  }
}

num _num(dynamic value) {
  if (value is num) return value;
  if (value == null) return 0;
  return num.tryParse('$value') ?? 0;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

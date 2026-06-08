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
  var _isSavingQuote = false;
  SavedQuote? _savedQuote;

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(calculatorContextProvider);
    final draft = ref.watch(calculatorDraftProvider);
    final resultAsync = ref.watch(calculatorResultProvider);
    final loadedQuote = ref.watch(loadedQuoteProvider);
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

        final roofModelState = _roofModelStateFor(
          calculatorContext,
          draft,
          selectedTemplate,
        );
        final disabledStepKeys = <String>{
          if (!roofModelState.required) 'model',
        };
        final canCalculate = draft.templateId != null &&
            draft.widthMm != null &&
            draft.depthMm != null &&
            roofModelState.isSelected(draft.modelCode);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              loadedQuote: loadedQuote,
              onNewCalculation: () => _confirmNewCalculation(context),
              onRefresh: () {
                ref.invalidate(calculatorContextProvider);
                ref.read(calculatorResultProvider.notifier).clear();
                setState(() => _savedQuote = null);
              },
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
                            disabledStepKeys: disabledStepKeys,
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
                            onNext: () => _moveStep(disabledStepKeys, 1),
                            onBack: () => _moveStep(disabledStepKeys, -1),
                            onCalculate: () => _calculate(context),
                            canCalculate: canCalculate,
                            roofModelState: roofModelState,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _ResultPanel(
                            resultAsync: resultAsync,
                            draft: draft,
                            loadedQuote: loadedQuote,
                            savedQuote: _savedQuote,
                            isSavingQuote: _isSavingQuote,
                            onSaveQuote: () => _showSaveQuoteDialog(context),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 88,
                          child: _StepScroller(
                            selectedIndex: _selectedStep,
                            disabledStepKeys: disabledStepKeys,
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
                            onNext: () => _moveStep(disabledStepKeys, 1),
                            onBack: () => _moveStep(disabledStepKeys, -1),
                            onCalculate: () => _calculate(context),
                            canCalculate: canCalculate,
                            roofModelState: roofModelState,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 360,
                          child: _ResultPanel(
                            resultAsync: resultAsync,
                            draft: draft,
                            loadedQuote: loadedQuote,
                            savedQuote: _savedQuote,
                            isSavingQuote: _isSavingQuote,
                            onSaveQuote: () => _showSaveQuoteDialog(context),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _moveStep(Set<String> disabledStepKeys, int direction) {
    var next = _selectedStep;

    while (true) {
      next += direction;
      if (next < 0 || next >= _steps.length) {
        next = next.clamp(0, _steps.length - 1).toInt();
        break;
      }

      if (!disabledStepKeys.contains(_steps[next].key)) {
        break;
      }
    }

    setState(() => _selectedStep = next);
  }

  Future<void> _confirmNewCalculation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start new calculation?'),
        content: const Text(
          'Current calculator input will be cleared. Unsaved changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('New calculation'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ref.read(loadedQuoteProvider.notifier).clear();
    ref.read(calculatorDraftProvider.notifier).reset();
    ref.read(calculatorResultProvider.notifier).clear();

    setState(() {
      _selectedStep = 0;
      _savedQuote = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New calculation started')),
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

    setState(() => _savedQuote = null);
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

  Future<void> _showSaveQuoteDialog(BuildContext context) async {
    final result = ref.read(calculatorResultProvider).maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run calculation before saving quote.')),
      );
      return;
    }

    final draft = ref.read(calculatorDraftProvider);
    final loadedQuote = ref.read(loadedQuoteProvider);
    final canSaveAsOption = draft.canSaveAsOptionFor(loadedQuote);

    final mode = await showDialog<SaveQuoteMode>(
      context: context,
      builder: (_) => _SaveQuoteModeDialog(
        loadedQuote: loadedQuote,
        canSaveAsOption: canSaveAsOption,
      ),
    );

    if (mode == null || !context.mounted) return;
    await _saveQuote(context, mode);
  }

  Future<void> _saveQuote(BuildContext context, SaveQuoteMode mode) async {
    final loadedQuote = ref.read(loadedQuoteProvider);

    setState(() => _isSavingQuote = true);
    try {
      final repository = ref.read(calculatorRepositoryProvider);
      final savedQuote = await repository.saveQuote(
        ref.read(calculatorDraftProvider),
        mode: mode,
        baseQuoteId: mode == SaveQuoteMode.asOption ? loadedQuote?.id : null,
      );
      final savedLoadedQuote = await repository.loadQuoteForWorkspace(savedQuote.id);

      if (!mounted || !context.mounted) return;

      ref.read(loadedQuoteProvider.notifier).set(savedLoadedQuote);
      ref.read(calculatorDraftProvider.notifier).loadQuote(savedLoadedQuote);

      final loadedResult = savedLoadedQuote.resultJson == null
          ? null
          : CalculatorResult.fromJson(savedLoadedQuote.resultJson!);
      if (loadedResult == null) {
        ref.read(calculatorResultProvider.notifier).clear();
      } else {
        ref.read(calculatorResultProvider.notifier).setData(loadedResult);
      }

      setState(() => _savedQuote = savedQuote);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quote saved ${mode.label}: ${savedLoadedQuote.quoteNo}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save quote failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingQuote = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onRefresh,
    required this.onNewCalculation,
    required this.loadedQuote,
  });

  final VoidCallback onRefresh;
  final VoidCallback onNewCalculation;
  final LoadedQuote? loadedQuote;

  @override
  Widget build(BuildContext context) {
    final quoteLabel = loadedQuote?.quoteNo ?? 'new quote';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.calculate_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
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
        ),
        const SizedBox(width: 12),
        Chip(
          avatar: Icon(
            loadedQuote == null ? Icons.add_circle_outline : Icons.request_quote_outlined,
            size: 18,
          ),
          label: Text(quoteLabel),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onNewCalculation,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('New calculation'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh context'),
        ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.selectedIndex,
    required this.disabledStepKeys,
    required this.draft,
    required this.onSelect,
  });

  final int selectedIndex;
  final Set<String> disabledStepKeys;
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
          final disabled = disabledStepKeys.contains(step.key);
          final complete = !disabled && _isStepComplete(step.key, draft);
          return ListTile(
            enabled: !disabled,
            dense: true,
            selected: selected,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(disabled ? Icons.lock_outline : complete ? Icons.check_circle : step.icon),
            title: Text(step.title),
            subtitle: Text(disabled ? 'not configured for selected template' : _stepHint(step.key, draft), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: disabled ? null : () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _StepScroller extends StatelessWidget {
  const _StepScroller({
    required this.selectedIndex,
    required this.disabledStepKeys,
    required this.onSelect,
  });

  final int selectedIndex;
  final Set<String> disabledStepKeys;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, index) {
        final step = _steps[index];
        final disabled = disabledStepKeys.contains(step.key);
        return ChoiceChip(
          selected: index == selectedIndex,
          avatar: Icon(disabled ? Icons.lock_outline : step.icon, size: 18),
          label: Text(step.title),
          onSelected: disabled ? null : (_) => onSelect(index),
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
    required this.onCalculate,
    required this.canCalculate,
    required this.roofModelState,
  });

  final int selectedStep;
  final CalculatorContext calculatorContext;
  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onCalculate;
  final bool canCalculate;
  final _RoofModelStepState roofModelState;

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
                Expanded(child: Text(step.title, style: Theme.of(context).textTheme.titleLarge)),
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: selectedStep == _steps.length - 1 ? null : onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canCalculate ? onCalculate : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Calculate'),
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
        return _ModelStep(
          roofModelState: roofModelState,
          draft: draft,
          onChanged: notifier.setModel,
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
        final result = ref.watch(calculatorResultProvider).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );
        return _OptionsStep(
          contextData: calculatorContext,
          draft: draft,
          notifier: notifier,
          optionDiagnostics: result?.optionDiagnostics ?? const [],
        );
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

class _DisabledStep extends StatelessWidget {
  const _DisabledStep({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _HintCard(icon: Icons.lock_outline, title: title, text: text);
  }
}

class _ModelStep extends StatelessWidget {
  const _ModelStep({
    required this.roofModelState,
    required this.draft,
    required this.onChanged,
  });

  final _RoofModelStepState roofModelState;
  final CalculatorDraft draft;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!roofModelState.required) {
      return const _DisabledStep(
        title: 'Model / construction type is not configured',
        text: 'No roof models exist for the selected product family. This step is skipped for the current calculation.',
      );
    }

    if (roofModelState.options.isEmpty) {
      return const _HintCard(
        icon: Icons.warning_amber_outlined,
        title: 'No roof models for selected template',
        text: 'Roof models exist for this product family, so Model is required. Link one or more roof models to the selected configurator template, or choose another template.',
      );
    }

    return _SelectStep(
      title: 'Model / construction type',
      description: 'Roof models are filtered by both product family and configurator template.',
      value: draft.modelCode,
      options: roofModelState.options,
      onChanged: onChanged,
      emptyLabel: '— Model not selected —',
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
    required this.contextData,
    required this.draft,
    required this.notifier,
    required this.optionDiagnostics,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final List<Map<String, dynamic>> optionDiagnostics;

  @override
  State<_OptionsStep> createState() => _OptionsStepState();
}

class _OptionsStepState extends State<_OptionsStep> {
  final _catalogItemController = TextEditingController();
  final _catalogVariantController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _catalogItemFocusNode = FocusNode();
  final _catalogVariantFocusNode = FocusNode();
  final Map<String, TextEditingController> _additionalHandlingControllers = {};
  final Set<String> _enabledAdditionalHandlingIds = <String>{};
  var _additionalHandlingInputEnabled = false;

  String? _pendingAdditionalHandlingId;
  String? _itemTypeCode;
  String? _catalogItemId;
  String? _catalogVariantId;
  String? _salesUnitCode;

  @override
  void dispose() {
    _catalogItemController.dispose();
    _catalogVariantController.dispose();
    _quantityController.dispose();
    for (final controller in _additionalHandlingControllers.values) {
      controller.dispose();
    }
    _catalogItemFocusNode.dispose();
    _catalogVariantFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsForSelectedType();
    final selectedItem = _findItem(_catalogItemId);
    final variantsForItem = _allVariantsForSelectedItem();
    final selectedVariant = _findVariant(_catalogVariantId);
    final additionalHandlingOptions = selectedItem == null
        ? const <CalculatorAdditionalHandlingOption>[]
        : widget.contextData.additionalHandlingByParentItemId[selectedItem.id] ?? const <CalculatorAdditionalHandlingOption>[];
    final addRequiresVariant = selectedItem != null && variantsForItem.isNotEmpty;
    final canAdd = selectedItem != null && (!addRequiresVariant || selectedVariant != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options / additional catalog positions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Options are additional catalog positions selected only for the current calculation. They do not change the base set, but are added to price lines and option BOM.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _itemTypeCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Item type'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('— All item types —')),
                  for (final option in widget.contextData.optionItemTypes)
                    DropdownMenuItem(value: option.code, child: Text(option.label)),
                ],
                onChanged: (value) => setState(() {
                  _itemTypeCode = value == null || value.isEmpty ? null : value;
                  _catalogItemId = null;
                  _catalogVariantId = null;
                  _salesUnitCode = null;
                  _catalogItemController.clear();
                  _catalogVariantController.clear();
                  _resetAdditionalHandlingInputs();
                }),
              ),
            ),
            SizedBox(
              width: 520,
              child: _SearchableOptionField<CalculatorCatalogItemOption>(
                label: 'Catalog item',
                hintText: 'Type to search catalog items',
                controller: _catalogItemController,
                focusNode: _catalogItemFocusNode,
                options: items,
                displayStringForOption: _itemLabel,
                searchStringForOption: _itemSearchText,
                onSelected: (item) {
                  final variants = _variantsForItem(item.id);
                  final onlyVariant = variants.length == 1 ? variants.first : null;
                  setState(() {
                    _catalogItemId = item.id;
                    _catalogVariantId = onlyVariant?.id;
                    _salesUnitCode = _defaultSalesUnitCode(item, onlyVariant);
                    _catalogItemController.text = _itemLabel(item);
                    _catalogVariantController.text = onlyVariant == null ? '' : _variantLabel(onlyVariant);
                    _resetAdditionalHandlingInputs();
                  });
                  if (onlyVariant == null && variants.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _catalogVariantFocusNode.requestFocus();
                    });
                  }
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: _clearOptionSelection,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedItem != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionPreviewPlaceholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchableOptionField<CalculatorCatalogVariantOption>(
                      label: variantsForItem.isEmpty ? 'Catalog variant / SKU (none available)' : 'Catalog variant / SKU',
                      hintText: variantsForItem.isEmpty ? 'This catalog item has no SKU variants' : 'Type to search SKU / color / length / article no',
                      controller: _catalogVariantController,
                      focusNode: _catalogVariantFocusNode,
                      enabled: variantsForItem.isNotEmpty,
                      options: variantsForItem,
                      displayStringForOption: _variantLabel,
                      searchStringForOption: _variantSearchText,
                      onSelected: (variant) => setState(() {
                        _catalogVariantId = variant.id;
                        _salesUnitCode = _defaultSalesUnitCode(selectedItem, variant);
                        _catalogVariantController.text = _variantLabel(variant);
                      }),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _skuCountLabel(variantsForItem),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _optionAddPanel(
                      additionalHandlingOptions: additionalHandlingOptions,
                      canAdd: canAdd,
                      addRequiresVariant: addRequiresVariant,
                      selectedItem: selectedItem,
                      selectedVariant: selectedVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _SelectedOptionsTable(
          contextData: widget.contextData,
          options: widget.draft.options,
          optionDiagnostics: widget.optionDiagnostics,
          onRemove: widget.notifier.removeOptionAt,
        ),
      ],
    );
  }

  List<CalculatorCatalogItemOption> _itemsForSelectedType() {
    return widget.contextData.optionCatalogItems.where((item) {
      if (_itemTypeCode != null && item.itemTypeCode != _itemTypeCode) return false;
      return true;
    }).toList(growable: false);
  }

  List<CalculatorCatalogVariantOption> _allVariantsForSelectedItem() {
    final itemId = _catalogItemId;
    if (itemId == null) return const [];
    return _variantsForItem(itemId);
  }

  List<CalculatorCatalogVariantOption> _variantsForItem(String itemId) {
    return widget.contextData.optionCatalogVariants
        .where((entry) => entry.catalogItemId == itemId)
        .toList(growable: false);
  }

  CalculatorCatalogItemOption? _findItem(String? id) {
    if (id == null) return null;
    return widget.contextData.optionCatalogItems.where((entry) => entry.id == id).cast<CalculatorCatalogItemOption?>().firstOrNull;
  }

  CalculatorCatalogVariantOption? _findVariant(String? id) {
    if (id == null) return null;
    return widget.contextData.optionCatalogVariants.where((entry) => entry.id == id).cast<CalculatorCatalogVariantOption?>().firstOrNull;
  }

  String _itemLabel(CalculatorCatalogItemOption item) {
    return [
      if (item.baseCode.isNotEmpty) item.baseCode,
      if (item.profileNo != null && item.profileNo!.isNotEmpty) item.profileNo,
      item.name,
    ].whereType<String>().where((entry) => entry.isNotEmpty).join(' · ');
  }

  String _itemSearchText(CalculatorCatalogItemOption item) {
    final variantText = widget.contextData.optionCatalogVariants
        .where((variant) => variant.catalogItemId == item.id)
        .map(_variantLabel)
        .join(' ');
    return '${_itemLabel(item)} ${item.shortName ?? ''} ${item.itemTypeCode} $variantText';
  }

  String _variantLabel(CalculatorCatalogVariantOption variant) {
    final primaryCode = _variantPrimaryCode(variant) ?? variant.id;
    final color = _firstNonEmpty([variant.colorName, variant.colorCode]);
    final length = _formatLengthMm(variant.lengthMm);

    return _joinDistinctTextParts([
      primaryCode,
      if (!_containsNormalized(primaryCode, color)) color,
      if (!_containsNormalized(primaryCode, length)) length,
    ]);
  }

  String _variantSearchText(CalculatorCatalogVariantOption variant) {
    return _joinDistinctTextParts([
      _variantLabel(variant),
      variant.profileNo,
      variant.variantSku,
      variant.articleNo,
      variant.colorName,
      variant.colorCode,
      _formatLengthMm(variant.lengthMm),
      variant.glassTypeCode,
      variant.coatingTypeCode,
      variant.systemCode,
      variant.systemName,
    ]);
  }

  String? _variantPrimaryCode(CalculatorCatalogVariantOption variant) {
    return _firstNonEmpty([variant.variantSku, variant.articleNo]);
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final raw in values) {
      final value = raw?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _containsNormalized(String? haystack, String? needle) {
    final normalizedHaystack = _normalize(haystack ?? '');
    final normalizedNeedle = _normalize(needle ?? '');
    if (normalizedHaystack.isEmpty || normalizedNeedle.isEmpty) return false;
    return normalizedHaystack.contains(normalizedNeedle);
  }

  String _skuCountLabel(List<CalculatorCatalogVariantOption> variants) {
    final count = variants.length;
    if (count == 0) return '0 SKUs found';
    if (count == 1) return '1 SKU found';
    return '$count SKUs found';
  }

  TextEditingController _handlingQuantityController(CalculatorAdditionalHandlingOption option) {
    return _additionalHandlingControllers.putIfAbsent(
      option.catalogItemId,
      () => TextEditingController(text: '1'),
    );
  }

  Widget _optionAddPanel({
    required List<CalculatorAdditionalHandlingOption> additionalHandlingOptions,
    required bool canAdd,
    required bool addRequiresVariant,
    required CalculatorCatalogItemOption? selectedItem,
    required CalculatorCatalogVariantOption? selectedVariant,
  }) {
    final unselectedHandlings = _unselectedAdditionalHandlingOptions(additionalHandlingOptions);
    final pendingHandlingId = _effectivePendingAdditionalHandlingId(unselectedHandlings);
    final selectedHandlings = additionalHandlingOptions
        .where((entry) => _enabledAdditionalHandlingIds.contains(entry.catalogItemId))
        .toList(growable: false);
    final canUseHandlingInput = _additionalHandlingInputEnabled && unselectedHandlings.isNotEmpty;
    final salesUnitOptions = _salesUnitOptions(selectedItem, selectedVariant);
    final salesUnitCode = _effectiveSalesUnitCode(selectedItem, selectedVariant);
    final packageInfoLabel = _packageInfoLabel(selectedItem, selectedVariant);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _optionQuantityAndAddRow(
            canAdd: canAdd,
            addRequiresVariant: addRequiresVariant,
            selectedVariant: selectedVariant,
            salesUnitOptions: salesUnitOptions,
            salesUnitCode: salesUnitCode,
            packageInfoLabel: packageInfoLabel,
          ),
          if (additionalHandlingOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              unselectedHandlings.isEmpty && selectedHandlings.isEmpty
                  ? 'No additional handling available for this option.'
                  : 'Add handling only when this option needs extra production work.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            _additionalHandlingInputRow(
              unselectedHandlings: unselectedHandlings,
              pendingHandlingId: pendingHandlingId,
              inputEnabled: canUseHandlingInput,
              allHandlingOptions: additionalHandlingOptions,
            ),
          ],
          if (selectedHandlings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _selectedAdditionalHandlingFrame(selectedHandlings),
          ],
        ],
      ),
    );
  }

  Widget _optionQuantityAndAddRow({
    required bool canAdd,
    required bool addRequiresVariant,
    required CalculatorCatalogVariantOption? selectedVariant,
    required List<String> salesUnitOptions,
    required String salesUnitCode,
    required String? packageInfoLabel,
  }) {
    final normalizedSalesUnit = salesUnitOptions.contains(salesUnitCode)
        ? salesUnitCode
        : (salesUnitOptions.isEmpty ? 'piece' : salesUnitOptions.first);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Qty',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 132,
          child: DropdownButtonFormField<String>(
            key: ValueKey('sales-unit-$normalizedSalesUnit-${salesUnitOptions.join('|')}'),
            initialValue: normalizedSalesUnit,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Unit',
              isDense: true,
            ),
            items: [
              for (final unit in salesUnitOptions)
                DropdownMenuItem(
                  value: unit,
                  child: Text(_formatUnitLabel(unit), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: salesUnitOptions.length > 1 ? (value) => setState(() => _salesUnitCode = value) : null,
          ),
        ),
        if (packageInfoLabel != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              packageInfoLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        if (addRequiresVariant && selectedVariant == null)
          Expanded(
            child: Text(
              'Select concrete SKU before adding.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          )
        else
          const Spacer(),
        FilledButton.icon(
          onPressed: canAdd ? _addSelectedOption : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(150, 42),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            textStyle: Theme.of(context).textTheme.titleSmall,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add option'),
        ),
      ],
    );
  }

  Widget _additionalHandlingInputRow({
    required List<CalculatorAdditionalHandlingOption> unselectedHandlings,
    required String? pendingHandlingId,
    required bool inputEnabled,
    required List<CalculatorAdditionalHandlingOption> allHandlingOptions,
  }) {
    final hasChoices = unselectedHandlings.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 34,
          child: Checkbox(
            value: _additionalHandlingInputEnabled && hasChoices,
            visualDensity: VisualDensity.compact,
            onChanged: hasChoices ? _toggleAdditionalHandlingInput : null,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('additional-handling-$pendingHandlingId-${unselectedHandlings.length}-$_additionalHandlingInputEnabled'),
            initialValue: pendingHandlingId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Possible handling',
              isDense: true,
            ),
            items: [
              for (final option in unselectedHandlings)
                DropdownMenuItem(
                  value: option.catalogItemId,
                  child: Text(
                    '${option.displayName} · max ${_formatInputQuantity(option.maxQuantity)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: inputEnabled ? (value) => setState(() => _pendingAdditionalHandlingId = value) : null,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: inputEnabled ? () => _addPendingAdditionalHandling(allHandlingOptions) : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(150, 42),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Add handling'),
        ),
      ],
    );
  }

  void _toggleAdditionalHandlingInput(bool? enabled) {
    setState(() {
      _additionalHandlingInputEnabled = enabled ?? false;
      if (!_additionalHandlingInputEnabled) return;
      final unselected = _unselectedAdditionalHandlingOptions(
        _catalogItemId == null
            ? const <CalculatorAdditionalHandlingOption>[]
            : widget.contextData.additionalHandlingByParentItemId[_catalogItemId!] ?? const <CalculatorAdditionalHandlingOption>[],
      );
      _pendingAdditionalHandlingId = _effectivePendingAdditionalHandlingId(unselected);
    });
  }

  List<String> _salesUnitOptions(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
  ) {
    final roundingCode = _normalizeText(variant?.saleRoundingCode) ?? _normalizeText(item?.saleRoundingCode);
    final packageUnit = _normalizeUnitCode(variant?.packageUnitCode) ?? _normalizeUnitCode(item?.packageUnitCode);
    final explicit = variant != null && variant.allowedSalesUnitCodes.isNotEmpty
        ? variant.allowedSalesUnitCodes
        : item?.allowedSalesUnitCodes ?? const <String>[];

    final candidates = <String?>[
      if (roundingCode == 'package_only' && packageUnit != null) packageUnit,
      if (roundingCode != 'package_only') ...explicit,
      variant?.defaultSalesUnitCode,
      item?.defaultSalesUnitCode,
      item?.measureTypeCode,
      variant?.packageUnitCode,
      item?.packageUnitCode,
      variant?.packageContentUnitCode,
      item?.packageContentUnitCode,
      'piece',
    ];

    final result = <String>[];
    for (final raw in candidates) {
      final unit = _normalizeUnitCode(raw);
      if (unit == null || result.contains(unit)) continue;
      result.add(unit);
      if (roundingCode == 'package_only') break;
    }
    return result.isEmpty ? const ['piece'] : result;
  }

  String _effectiveSalesUnitCode(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
  ) {
    final options = _salesUnitOptions(item, variant);
    final selected = _normalizeUnitCode(_salesUnitCode);
    if (selected != null && options.contains(selected)) return selected;
    return _defaultSalesUnitCode(item, variant);
  }

  String _defaultSalesUnitCode(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
  ) {
    final options = _salesUnitOptions(item, variant);
    final candidates = <String?>[
      variant?.defaultSalesUnitCode,
      item?.defaultSalesUnitCode,
      item?.measureTypeCode,
      variant?.packageUnitCode,
      item?.packageUnitCode,
      variant?.packageContentUnitCode,
      item?.packageContentUnitCode,
    ];
    for (final raw in candidates) {
      final unit = _normalizeUnitCode(raw);
      if (unit != null && options.contains(unit)) return unit;
    }
    return options.first;
  }

  String? _packageInfoLabel(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
  ) {
    final packageUnit = _normalizeUnitCode(variant?.packageUnitCode) ?? _normalizeUnitCode(item?.packageUnitCode);
    final contentUnit = _normalizeUnitCode(variant?.packageContentUnitCode) ?? _normalizeUnitCode(item?.packageContentUnitCode);
    final contentQty = variant?.packageContentQty ?? item?.packageContentQty;
    final roundingCode = _normalizeText(variant?.saleRoundingCode) ?? _normalizeText(item?.saleRoundingCode);
    if (packageUnit == null || contentUnit == null || contentQty == null || contentQty <= 0) return null;
    final roundingLabel = switch (roundingCode) {
      'exact' => 'exact',
      'ceil_package' => 'round to package',
      'package_only' => 'package only',
      _ => null,
    };
    final base = '1 ${_formatUnitLabel(packageUnit)} = ${_formatInputQuantity(contentQty)} ${_formatUnitLabel(contentUnit)}';
    return roundingLabel == null ? base : '$base · $roundingLabel';
  }

  String? _normalizeText(String? value) {
    final text = value?.trim().toLowerCase();
    return text == null || text.isEmpty ? null : text;
  }

  String? _normalizeUnitCode(String? value) {
    final text = _normalizeText(value)?.replaceAll(RegExp(r'\s+'), '_');
    if (text == null) return null;
    switch (text) {
      case 'm':
      case 'meter':
      case 'meters':
      case 'metre':
      case 'metres':
        return 'meter';
      case 'karton':
      case 'carton':
      case 'box':
      case 'package':
        return 'carton';
      case 'rolle':
      case 'roll':
        return 'roll';
      case 'stk':
      case 'stk.':
      case 'st':
      case 'pc':
      case 'pcs':
      case 'piece':
      case 'pieces':
        return 'piece';
      case 'm2':
      case 'sqm':
      case 'square_meter':
      case 'square_meters':
        return 'sqm';
      case 'prozent':
      case 'percent':
      case '%':
        return 'percent';
      default:
        return text;
    }
  }

  List<CalculatorAdditionalHandlingOption> _unselectedAdditionalHandlingOptions(List<CalculatorAdditionalHandlingOption> options) {
    return options
        .where((entry) => !_enabledAdditionalHandlingIds.contains(entry.catalogItemId))
        .toList(growable: false);
  }

  String? _effectivePendingAdditionalHandlingId(List<CalculatorAdditionalHandlingOption> unselectedOptions) {
    final pendingId = _pendingAdditionalHandlingId;
    if (pendingId != null && unselectedOptions.any((entry) => entry.catalogItemId == pendingId)) {
      return pendingId;
    }
    return unselectedOptions.isEmpty ? null : unselectedOptions.first.catalogItemId;
  }

  void _addPendingAdditionalHandling(List<CalculatorAdditionalHandlingOption> options) {
    final unselected = _unselectedAdditionalHandlingOptions(options);
    if (unselected.isEmpty) return;
    final pendingId = _effectivePendingAdditionalHandlingId(unselected) ?? unselected.first.catalogItemId;
    final option = unselected.firstWhere(
      (entry) => entry.catalogItemId == pendingId,
      orElse: () => unselected.first,
    );

    setState(() {
      _enabledAdditionalHandlingIds.add(option.catalogItemId);
      final controller = _handlingQuantityController(option);
      final currentQuantity = num.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
      if (currentQuantity <= 0) controller.text = '1';
      final nextUnselected = options
          .where((entry) => !_enabledAdditionalHandlingIds.contains(entry.catalogItemId))
          .cast<CalculatorAdditionalHandlingOption?>()
          .firstOrNull;
      //_additionalHandlingInputEnabled = nextUnselected != null;
      _pendingAdditionalHandlingId = nextUnselected?.catalogItemId;
    });
  }

  Widget _selectedAdditionalHandlingFrame(List<CalculatorAdditionalHandlingOption> selectedHandlings) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selected handling',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          for (final option in selectedHandlings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: _handlingQuantityController(option),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Qty',
                        helperText: 'max ${_formatInputQuantity(option.maxQuantity)}',
                      ),
                      onEditingComplete: () => _clampHandlingQuantity(option),
                      onSubmitted: (_) => _clampHandlingQuantity(option),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove handling',
                    onPressed: () => setState(() {
                      _enabledAdditionalHandlingIds.remove(option.catalogItemId);
                      _pendingAdditionalHandlingId ??= option.catalogItemId;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _clampHandlingQuantity(CalculatorAdditionalHandlingOption option) {
    final controller = _handlingQuantityController(option);
    var quantity = num.tryParse(controller.text.replaceAll(',', '.')) ?? 1;
    if (quantity <= 0) quantity = 1;
    if (option.maxQuantity > 0 && quantity > option.maxQuantity) {
      quantity = option.maxQuantity;
    }
    controller.text = _formatInputQuantity(quantity);
  }

  void _resetAdditionalHandlingInputs() {
    _enabledAdditionalHandlingIds.clear();
    _additionalHandlingInputEnabled = false;
    _pendingAdditionalHandlingId = null;
    for (final controller in _additionalHandlingControllers.values) {
      controller.text = '1';
    }
  }

  List<CalculatorSelectedAdditionalHandling> _selectedAdditionalHandlings(String parentItemId) {
    final options = widget.contextData.additionalHandlingByParentItemId[parentItemId] ?? const <CalculatorAdditionalHandlingOption>[];
    final result = <CalculatorSelectedAdditionalHandling>[];
    for (final option in options) {
      if (!_enabledAdditionalHandlingIds.contains(option.catalogItemId)) continue;
      final controller = _handlingQuantityController(option);
      var quantity = num.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
      if (quantity <= 0) continue;
      if (option.maxQuantity > 0 && quantity > option.maxQuantity) {
        quantity = option.maxQuantity;
        controller.text = option.maxQuantity.toString();
      }
      result.add(CalculatorSelectedAdditionalHandling(catalogItemId: option.catalogItemId, quantity: quantity));
    }
    return result;
  }

  void _clearOptionSelection() {
    setState(() {
      _itemTypeCode = null;
      _catalogItemId = null;
      _catalogVariantId = null;
      _salesUnitCode = null;
      _catalogItemController.clear();
      _catalogVariantController.clear();
      _quantityController.text = '1';
      _resetAdditionalHandlingInputs();
    });
  }

  void _addSelectedOption() {
    final itemId = _catalogItemId;
    if (itemId == null) return;
    final quantity = num.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    final item = _findItem(itemId);
    final variant = _findVariant(_catalogVariantId);
    final salesUnitCode = _effectiveSalesUnitCode(item, variant);
    widget.notifier.addCatalogOption(
      catalogItemId: itemId,
      catalogVariantId: _catalogVariantId,
      quantity: quantity,
      salesUnitCode: salesUnitCode,
      additionalHandlings: _selectedAdditionalHandlings(itemId),
    );
    setState(() {
      _catalogVariantId = null;
      _salesUnitCode = _defaultSalesUnitCode(_findItem(itemId), null);
      _catalogVariantController.clear();
      _quantityController.text = '1';
      _resetAdditionalHandlingInputs();
    });
  }
}

class _SectionPreviewPlaceholder extends StatelessWidget {
  const _SectionPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_in_ar_outlined),
          SizedBox(height: 6),
          Text('section\npreview', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SelectedOptionsTable extends StatelessWidget {
  const _SelectedOptionsTable({
    required this.contextData,
    required this.options,
    required this.optionDiagnostics,
    required this.onRemove,
  });

  final CalculatorContext contextData;
  final List<CalculatorSelectedOption> options;
  final List<Map<String, dynamic>> optionDiagnostics;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const _HintCard(
        icon: Icons.tune_outlined,
        title: 'No options selected',
        text: 'The selected base matrix will still calculate the base system price. Additional catalog positions can be added above.',
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _optionTableHeader(context),
            const Divider(height: 1),
            for (var i = 0; i < options.length; i++) ...[
              _selectedOptionRow(context, i),
              if (i < options.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _optionTableHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cell(context, const Text('Profile no'), width: 74, header: true),
          _cell(context, const Text('Name / additional handling'), flex: 5, header: true),
          _cell(context, const Text('Qty'), width: 46, header: true),
          _cell(context, const Text('Unit'), width: 52, header: true),
          _cell(context, const Text('Option info'), width: 132, header: true),
          _cell(context, const Text('Price'), width: 84, header: true),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _selectedOptionRow(BuildContext context, int index) {
    final option = options[index];
    final item = _findItem(option.catalogItemId);
    final variant = _findVariant(option.catalogVariantId);
    final diagnostic = _diagnosticFor(index, option);
    final profileNo = variant?.profileNo ?? item?.profileNo ?? diagnostic?['profile_no'];
    final name = _selectedOptionName(item, variant, option);
    final availableHandlings = item == null
        ? const <CalculatorAdditionalHandlingOption>[]
        : contextData.additionalHandlingByParentItemId[item.id] ?? const <CalculatorAdditionalHandlingOption>[];
    final unitCode = option.salesUnitCode
        ?? diagnostic?['requested_unit_code']?.toString()
        ?? item?.defaultSalesUnitCode
        ?? item?.measureTypeCode
        ?? diagnostic?['unit_code']?.toString()
        ?? 'piece';
    final salesNote = diagnostic?['sales_note']?.toString();
    final optionTextParts = [
      if (variant?.colorName != null) variant!.colorName!,
      if (_formatLengthMm(variant?.lengthMm) != null) _formatLengthMm(variant?.lengthMm),
      if (salesNote != null && salesNote.isNotEmpty) salesNote,
    ].whereType<String>().where((entry) => entry.isNotEmpty).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cell(context, Text('${profileNo ?? '—'}'), width: 74),
          _cell(
            context,
            _SelectedOptionNameCell(
              name: name,
              availableHandlings: availableHandlings,
              selectedHandlings: option.additionalHandlings,
            ),
            flex: 5,
          ),
          _cell(context, Text('${option.quantity}'), width: 46),
          _cell(context, Text(_formatUnitLabel(unitCode)), width: 52),
          _cell(
            context,
            _SelectedOptionInfoCell(optionTextParts: optionTextParts),
            width: 132,
          ),
          _cell(context, _SelectedOptionPriceCell(diagnostic: diagnostic), width: 84),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: 'Remove',
              onPressed: () => onRemove(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    Widget child, {
    double? width,
    int? flex,
    bool header = false,
  }) {
    final textStyle = header ? Theme.of(context).textTheme.labelMedium : Theme.of(context).textTheme.bodySmall;
    final content = DefaultTextStyle.merge(
      style: textStyle,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: child,
      ),
    );
    if (width != null) return SizedBox(width: width, child: content);
    return Expanded(flex: flex ?? 1, child: content);
  }

  String _selectedOptionName(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
    CalculatorSelectedOption option,
  ) {
    final parts = <String?>[
      item?.itemTypeCode,
      item?.name,
      variant?.variantSku,
      if (item == null && variant == null) option.optionCode ?? option.catalogVariantId ?? option.catalogItemId ?? 'Option',
    ];
    return _joinDistinctTextParts(parts);
  }

  Map<String, dynamic>? _diagnosticFor(int index, CalculatorSelectedOption option) {
    for (final row in optionDiagnostics) {
      final rowIndex = _num(row['option_index']).toInt();
      if (rowIndex != index) continue;
      final sameItem = '${row['catalog_item_id'] ?? ''}' == (option.catalogItemId ?? '');
      final sameVariant = '${row['catalog_variant_id'] ?? ''}' == (option.catalogVariantId ?? '');
      if (sameItem && sameVariant) return row;
    }
    return null;
  }

  CalculatorCatalogItemOption? _findItem(String? id) {
    if (id == null) return null;
    return contextData.optionCatalogItems.where((entry) => entry.id == id).cast<CalculatorCatalogItemOption?>().firstOrNull;
  }

  CalculatorCatalogVariantOption? _findVariant(String? id) {
    if (id == null) return null;
    return contextData.optionCatalogVariants.where((entry) => entry.id == id).cast<CalculatorCatalogVariantOption?>().firstOrNull;
  }

}



String _formatInputQuantity(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toString();
}

String _formatUnitLabel(String? rawUnit) {
  final unit = rawUnit?.trim();
  if (unit == null || unit.isEmpty) return 'piece';
  switch (unit.toLowerCase()) {
    case 'm':
    case 'meter':
    case 'meters':
    case 'metre':
    case 'metres':
      return 'm';
    case 'mm':
      return 'mm';
    case 'm2':
    case 'sqm':
    case 'square_meter':
    case 'square_meters':
      return 'm²';
    case 'stk':
    case 'stk.':
    case 'st':
    case 'pc':
    case 'pcs':
    case 'piece':
    case 'pieces':
      return 'Stk';
    case 'carton':
    case 'karton':
    case 'box':
    case 'package':
      return 'Karton';
    case 'roll':
    case 'rolle':
      return 'Rolle';
    case 'prozent':
    case 'percent':
    case '%':
      return '%';
    default:
      return unit;
  }
}

class _SelectedOptionNameCell extends StatelessWidget {
  const _SelectedOptionNameCell({
    required this.name,
    required this.availableHandlings,
    required this.selectedHandlings,
  });

  final String name;
  final List<CalculatorAdditionalHandlingOption> availableHandlings;
  final List<CalculatorSelectedAdditionalHandling> selectedHandlings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          softWrap: true,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        if (selectedHandlings.isNotEmpty) ...[
          const SizedBox(height: 5),
          for (final entry in selectedHandlings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_handlingLabel(entry)} × ${_formatInputQuantity(entry.quantity)}',
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _handlingLabel(CalculatorSelectedAdditionalHandling entry) {
    for (final option in availableHandlings) {
      if (option.catalogItemId == entry.catalogItemId) return option.displayName;
    }
    return entry.catalogItemId;
  }
}

class _SelectedOptionInfoCell extends StatelessWidget {
  const _SelectedOptionInfoCell({required this.optionTextParts});

  final List<String> optionTextParts;

  @override
  Widget build(BuildContext context) {
    if (optionTextParts.isEmpty) return const Text('—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final text in optionTextParts)
          Text(
            text,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _SelectedOptionPriceCell extends StatelessWidget {
  const _SelectedOptionPriceCell({required this.diagnostic});

  final Map<String, dynamic>? diagnostic;

  @override
  Widget build(BuildContext context) {
    final row = diagnostic;
    if (row == null) {
      return const Tooltip(
        message: 'Run calculation to resolve option price.',
        child: Icon(Icons.help_outline, size: 18),
      );
    }

    final warning = row['warning'];
    final priceFound = row['price_found'] == true;
    final amount = row['amount'];
    if (!priceFound) {
      return Tooltip(
        message: warning == null ? 'No price found for this option.' : '$warning',
        child: Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error, size: 18),
      );
    }

    final priceText = amount == null ? 'OK' : _moneyFormat.format(_num(amount));
    if (warning == null || '$warning'.isEmpty) {
      return Text(priceText);
    }

    return Tooltip(
      message: '$warning',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(priceText),
          const SizedBox(width: 4),
          Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error, size: 16),
        ],
      ),
    );
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
          text: 'Click Calculate in the bottom right of this data card. The right panel will show price, options diagnostics, BOM preview, price sources and trace.',
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.resultAsync,
    required this.draft,
    required this.onSaveQuote,
    required this.isSavingQuote,
    this.loadedQuote,
    this.savedQuote,
  });

  final AsyncValue<CalculatorResult?> resultAsync;
  final CalculatorDraft draft;
  final LoadedQuote? loadedQuote;
  final VoidCallback onSaveQuote;
  final bool isSavingQuote;
  final SavedQuote? savedQuote;

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _HintCard(
                      icon: Icons.calculate_outlined,
                      title: 'No calculation yet',
                      text: 'Fill the steps and run Calculate. Internal result will include sources, options diagnostics, BOM and trace.',
                    ),
                  ),
                ),
                const Divider(height: 1),
                _ResultActions(
                  canSaveQuote: false,
                  canSaveAsOption: false,
                  isSavingQuote: isSavingQuote,
                  savedQuote: savedQuote,
                  onSaveQuote: onSaveQuote,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DefaultTabController(
                  length: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                        child: _PriceHeader(result: result, loadedQuote: loadedQuote),
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
                            _BomTab(result: result),
                            _ScrollableResultCard(child: JsonViewCard(title: 'Price sources', data: result.sources)),
                            _SimpleRowsTab(rows: result.trace, empty: 'No trace.'),
                            _ScrollableResultCard(child: JsonViewCard(title: 'Raw calculation result', data: result.raw)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _ResultActions(
                canSaveQuote: true,
                canSaveAsOption: draft.canSaveAsOptionFor(loadedQuote),
                isSavingQuote: isSavingQuote,
                savedQuote: savedQuote,
                onSaveQuote: onSaveQuote,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.canSaveQuote,
    required this.canSaveAsOption,
    required this.isSavingQuote,
    required this.savedQuote,
    required this.onSaveQuote,
  });

  final bool canSaveQuote;
  final bool canSaveAsOption;
  final bool isSavingQuote;
  final SavedQuote? savedQuote;
  final VoidCallback onSaveQuote;

  @override
  Widget build(BuildContext context) {
    final hint = canSaveAsOption ? 'As New / As Option' : 'As New';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (savedQuote != null)
            Expanded(
              child: Text(
                'Saved quote: ${savedQuote!.quoteNo}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            Expanded(
              child: Text(
                hint,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          OutlinedButton.icon(
            onPressed: canSaveQuote && !isSavingQuote ? onSaveQuote : null,
            icon: isSavingQuote
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('save quote'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.description_outlined),
            label: const Text('create offer'),
          ),
        ],
      ),
    );
  }
}

class _SaveQuoteModeDialog extends StatelessWidget {
  const _SaveQuoteModeDialog({
    required this.loadedQuote,
    required this.canSaveAsOption,
  });

  final LoadedQuote? loadedQuote;
  final bool canSaveAsOption;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save quote'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('As New'),
              subtitle: const Text('Save under the next quote number for the current buyer/seller context.'),
              onTap: () => Navigator.of(context).pop(SaveQuoteMode.asNew),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: canSaveAsOption,
              leading: const Icon(Icons.call_split_outlined),
              title: const Text('As Option'),
              subtitle: Text(
                loadedQuote == null
                    ? 'Load an existing quote first.'
                    : canSaveAsOption
                        ? 'Save as ${loadedQuote!.quoteNo} - Option #...'
                        : 'Available only if input changed and buyer/ship-to stayed the same.',
              ),
              onTap: canSaveAsOption ? () => Navigator.of(context).pop(SaveQuoteMode.asOption) : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({
    required this.result,
    required this.loadedQuote,
  });

  final CalculatorResult result;
  final LoadedQuote? loadedQuote;

  @override
  Widget build(BuildContext context) {
    final net = _num(result.price['net']);
    final gross = _num(result.price['gross']);
    final margin = result.internalPrice['margin'];
    final quoteTitle = loadedQuote?.quoteNo ?? 'new quote';
    final missingOptionPriceCount = result.optionDiagnostics
        .where((row) => row['price_found'] == false)
        .length;
    final nonOptionWarnings = result.warnings.where((warning) {
      final code = '${warning['code'] ?? ''}';
      return !code.startsWith('option_');
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quoteTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
            _MetricChip(label: 'Options', value: '${result.optionDiagnostics.length}'),
            _MetricChip(label: 'Currency', value: result.currency),
          ],
        ),
        if (missingOptionPriceCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '⚠ $missingOptionPriceCount selected option(s) have no configured price. See Options tab.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (nonOptionWarnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final warning in nonOptionWarnings.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '⚠ ${warning['message'] ?? warning['code']}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
    if (result.visibleLines.isEmpty) return const Center(child: Text('No lines.'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: result.visibleLines.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final line = result.visibleLines[index];
        final unitPrice = _num(line['unitPrice']);
        final note = '${line['note'] ?? ''}'.trim();
        final subtitleParts = <String>[
          'Qty ${line['quantity'] ?? 1} ${_formatUnitLabel('${line['unit'] ?? ''}')}',
          if (unitPrice > 0) '${_moneyFormat.format(unitPrice)} / ${_formatUnitLabel('${line['unit'] ?? ''}')}',
          if (note.isNotEmpty) note,
        ];
        return ListTile(
          title: Text('${line['label'] ?? 'Line'}'),
          subtitle: Text(subtitleParts.join(' · ')),
          trailing: Text(_moneyFormat.format(_num(line['amount']))),
        );
      },
    );
  }
}

class _BomTab extends StatelessWidget {
  const _BomTab({required this.result});

  final CalculatorResult result;

  @override
  Widget build(BuildContext context) {
    final rows = result.bom;
    if (rows.isEmpty) return const Center(child: Text('No BOM lines yet.'));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        return ListTile(
          dense: true,
          title: Text('${row['name'] ?? row['article_no'] ?? 'BOM line'}'),
          subtitle: Text('Article: ${row['article_no'] ?? '—'} · Qty: ${row['quantity'] ?? 1} ${row['unit_code'] ?? ''}'),
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

class _SearchableOptionField<T extends Object> extends StatefulWidget {
  const _SearchableOptionField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.displayStringForOption,
    required this.onSelected,
    this.searchStringForOption,
    this.hintText,
    this.enabled = true,
  });

  final String label;
  final String? hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<T> options;
  final String Function(T option) displayStringForOption;
  final String Function(T option)? searchStringForOption;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  State<_SearchableOptionField<T>> createState() => _SearchableOptionFieldState<T>();
}

class _SearchableOptionFieldState<T extends Object> extends State<_SearchableOptionField<T>> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _SearchableOptionField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleInputChanged);
      widget.controller.addListener(_handleInputChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }

    if (!widget.enabled || widget.options.isEmpty) {
      _hideOverlay();
      return;
    }
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusNode.hasFocus) _showOrUpdateOverlay();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleInputChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    _hideOverlay();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!widget.focusNode.hasFocus) return;
    _showOrUpdateOverlay();
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _showOrUpdateOverlay();
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted || widget.focusNode.hasFocus) return;
      _hideOverlay();
    });
  }

  List<T> _filteredOptions() {
    if (!widget.enabled) return <T>[];
    final query = _normalize(widget.controller.text);
    return widget.options.where((option) {
      if (query.isEmpty) return true;
      final searchable = widget.searchStringForOption?.call(option) ?? widget.displayStringForOption(option);
      return _normalize(searchable).contains(query);
    }).take(250).toList(growable: false);
  }

  void _showOrUpdateOverlay() {
    if (!widget.enabled || !mounted) {
      _hideOverlay();
      return;
    }

    final rows = _filteredOptions();
    if (rows.isEmpty) {
      _hideOverlay();
      return;
    }

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: (_) => _buildOverlay());
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay() {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 520.0;
    final rows = _filteredOptions();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 260,
                minWidth: width,
                maxWidth: width,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = rows[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      widget.displayStringForOption(option),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      widget.controller.text = widget.displayStringForOption(option);
                      widget.onSelected(option);
                      _hideOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Show list',
            onPressed: widget.enabled
                ? () {
                    widget.focusNode.requestFocus();
                    widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
                    _showOrUpdateOverlay();
                  }
                : null,
            icon: const Icon(Icons.expand_more),
          ),
        ),
        onTap: () {
          widget.focusNode.requestFocus();
          widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
          _showOrUpdateOverlay();
        },
      ),
    );
  }
}

class _ScrollableDataTable extends StatefulWidget {
  const _ScrollableDataTable({
    required this.dataTable,
  });

  final DataTable dataTable;

  @override
  State<_ScrollableDataTable> createState() => _ScrollableDataTableState();
}

class _ScrollableDataTableState extends State<_ScrollableDataTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final table = Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: widget.dataTable,
      ),
    );

    final scrollable = Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: table,
      ),
    );

    return scrollable;
  }
}

class _ScrollableResultCard extends StatefulWidget {
  const _ScrollableResultCard({required this.child});

  final Widget child;

  @override
  State<_ScrollableResultCard> createState() => _ScrollableResultCardState();
}

class _ScrollableResultCardState extends State<_ScrollableResultCard> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.all(12),
        child: widget.child,
      ),
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

class _RoofModelStepState {
  const _RoofModelStepState({
    required this.required,
    required this.options,
    required this.familyModelsCount,
  });

  final bool required;
  final List<CalculatorOption> options;
  final int familyModelsCount;

  bool isSelected(String? modelCode) {
    if (!required) return true;
    if (modelCode == null || modelCode.isEmpty) return false;
    return options.any((option) => option.code == modelCode);
  }
}

_RoofModelStepState _roofModelStateFor(
  CalculatorContext calculatorContext,
  CalculatorDraft draft,
  CalculatorTemplateOption? selectedTemplate,
) {
  final familyId = selectedTemplate?.productFamilyId ?? draft.productFamilyId;
  if (familyId == null || familyId.isEmpty) {
    return const _RoofModelStepState(
      required: false,
      options: [],
      familyModelsCount: 0,
    );
  }

  final allModels = calculatorContext.references['roof_models'] ?? const <CalculatorOption>[];
  final familyModels = allModels.where((option) {
    return _roofModelString(option.raw['product_family_id']) == familyId;
  }).toList(growable: false);

  if (familyModels.isEmpty) {
    return const _RoofModelStepState(
      required: false,
      options: [],
      familyModelsCount: 0,
    );
  }

  final templateId = draft.templateId;
  if (templateId == null || templateId.isEmpty) {
    return _RoofModelStepState(
      required: true,
      options: const [],
      familyModelsCount: familyModels.length,
    );
  }

  final templateModels = familyModels.where((option) {
    final optionTemplateId = _roofModelString(
      option.raw['configurator_template_id'] ?? option.raw['template_id'],
    );

    return optionTemplateId == templateId;
  }).toList(growable: false);

  return _RoofModelStepState(
    required: true,
    options: templateModels,
    familyModelsCount: familyModels.length,
  );
}

String? _roofModelString(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
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

String _joinDistinctTextParts(Iterable<String?> values) {
  final result = <String>[];
  final normalized = <String>{};
  for (final raw in values) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) continue;
    final key = _normalize(value);
    if (key.isEmpty || normalized.contains(key)) continue;
    normalized.add(key);
    result.add(value);
  }
  return result.isEmpty ? 'Option' : result.join(' · ');
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]+'), ' ').trim();
}

String? _formatLengthMm(int? value) {
  if (value == null || value <= 1) return null;
  return '$value mm';
}

num _num(dynamic value) {
  if (value is num) return value;
  if (value == null) return 0;
  return num.tryParse('$value') ?? 0;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

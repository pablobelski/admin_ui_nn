import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/http/admin_resource_repository.dart';
import '../../../core/http/api_client.dart';
import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../../../core/ui/json_view_card.dart';
import '../../../core/ui/media_file_actions.dart';
import '../../../core/ui/media_preview_dialog.dart';
import '../data/calculator_models.dart';
import '../data/calculator_repository.dart';
import 'calculator_providers.dart';

const _steps = <_StepDefinition>[
  _StepDefinition('product', 'Product', Icons.inventory_2_outlined),
  _StepDefinition('template', 'Template', Icons.account_tree_outlined),
  _StepDefinition('model', 'Model', Icons.view_in_ar_outlined),
  _StepDefinition('dimensions', 'Dimensions', Icons.straighten_outlined),
  _StepDefinition('covering', 'Covering', Icons.layers_outlined),
  _StepDefinition('color', 'Color', Icons.palette_outlined),
  _StepDefinition('set_contents', 'Set contents', Icons.view_list_outlined),
  _StepDefinition('accessory', 'Accessory', Icons.build_outlined),
  _StepDefinition('options', 'Options', Icons.tune_outlined),
  _StepDefinition('delivery', 'Delivery', Icons.local_shipping_outlined),
  _StepDefinition('summary', 'Summary', Icons.summarize_outlined),
];

final _moneyFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');
const _customRalOptionCode = '__custom_ral__';

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
                            onPrint: () => _showPrintDialog(context),
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
                            onPrint: () => _showPrintDialog(context),
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

  Future<void> _showPrintDialog(BuildContext context) async {
    final loadedQuote = ref.read(loadedQuoteProvider);
    final quoteId = loadedQuote?.id ?? _savedQuote?.id;
    if (quoteId == null || quoteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the quote before printing.')),
      );
      return;
    }

    final repository = ref.read(calculatorRepositoryProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => _PrintDialog(
        quoteId: quoteId,
        repository: repository,
      ),
    );
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
                'Internal step-by-step configurator: Product → Template → Model → Dimensions → Covering → Color → Set contents → Options → Delivery → Summary.',
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


  Future<void> _confirmAndReloadSetContents(
    BuildContext context,
    WidgetRef ref,
    CalculatorDraftNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update set contents?'),
        content: const Text(
          'The component set will be loaded again from the linked rule-set row. Current row quantities and profile lengths will be replaced by the initial component defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final preview = await ref.read(calculatorRepositoryProvider).fetchSetContents(
            draft.copyWith(setContents: const []),
          );
      notifier.setSetContentsFromDefaults(preview.tabs);
      ref.read(calculatorSetContentsRefreshTickProvider.notifier).bump();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set contents updated from defaults.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set contents update failed: $error')),
      );
    }
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
        return _ColorStep(
          contextData: calculatorContext,
          draft: draft,
          notifier: notifier,
        );
      case 'set_contents':
        final preview = ref.watch(calculatorSetContentsProvider);
        final result = ref.watch(calculatorResultProvider).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );
        return _SetContentsStep(
          contextData: calculatorContext,
          draft: draft,
          notifier: notifier,
          preview: preview,
          diagnostics: result?.setContentDiagnostics ?? const [],
          onUpdateFromDefaults: () => _confirmAndReloadSetContents(context, ref, notifier),
        );
      case 'accessory':
        final result = ref.watch(calculatorResultProvider).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );
        return _AccessoryStep(
          contextData: calculatorContext,
          draft: draft,
          notifier: notifier,
          diagnostics: result?.setContentDiagnostics ?? const [],
          onFastenersPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fasteners import will be connected in the next iteration.')),
            );
          },
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
          mediaRepository: ref.read(resourceRepositoryProvider),
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
  late final TextEditingController _blockCount;

  @override
  void initState() {
    super.initState();
    _width = TextEditingController(text: widget.draft.widthMm?.toString() ?? '');
    _depth = TextEditingController(text: widget.draft.depthMm?.toString() ?? '');
    _height = TextEditingController(text: widget.draft.heightMm?.toString() ?? '');
    _blockCount = TextEditingController(text: _setContentBlockCount(widget.draft).toString());
  }

  @override
  void didUpdateWidget(covariant _DimensionsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_width, widget.draft.widthMm);
    _sync(_depth, widget.draft.depthMm);
    _sync(_height, widget.draft.heightMm);
    _sync(_blockCount, _setContentBlockCount(widget.draft));
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
    _blockCount.dispose();
    super.dispose();
  }

  int _setContentBlockCount(CalculatorDraft draft) {
    return draft.setContents.isEmpty ? 1 : draft.setContents.length;
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
        const SizedBox(height: 24),
        _SetContentBlockDimensionsEditor(
          draft: widget.draft,
          blockCountController: _blockCount,
          onBlockCountChanged: (value) {
            final count = int.tryParse(value.trim());
            if (count == null) return;
            widget.notifier.setSetContentBlockCount(count);
          },
          onIncrementBlockCount: widget.notifier.incrementSetContentBlockCount,
          onRemoveBlock: widget.notifier.removeSetContentTab,
          onBlockGeometryChanged: widget.notifier.updateSetContentBlockGeometry,
        ),
        const SizedBox(height: 20),
        const _HintCard(
          icon: Icons.grid_on_outlined,
          title: 'Matrix-aware matching',
          text: 'For roof_matrix: width + depth. For height_width_grid: width + height. Set Content blocks can be preset here and still added/removed independently in Set contents.',
        ),
      ],
    );
  }
}

class _SetContentBlockDimensionsEditor extends StatelessWidget {
  const _SetContentBlockDimensionsEditor({
    required this.draft,
    required this.blockCountController,
    required this.onBlockCountChanged,
    required this.onIncrementBlockCount,
    required this.onRemoveBlock,
    required this.onBlockGeometryChanged,
  });

  final CalculatorDraft draft;
  final TextEditingController blockCountController;
  final ValueChanged<String> onBlockCountChanged;
  final VoidCallback onIncrementBlockCount;
  final ValueChanged<int> onRemoveBlock;
  final void Function(int tabIndex, String key, String value) onBlockGeometryChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = draft.setContents.isEmpty
        ? const [CalculatorSetContentTab(id: 'part-1', label: 'Block 1', items: [])]
        : draft.setContents;
    final warnings = _warningsFor(tabs);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set Content blocks', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      const Text(
                        'Preset the number and dimensions of geometry blocks. These tabs are used by Set contents, but blocks can still be added or removed there independently.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 210,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: blockCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Blocks',
                            helperText: '1–20',
                          ),
                          onChanged: onBlockCountChanged,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filledTonal(
                          tooltip: 'Add block',
                          onPressed: onIncrementBlockCount,
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < tabs.length; i++) ...[
              _blockRow(context, tabs[i], i),
              if (i < tabs.length - 1) const Divider(height: 20),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HintCard(
                icon: Icons.warning_amber_outlined,
                title: 'Block dimensions need review',
                text: warnings.join('\n'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _blockRow(BuildContext context, CalculatorSetContentTab tab, int index) {
    final canRemove = draft.setContents.length > 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(tab.label.isEmpty ? 'Block ${index + 1}' : tab.label),
          ),
        ),
        const SizedBox(width: 12),
        _dimensionField(
          context,
          tabId: tab.id,
          fieldKey: 'width_mm',
          label: 'Width',
          value: tab.blockWidthMm,
          maxValue: draft.widthMm,
          index: index,
        ),
        const SizedBox(width: 12),
        _dimensionField(
          context,
          tabId: tab.id,
          fieldKey: 'depth_mm',
          label: 'Depth',
          value: tab.blockDepthMm,
          maxValue: draft.depthMm,
          index: index,
        ),
        const SizedBox(width: 12),
        _dimensionField(
          context,
          tabId: tab.id,
          fieldKey: 'height_mm',
          label: 'Height',
          value: tab.blockHeightMm,
          maxValue: draft.heightMm,
          index: index,
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            tooltip: canRemove ? 'Remove block' : 'At least one block is required',
            onPressed: canRemove ? () => onRemoveBlock(index) : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ],
    );
  }

  Widget _dimensionField(
    BuildContext context, {
    required String tabId,
    required String fieldKey,
    required String label,
    required int? value,
    required int? maxValue,
    required int index,
  }) {
    final error = _dimensionError(value, maxValue, label);
    return SizedBox(
      width: 150,
      child: TextFormField(
        key: ValueKey('set-content-block-$tabId-$fieldKey'),
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '$label mm',
          suffixText: 'mm',
          errorText: error,
        ),
        onChanged: (input) => onBlockGeometryChanged(index, fieldKey, input),
      ),
    );
  }

  String? _dimensionError(int? value, int? maxValue, String label) {
    if (value == null || maxValue == null || maxValue <= 0) return null;
    if (value > maxValue) return '>${_formatLengthMm(maxValue)}';
    return null;
  }

  List<String> _warningsFor(List<CalculatorSetContentTab> tabs) {
    final warnings = <String>[];
    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      if (draft.widthMm != null && tab.blockWidthMm != null && tab.blockWidthMm! > draft.widthMm!) {
        warnings.add('${tab.label}: width ${_formatLengthMm(tab.blockWidthMm)} is greater than main width ${_formatLengthMm(draft.widthMm)}.');
      }
      if (draft.depthMm != null && tab.blockDepthMm != null && tab.blockDepthMm! > draft.depthMm!) {
        warnings.add('${tab.label}: depth ${_formatLengthMm(tab.blockDepthMm)} is greater than main depth ${_formatLengthMm(draft.depthMm)}.');
      }
      if (draft.heightMm != null && tab.blockHeightMm != null && tab.blockHeightMm! > draft.heightMm!) {
        warnings.add('${tab.label}: height ${_formatLengthMm(tab.blockHeightMm)} is greater than main height ${_formatLengthMm(draft.heightMm)}.');
      }
    }

    final widthValues = tabs.map((tab) => tab.blockWidthMm).whereType<int>().toList(growable: false);
    if (draft.widthMm != null && widthValues.length > 1) {
      final sum = widthValues.fold<int>(0, (total, value) => total + value);
      if (sum > draft.widthMm!) {
        warnings.add('Sum of block widths ${_formatLengthMm(sum)} is greater than main width ${_formatLengthMm(draft.widthMm)}.');
      }
    }
    final depthValues = tabs.map((tab) => tab.blockDepthMm).whereType<int>().toList(growable: false);
    if (draft.depthMm != null && depthValues.length > 1) {
      final sum = depthValues.fold<int>(0, (total, value) => total + value);
      if (sum > draft.depthMm!) {
        warnings.add('Sum of block depths ${_formatLengthMm(sum)} is greater than main depth ${_formatLengthMm(draft.depthMm)}.');
      }
    }
    return warnings;
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

    final selectedModel = roofModelState.options
        .where((option) => option.code == draft.modelCode)
        .cast<CalculatorOption?>()
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Model / construction type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Roof models are filtered by both product family and configurator template.'),
        const SizedBox(height: 20),
        _DropdownField(
          label: 'Model / construction type',
          value: draft.modelCode,
          options: roofModelState.options,
          idSelector: (option) => option.code,
          onChanged: onChanged,
          emptyLabel: '— Model not selected —',
        ),
        const SizedBox(height: 16),
        _ModelGeometryPreview(
          modelCode: draft.modelCode,
          modelLabel: selectedModel?.label,
        ),
      ],
    );
  }
}

class _ModelGeometryPreview extends StatelessWidget {
  const _ModelGeometryPreview({
    required this.modelCode,
    required this.modelLabel,
  });

  final String? modelCode;
  final String? modelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = (modelLabel?.trim().isNotEmpty ?? false)
        ? modelLabel!.trim()
        : ((modelCode?.trim().isNotEmpty ?? false) ? modelCode!.trim() : 'No model selected');
    final hasSelection = modelCode?.trim().isNotEmpty ?? false;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schema_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Geometry preview', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasSelection
                  ? 'Simple generated scheme for $label.'
                  : 'Select a model to show a simple generated scheme.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              width: double.infinity,
              child: CustomPaint(
                painter: _ModelGeometryPreviewPainter(
                  modelCode: modelCode,
                  modelLabel: modelLabel,
                  lineColor: colorScheme.onSurface,
                  mutedLineColor: colorScheme.onSurfaceVariant,
                  accentColor: colorScheme.primary,
                  surfaceColor: colorScheme.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ModelGeometryKind {
  rectangle,
  saddle,
  gable,
  trapezoid,
  withGable,
  custom,
  polygon,
}

class _ModelGeometryPreviewPainter extends CustomPainter {
  const _ModelGeometryPreviewPainter({
    required this.modelCode,
    required this.modelLabel,
    required this.lineColor,
    required this.mutedLineColor,
    required this.accentColor,
    required this.surfaceColor,
  });

  final String? modelCode;
  final String? modelLabel;
  final Color lineColor;
  final Color mutedLineColor;
  final Color accentColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final kind = _modelGeometryKind(modelCode, modelLabel);
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final thinStroke = Paint()
      ..color = mutedLineColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final accentStroke = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = surfaceColor.withValues(alpha: 0.44)
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _ModelGeometryKind.saddle:
        _drawSaddle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.gable:
        _drawGable(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.trapezoid:
        _drawTrapezoid(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.withGable:
        _drawWithGable(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.custom:
        _drawCustom(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.polygon:
        _drawPolygon(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
      case _ModelGeometryKind.rectangle:
        _drawRectangle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
        break;
    }

    _drawMiniTopView(canvas, size, kind, stroke, thinStroke);
  }

  _ModelGeometryKind _modelGeometryKind(String? code, String? label) {
    final value = _normalizeModelText('${code ?? ''} ${label ?? ''}');
    if (value.trim().isEmpty) return _ModelGeometryKind.rectangle;
    if (value.contains('satteldach') || value.contains('sattel')) return _ModelGeometryKind.saddle;
    if (value.contains('giebeldach')) return _ModelGeometryKind.gable;
    if (value.contains('mit giebel')) return _ModelGeometryKind.withGable;
    if (value.contains('trapez')) return _ModelGeometryKind.trapezoid;
    if (value.contains('nach mass') || value.contains('custom') || value.contains('sonder')) return _ModelGeometryKind.custom;
    if (value.contains('vieleck') || value.contains('polygon')) return _ModelGeometryKind.polygon;
    return _ModelGeometryKind.rectangle;
  }

  String _normalizeModelText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  void _drawRectangle(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints.fromSize(size);
    final roof = Path()
      ..moveTo(points.backLeft.dx, points.backLeft.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(points.frontLeft.dx, points.frontLeft.dy)
      ..close();
    canvas.drawPath(roof, fillPaint);
    canvas.drawPath(roof, stroke);
    _drawPerspectiveGrid(canvas, points, thinStroke);
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawSaddle(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints.fromSize(size);
    final backRidge = Offset((points.backLeft.dx + points.backRight.dx) / 2, points.backLeft.dy - size.height * 0.14);
    final frontRidge = Offset((points.frontLeft.dx + points.frontRight.dx) / 2, points.frontLeft.dy - size.height * 0.18);
    final leftPlane = Path()
      ..moveTo(points.backLeft.dx, points.backLeft.dy)
      ..lineTo(backRidge.dx, backRidge.dy)
      ..lineTo(frontRidge.dx, frontRidge.dy)
      ..lineTo(points.frontLeft.dx, points.frontLeft.dy)
      ..close();
    final rightPlane = Path()
      ..moveTo(backRidge.dx, backRidge.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(frontRidge.dx, frontRidge.dy)
      ..close();
    canvas.drawPath(leftPlane, fillPaint);
    canvas.drawPath(rightPlane, fillPaint);
    canvas.drawPath(leftPlane, stroke);
    canvas.drawPath(rightPlane, stroke);
    canvas.drawLine(backRidge, frontRidge, accentStroke);
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      final left = _lerp(points.frontLeft, points.backLeft, t);
      final right = _lerp(points.frontRight, points.backRight, t);
      final ridge = _lerp(frontRidge, backRidge, t);
      canvas.drawLine(left, ridge, thinStroke);
      canvas.drawLine(ridge, right, thinStroke);
    }
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawGable(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints.fromSize(size);
    final top = Offset((points.frontLeft.dx + points.frontRight.dx) / 2, points.frontLeft.dy - size.height * 0.24);
    final backTop = Offset((points.backLeft.dx + points.backRight.dx) / 2, points.backLeft.dy - size.height * 0.20);
    final roof = Path()
      ..moveTo(points.frontLeft.dx, points.frontLeft.dy)
      ..lineTo(top.dx, top.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(backTop.dx, backTop.dy)
      ..lineTo(points.backLeft.dx, points.backLeft.dy)
      ..close();
    canvas.drawPath(roof, fillPaint);
    canvas.drawPath(roof, stroke);
    canvas.drawLine(top, backTop, accentStroke);
    canvas.drawLine(points.frontLeft, points.backLeft, thinStroke);
    canvas.drawLine(points.frontRight, points.backRight, thinStroke);
    canvas.drawLine(points.backLeft, backTop, thinStroke);
    canvas.drawLine(backTop, points.backRight, thinStroke);
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawTrapezoid(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final points = _PerspectivePoints(
      frontLeft: Offset(size.width * 0.26, size.height * 0.36),
      frontRight: Offset(size.width * 0.72, size.height * 0.36),
      backLeft: Offset(size.width * 0.40, size.height * 0.14),
      backRight: Offset(size.width * 0.84, size.height * 0.17),
    );
    final roof = Path()
      ..moveTo(points.backLeft.dx, points.backLeft.dy)
      ..lineTo(points.backRight.dx, points.backRight.dy)
      ..lineTo(points.frontRight.dx, points.frontRight.dy)
      ..lineTo(points.frontLeft.dx, points.frontLeft.dy)
      ..close();
    canvas.drawPath(roof, fillPaint);
    canvas.drawPath(roof, stroke);
    _drawPerspectiveGrid(canvas, points, thinStroke);
    _drawPosts(canvas, size, points, stroke);
    _drawDimensions(canvas, size, points, accentStroke);
  }

  void _drawWithGable(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    _drawRectangle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
    final points = _PerspectivePoints.fromSize(size);
    final peak = Offset((points.backLeft.dx + points.backRight.dx) / 2, points.backLeft.dy - size.height * 0.17);
    canvas.drawLine(points.backLeft, peak, accentStroke);
    canvas.drawLine(peak, points.backRight, accentStroke);
    canvas.drawLine(peak, Offset((points.frontLeft.dx + points.frontRight.dx) / 2, points.frontLeft.dy - size.height * 0.12), thinStroke);
  }

  void _drawCustom(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    _drawRectangle(canvas, size, stroke, thinStroke, accentStroke, fillPaint);
    final rect = Rect.fromLTWH(size.width * 0.38, size.height * 0.36, size.width * 0.22, size.height * 0.18);
    _drawDashedRect(canvas, rect, accentStroke);
    _drawText(canvas, 'nach Maß', Offset(rect.left, rect.bottom + 8), accentColor, 11);
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint thinStroke,
    Paint accentStroke,
    Paint fillPaint,
  ) {
    final polygon = <Offset>[
      Offset(size.width * 0.22, size.height * 0.62),
      Offset(size.width * 0.18, size.height * 0.42),
      Offset(size.width * 0.36, size.height * 0.26),
      Offset(size.width * 0.68, size.height * 0.28),
      Offset(size.width * 0.84, size.height * 0.48),
      Offset(size.width * 0.72, size.height * 0.68),
    ];
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, stroke);
    for (var i = 0; i < polygon.length; i++) {
      canvas.drawLine(polygon[i], polygon[(i + 2) % polygon.length], thinStroke);
    }
    _drawDimensionLine(canvas, polygon[0] + const Offset(0, 28), polygon[5] + const Offset(0, 28), 'Länge', accentStroke);
    _drawDimensionLine(canvas, polygon[4] + const Offset(22, 0), polygon[5] + const Offset(22, 0), 'Tiefe', accentStroke);
  }

  void _drawPerspectiveGrid(Canvas canvas, _PerspectivePoints points, Paint thinStroke) {
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      canvas.drawLine(_lerp(points.frontLeft, points.backLeft, t), _lerp(points.frontRight, points.backRight, t), thinStroke);
    }
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      canvas.drawLine(_lerp(points.frontLeft, points.frontRight, t), _lerp(points.backLeft, points.backRight, t), thinStroke);
    }
  }

  double _postHeight(Size size) => size.height * 0.52;

  void _drawPosts(Canvas canvas, Size size, _PerspectivePoints points, Paint stroke) {
    final height = _postHeight(size);
    for (final point in [points.frontLeft, points.frontRight, points.backLeft, points.backRight]) {
      canvas.drawLine(point, point + Offset(0, height), stroke);
    }
  }

  void _drawDimensions(Canvas canvas, Size size, _PerspectivePoints points, Paint accentStroke) {
    final postHeight = _postHeight(size);
    _drawDimensionLine(
      canvas,
      points.frontLeft + Offset(0, postHeight + 16),
      points.frontRight + Offset(0, postHeight + 16),
      'Länge',
      accentStroke,
    );
    _drawDimensionLine(
      canvas,
      points.frontRight + Offset(20, postHeight + 6),
      points.backRight + Offset(20, postHeight + 6),
      'Tiefe',
      accentStroke,
    );
    _drawDimensionLine(
      canvas,
      points.frontLeft + const Offset(-24, 0),
      points.frontLeft + Offset(-24, postHeight),
      'Höhe',
      accentStroke,
    );
  }

  void _drawDimensionLine(Canvas canvas, Offset start, Offset end, String label, Paint paint) {
    canvas.drawLine(start, end, paint);
    final direction = end - start;
    final length = direction.distance;
    if (length > 0) {
      final unit = direction / length;
      final normal = Offset(-unit.dy, unit.dx);
      canvas.drawLine(start - unit * 5 + normal * 5, start + unit * 5 - normal * 5, paint);
      canvas.drawLine(end - unit * 5 + normal * 5, end + unit * 5 - normal * 5, paint);
    }
    _drawText(canvas, label, _lerp(start, end, 0.5) + const Offset(0, 6), accentColor, 16, isBold: true);
  }

  void _drawMiniTopView(Canvas canvas, Size size, _ModelGeometryKind kind, Paint stroke, Paint thinStroke) {
    final rect = Rect.fromLTWH(8, 8, 86, 42);
    if (kind == _ModelGeometryKind.trapezoid) {
      final path = Path()
        ..moveTo(rect.left + 14, rect.bottom)
        ..lineTo(rect.left + 26, rect.top)
        ..lineTo(rect.right, rect.top + 4)
        ..lineTo(rect.right - 8, rect.bottom)
        ..close();
      canvas.drawPath(path, stroke);
      return;
    }
    if (kind == _ModelGeometryKind.polygon) {
      final path = Path()
        ..moveTo(rect.left + 6, rect.bottom - 8)
        ..lineTo(rect.left + 4, rect.top + 12)
        ..lineTo(rect.left + 22, rect.top)
        ..lineTo(rect.right - 12, rect.top + 2)
        ..lineTo(rect.right, rect.top + 22)
        ..lineTo(rect.right - 18, rect.bottom)
        ..close();
      canvas.drawPath(path, stroke);
      return;
    }
    canvas.drawRect(rect, stroke);
    for (var i = 1; i <= 6; i++) {
      final x = rect.left + rect.width * i / 7;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thinStroke);
    }
    if (kind == _ModelGeometryKind.saddle || kind == _ModelGeometryKind.gable || kind == _ModelGeometryKind.withGable) {
      canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), stroke);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) return;
    final unit = vector / length;
    var drawn = 0.0;
    const dash = 7.0;
    const gap = 5.0;
    while (drawn < length) {
      final next = (drawn + dash).clamp(0, length).toDouble();
      canvas.drawLine(start + unit * drawn, start + unit * next, paint);
      drawn += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool isBold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset - Offset(painter.width / 2, painter.height / 2));
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

  @override
  bool shouldRepaint(covariant _ModelGeometryPreviewPainter oldDelegate) {
    return oldDelegate.modelCode != modelCode ||
        oldDelegate.modelLabel != modelLabel ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedLineColor != mutedLineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

class _PerspectivePoints {
  const _PerspectivePoints({
    required this.frontLeft,
    required this.frontRight,
    required this.backLeft,
    required this.backRight,
  });

  factory _PerspectivePoints.fromSize(Size size) {
    return _PerspectivePoints(
      frontLeft: Offset(size.width * 0.24, size.height * 0.34),
      frontRight: Offset(size.width * 0.72, size.height * 0.34),
      backLeft: Offset(size.width * 0.34, size.height * 0.12),
      backRight: Offset(size.width * 0.82, size.height * 0.12),
    );
  }

  final Offset frontLeft;
  final Offset frontRight;
  final Offset backLeft;
  final Offset backRight;
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

class _ColorStep extends StatefulWidget {
  const _ColorStep({
    required this.contextData,
    required this.draft,
    required this.notifier,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;

  @override
  State<_ColorStep> createState() => _ColorStepState();
}

class _ColorStepState extends State<_ColorStep> {
  late final TextEditingController _customRalController;
  var _customRalMode = false;

  @override
  void initState() {
    super.initState();
    _customRalController = TextEditingController(text: _initialCustomRalCode());
    _customRalMode = _customRalController.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _ColorStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedCode = _normalizeRalCode(widget.draft.colorCode);
    final isStandard = selectedCode != null && _standardColorCodes.contains(selectedCode);
    final nextText = isStandard || selectedCode == null ? '' : selectedCode;
    if (nextText.isNotEmpty && nextText != _customRalController.text) {
      _customRalController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
    if (nextText.isNotEmpty && !_customRalMode) {
      _customRalMode = true;
    }
  }

  @override
  void dispose() {
    _customRalController.dispose();
    super.dispose();
  }

  List<CalculatorOption> get _standardColorOptions => widget.contextData.references['colors'] ?? const [];
  List<CalculatorOption> get _ralColorOptions => widget.contextData.references['ral_colors'] ?? const [];

  Set<String> get _standardColorCodes => _standardColorOptions
      .map((entry) => _normalizeRalCode(entry.code))
      .whereType<String>()
      .toSet();

  String _initialCustomRalCode() {
    final selectedCode = _normalizeRalCode(widget.draft.colorCode);
    if (selectedCode == null || _standardColorCodes.contains(selectedCode)) return '';
    return selectedCode;
  }

  void _setColor(String? value) {
    final normalized = _normalizeRalCode(value);
    widget.notifier.setColor(normalized);
    _syncPaintOption(normalized);
  }

  void _syncPaintOption(String? normalizedColorCode) {
    final paintItem = widget.contextData.customPaintCatalogItem;
    if (paintItem == null) return;

    final paintIndexes = <int>[];
    for (var index = 0; index < widget.draft.options.length; index += 1) {
      if (widget.draft.options[index].catalogItemId == paintItem.id) {
        paintIndexes.add(index);
      }
    }

    final needsPaint = normalizedColorCode != null && !_standardColorCodes.contains(normalizedColorCode);
    if (needsPaint) {
      if (paintIndexes.isEmpty) {
        widget.notifier.addCatalogOption(
          catalogItemId: paintItem.id,
          quantity: 1,
          salesUnitCode: paintItem.defaultSalesUnitCode ?? paintItem.measureTypeCode,
        );
      }
      return;
    }

    for (final index in paintIndexes.reversed) {
      widget.notifier.removeOptionAt(index);
    }
  }

  Color? _colorForCode(String? rawCode) {
    final code = _normalizeRalCode(rawCode);
    if (code == null) return null;

    CalculatorOption? match;
    for (final option in [..._standardColorOptions, ..._ralColorOptions]) {
      if (_normalizeRalCode(option.code) == code) {
        match = option;
        break;
      }
    }

    return _colorFromHex(_stringFromRaw(match?.raw['color_hex'] ?? match?.raw['colorHex'] ?? match?.raw['metadata_json']?['color_hex']));
  }

  String _labelForCode(String code) {
    for (final option in [..._standardColorOptions, ..._ralColorOptions]) {
      if (_normalizeRalCode(option.code) == code) return option.label;
    }
    return 'RAL $code';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCode = _normalizeRalCode(widget.draft.colorCode);
    final customSelected = selectedCode != null && !_standardColorCodes.contains(selectedCode);
    final customMode = _customRalMode || customSelected;
    final dropdownOptions = [
      ..._standardColorOptions,
      const CalculatorOption(id: _customRalOptionCode, code: _customRalOptionCode, label: 'Указать свой цвет'),
    ];
    final dropdownValue = customMode ? _customRalOptionCode : selectedCode;
    final customColor = _colorForCode(selectedCode);
    final paintItem = widget.contextData.customPaintCatalogItem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frame color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Стандартные цвета берутся из reference domain colors. Полный справочник RAL берется из ral_colors. Для нестандартного цвета добавляется позиция из domain Lackierung.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _DropdownField(
          label: 'Frame color',
          value: dropdownValue,
          options: dropdownOptions,
          idSelector: (option) => option.code,
          onChanged: (next) {
            if (next == _customRalOptionCode) {
              setState(() {
                _customRalMode = true;
              });
              final existing = _normalizeRalCode(_customRalController.text);
              if (existing != null && !_standardColorCodes.contains(existing)) {
                _setColor(existing);
              }
              return;
            }
            setState(() {
              _customRalMode = false;
            });
            _customRalController.clear();
            _setColor(next);
          },
          emptyLabel: '— Color not selected —',
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 3.2,
          children: [
            for (final option in _standardColorOptions)
              _RalColorTile(
                label: option.label,
                color: _colorForCode(option.code),
                selected: selectedCode == _normalizeRalCode(option.code),
                onTap: () {
                  setState(() {
                    _customRalMode = false;
                  });
                  _customRalController.clear();
                  _setColor(option.code);
                },
              ),
            _RalColorTile(
              label: customSelected ? _labelForCode(selectedCode) : 'Указать свой цвет',
              color: customSelected ? customColor : null,
              selected: customMode,
              onTap: () {
                setState(() {
                  _customRalMode = true;
                });
                final existing = _normalizeRalCode(_customRalController.text);
                if (existing != null && !_standardColorCodes.contains(existing)) {
                  _setColor(existing);
                }
              },
            ),
          ],
        ),
        if (customMode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customRalController,
            decoration: const InputDecoration(
              labelText: 'Свой RAL код',
              hintText: 'Например: 3024',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              if (!_customRalMode) {
                setState(() {
                  _customRalMode = true;
                });
              }
              final normalized = _normalizeRalCode(value);
              if (normalized != null && normalized.length == 4) {
                _setColor(normalized);
              } else if (normalized == null) {
                _setColor(null);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            paintItem == null
                ? 'Для нестандартного цвета не найдена активная позиция в domain Lackierung.'
                : 'Для нестандартного цвета будет добавлена строка “${paintItem.name}”.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _RalColorTile extends StatelessWidget {
  const _RalColorTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = color ?? theme.colorScheme.surfaceContainerHighest;
    final foreground = color == null || background.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: foreground,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SetContentsStep extends StatefulWidget {
  const _SetContentsStep({
    required this.contextData,
    required this.draft,
    required this.notifier,
    required this.preview,
    required this.diagnostics,
    required this.onUpdateFromDefaults,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final AsyncValue<CalculatorSetContentsPreview> preview;
  final List<Map<String, dynamic>> diagnostics;
  final Future<void> Function() onUpdateFromDefaults;

  @override
  State<_SetContentsStep> createState() => _SetContentsStepState();
}

class _SetContentsStepState extends State<_SetContentsStep> {
  @override
  Widget build(BuildContext context) {
    widget.preview.whenData((preview) {
      final needsSeed = widget.draft.setContents.isEmpty ||
          widget.draft.setContents.every((tab) => tab.items.isEmpty);
      if (needsSeed && preview.tabs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.notifier.seedSetContentsIfEmpty(preview.tabs);
        });
      }
    });

    final preview = widget.preview.asData?.value;
    final tabs = widget.draft.setContents.isNotEmpty ? widget.draft.setContents : preview?.tabs ?? const <CalculatorSetContentTab>[];
    final isLoading = widget.preview.isLoading && widget.draft.setContents.isEmpty;
    final source = preview?.source ?? const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Set contents / Stückliste je Block', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: widget.draft.templateId == null ? null : widget.onUpdateFromDefaults,
              icon: const Icon(Icons.refresh),
              label: const Text('Update'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'The default composition is loaded from the linked rule set row. Each tab represents one geometry block of the roof. Use + to add another block with the same default contents, then adjust quantities and profile lengths per block.',
        ),
        const SizedBox(height: 12),
        if (isLoading) const LinearProgressIndicator(),
        if (source.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Rule set', value: '${source['rule_set_id'] ?? '—'}'),
              _InfoChip(label: 'Matrix', value: '${source['matrix_code'] ?? source['matrix_name'] ?? '—'}'),
              _InfoChip(label: 'Row', value: '${source['row_no'] ?? '—'}'),
            ],
          ),
          const SizedBox(height: 12),
        ],
        widget.preview.maybeWhen(
          error: (error, _) => _HintCard(
            icon: Icons.warning_amber_outlined,
            title: 'Set contents could not be loaded',
            text: '$error',
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        if (tabs.isEmpty && !isLoading)
          const _HintCard(
            icon: Icons.view_list_outlined,
            title: 'No set contents found',
            text: 'No linked published rule set row with result_json.components was found for this template/dimensions. Apply the SQL link script below and re-open this step.',
          )
        else
          _setContentTabs(context, tabs, preview?.tabs ?? const []),
      ],
    );
  }

  Widget _setContentTabs(
    BuildContext context,
    List<CalculatorSetContentTab> tabs,
    List<CalculatorSetContentTab> defaults,
  ) {
    return DefaultTabController(
      key: ValueKey('set-content-tabs-${tabs.length}'),
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabs: [for (final tab in tabs) Tab(text: tab.label)],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => widget.notifier.addSetContentTabFromDefault(defaults),
                icon: const Icon(Icons.add),
                label: const Text('Add block'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 440,
            child: TabBarView(
              children: [
                for (var tabIndex = 0; tabIndex < tabs.length; tabIndex++)
                  _SetContentTabTable(
                    contextData: widget.contextData,
                    tab: tabs[tabIndex],
                    tabIndex: tabIndex,
                    diagnostics: _diagnosticsForTab(tabs, tabIndex),
                    onRemoveTab: tabs.length <= 1 ? null : () => widget.notifier.removeSetContentTab(tabIndex),
                    onToggleItem: (itemIndex) => widget.notifier.toggleSetContentItemEnabled(tabIndex, itemIndex),
                    onQuantityChanged: (itemIndex, quantity) => widget.notifier.updateSetContentItemQuantity(tabIndex, itemIndex, quantity),
                    onLengthChanged: (itemIndex, lengthMm) => widget.notifier.updateSetContentItemLength(tabIndex, itemIndex, lengthMm),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _diagnosticsForTab(List<CalculatorSetContentTab> tabs, int tabIndex) {
    final offset = tabs.take(tabIndex).fold<int>(0, (sum, tab) => sum + tab.items.where((entry) => entry.enabled).length);
    final activeCount = tabs[tabIndex].items.where((entry) => entry.enabled).length;
    return widget.diagnostics.skip(offset).take(activeCount).toList(growable: false);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value', overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SetContentVisibleRow {
  const _SetContentVisibleRow({required this.itemIndex, required this.item});

  final int itemIndex;
  final CalculatorSetContentItem item;
}

List<_SetContentVisibleRow> _visibleSetContentRows(CalculatorContext contextData, CalculatorSetContentTab tab) {
  final rows = <_SetContentVisibleRow>[];
  for (var i = 0; i < tab.items.length; i++) {
    final item = tab.items[i];
    if (_isAccessorySetContentItem(contextData, item)) continue;
    rows.add(_SetContentVisibleRow(itemIndex: i, item: item));
  }
  return rows;
}

class _SetContentTabTable extends StatefulWidget {
  const _SetContentTabTable({
    required this.contextData,
    required this.tab,
    required this.tabIndex,
    required this.diagnostics,
    required this.onQuantityChanged,
    required this.onLengthChanged,
    required this.onToggleItem,
    this.onRemoveTab,
  });

  static const _profileWidth = 72.0;
  static const _qtyWidth = 92.0;
  static const _unitWidth = 58.0;
  static const _lengthWidth = 118.0;
  static const _priceWidth = 96.0;
  static const _toggleWidth = 44.0;
  static const _columnGap = 16.0;

  final CalculatorContext contextData;
  final CalculatorSetContentTab tab;
  final int tabIndex;
  final List<Map<String, dynamic>> diagnostics;
  final void Function(int itemIndex, num quantity) onQuantityChanged;
  final void Function(int itemIndex, int? lengthMm) onLengthChanged;
  final void Function(int itemIndex) onToggleItem;
  final VoidCallback? onRemoveTab;

  @override
  State<_SetContentTabTable> createState() => _SetContentTabTableState();
}

class _SetContentTabTableState extends State<_SetContentTabTable> {
  static const _profileWidth = _SetContentTabTable._profileWidth;
  static const _qtyWidth = _SetContentTabTable._qtyWidth;
  static const _unitWidth = _SetContentTabTable._unitWidth;
  static const _lengthWidth = _SetContentTabTable._lengthWidth;
  static const _priceWidth = _SetContentTabTable._priceWidth;
  static const _toggleWidth = _SetContentTabTable._toggleWidth;
  static const _columnGap = _SetContentTabTable._columnGap;
  static const _rowExtent = 60.0;
  static const _titleHeight = 48.0;
  static const _headerHeight = 32.0;
  static const _footerHeight = 34.0;
  static const _verticalPadding = 12.0;
  static const _dividerHeight = 1.0;

  final _scrollController = ScrollController();
  var _isAtListEnd = false;

  CalculatorContext get contextData => widget.contextData;
  CalculatorSetContentTab get tab => widget.tab;
  int get tabIndex => widget.tabIndex;
  List<Map<String, dynamic>> get diagnostics => widget.diagnostics;
  void Function(int itemIndex, num quantity) get onQuantityChanged => widget.onQuantityChanged;
  void Function(int itemIndex, int? lengthMm) get onLengthChanged => widget.onLengthChanged;
  void Function(int itemIndex) get onToggleItem => widget.onToggleItem;
  VoidCallback? get onRemoveTab => widget.onRemoveTab;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncScrollHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollHint());
  }

  @override
  void didUpdateWidget(covariant _SetContentTabTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollHint());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncScrollHint);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncScrollHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atEnd = position.maxScrollExtent <= 0 || position.pixels >= position.maxScrollExtent - 2;
    if (atEnd == _isAtListEnd) return;
    setState(() => _isAtListEnd = atEnd);
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleSetContentRows(contextData, tab);
    final activeCount = visibleRows.where((entry) => entry.item.enabled).length;
    final hiddenAccessoryCount = tab.items.length - visibleRows.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 440.0;
        const fixedHeightWithoutFooter = _verticalPadding +
            _titleHeight +
            _headerHeight +
            _dividerHeight +
            _dividerHeight;
        final slotsWithoutFooter = visibleRows.isEmpty
            ? 0
            : ((maxHeight - fixedHeightWithoutFooter) / _rowExtent).floor().clamp(1, visibleRows.length).toInt();
        final hasHiddenRows = visibleRows.length > slotsWithoutFooter;
        final showScrollHint = hasHiddenRows && !_isAtListEnd;
        final fixedHeight = fixedHeightWithoutFooter + (showScrollHint ? _dividerHeight + _footerHeight : 0);
        final visibleSlots = visibleRows.isEmpty
            ? 0
            : ((maxHeight - fixedHeight) / _rowExtent).floor().clamp(1, visibleRows.length).toInt();
        final listHeight = visibleRows.isEmpty ? null : visibleSlots * _rowExtent;

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _titleHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${tab.label} · $activeCount/${visibleRows.length} active set items${hiddenAccessoryCount > 0 ? ' · $hiddenAccessoryCount accessory moved' : ''}',
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove block',
                          onPressed: onRemoveTab,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                SizedBox(height: _headerHeight, child: _header(context)),
                const Divider(height: 1),
                if (visibleRows.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Only accessory components were found in this block. They are shown in the Accessory step.'),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: listHeight,
                    child: Scrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemExtent: _rowExtent,
                        itemCount: visibleRows.length,
                        itemBuilder: (context, index) => DecoratedBox(
                          decoration: BoxDecoration(
                            border: index == visibleRows.length - 1
                                ? null
                                : Border(
                                    bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
                                  ),
                          ),
                          child: _row(context, visibleRows[index]),
                        ),
                      ),
                    ),
                  ),
                if (showScrollHint) ...[
                  const Divider(height: 1),
                  SizedBox(
                    height: _footerHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 4),
                                Text('more', style: Theme.of(context).textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _fixedCell(context, const Text('Profile'), width: _profileWidth, header: true),
          _gap(),
          _expandedCell(context, const Text('Name'), flex: 5, header: true),
          _gap(),
          _fixedCell(context, const Text('Qty'), width: _qtyWidth, header: true),
          _gap(),
          _fixedCell(context, const Text('Unit'), width: _unitWidth, header: true),
          _gap(),
          _fixedCell(context, const Text('Length'), width: _lengthWidth, header: true),
          _gap(),
          _fixedCell(context, const Text('Price'), width: _priceWidth, header: true),
          _gap(),
          const SizedBox(width: _toggleWidth),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _SetContentVisibleRow row) {
    final index = row.itemIndex;
    final item = row.item;
    final catalogItem = _findItem(item.catalogItemId);
    final variant = _findVariant(item.catalogVariantId);
    final enabled = item.enabled;
    final activeIndex = tab.items.take(index).where((entry) => entry.enabled).length;
    final diagnostic = enabled && activeIndex < diagnostics.length ? diagnostics[activeIndex] : null;
    final profileNo = item.profileNo ?? variant?.profileNo ?? catalogItem?.profileNo ?? diagnostic?['profile_no']?.toString();
    final name = item.name ?? _selectedName(catalogItem, variant, item);
    final unit = item.salesUnitCode ?? item.unitCode ?? catalogItem?.defaultSalesUnitCode ?? catalogItem?.measureTypeCode ?? diagnostic?['unit_code']?.toString() ?? 'piece';
    final priceAmount = _num(diagnostic?['amount']);
    final colorScheme = Theme.of(context).colorScheme;

    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fixedCell(context, Text(profileNo ?? '—'), width: _profileWidth),
        _gap(),
        _expandedCell(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(
                [item.articleNo, item.variantSku, variant?.colorName, _formatLengthMm(variant?.lengthMm)]
                    .whereType<String>()
                    .where((entry) => entry.isNotEmpty)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          flex: 5,
        ),
        _gap(),
        _fixedCell(
          context,
          TextFormField(
            key: ValueKey('set-content-qty-$tabIndex-$index-${item.catalogItemId}-${item.catalogVariantId ?? ''}-$enabled'),
            initialValue: _formatInputQuantity(item.quantity),
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true),
            onChanged: (value) => onQuantityChanged(index, num.tryParse(value.replaceAll(',', '.')) ?? item.quantity),
          ),
          width: _qtyWidth,
        ),
        _gap(),
        _fixedCell(context, Text(_formatUnitLabel(unit)), width: _unitWidth),
        _gap(),
        _fixedCell(
          context,
          item.isProfile
              ? TextFormField(
                  key: ValueKey('set-content-length-$tabIndex-$index-${item.catalogItemId}-${item.catalogVariantId ?? ''}-$enabled'),
                  initialValue: item.lengthMm == null ? '' : '${item.lengthMm}',
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, suffixText: 'mm'),
                  onChanged: (value) => onLengthChanged(index, int.tryParse(value.trim())),
                )
              : Text(_formatLengthMm(item.lengthMm) ?? '—'),
          width: _lengthWidth,
        ),
        _gap(),
        _fixedCell(
          context,
          Text(priceAmount > 0 ? _moneyFormat.format(priceAmount) : '—'),
          width: _priceWidth,
        ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: enabled ? Colors.transparent : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: enabled ? 1 : 0.46,
              child: rowContent,
            ),
          ),
          _gap(),
          SizedBox(
            width: _toggleWidth,
            child: IconButton(
              tooltip: enabled ? 'Exclude from calculation' : 'Include in calculation',
              onPressed: () => onToggleItem(index),
              icon: Icon(enabled ? Icons.check_circle_outline : Icons.remove_circle_outline),
              color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(width: _columnGap);

  Widget _fixedCell(
    BuildContext context,
    Widget child, {
    required double width,
    bool header = false,
  }) {
    final style = header
        ? Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return SizedBox(
      width: width,
      child: DefaultTextStyle.merge(style: style, child: child),
    );
  }

  Widget _expandedCell(
    BuildContext context,
    Widget child, {
    int flex = 1,
    bool header = false,
  }) {
    final style = header
        ? Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Expanded(
      flex: flex,
      child: DefaultTextStyle.merge(style: style, child: child),
    );
  }

  CalculatorCatalogItemOption? _findItem(String? id) {
    if (id == null) return null;
    return contextData.optionCatalogItems.where((entry) => entry.id == id).cast<CalculatorCatalogItemOption?>().firstOrNull;
  }

  CalculatorCatalogVariantOption? _findVariant(String? id) {
    if (id == null) return null;
    return contextData.optionCatalogVariants.where((entry) => entry.id == id).cast<CalculatorCatalogVariantOption?>().firstOrNull;
  }

  String _selectedName(CalculatorCatalogItemOption? item, CalculatorCatalogVariantOption? variant, CalculatorSetContentItem selected) {
    return _joinDistinctTextParts([
      selected.itemTypeCode ?? item?.itemTypeCode,
      item?.name ?? selected.name,
      variant?.variantSku ?? selected.variantSku,
    ]);
  }
}


bool _isAccessorySetContentItem(CalculatorContext contextData, CalculatorSetContentItem item) {
  final catalogItem = contextData.optionCatalogItems
      .where((entry) => entry.id == item.catalogItemId)
      .cast<CalculatorCatalogItemOption?>()
      .firstOrNull;
  final itemTypeCode = (item.itemTypeCode ?? catalogItem?.itemTypeCode ?? '').trim().toLowerCase();
  return itemTypeCode == 'accessory' || itemTypeCode.contains('accessory');
}

class _AccessoryStep extends StatelessWidget {
  const _AccessoryStep({
    required this.contextData,
    required this.draft,
    required this.notifier,
    required this.diagnostics,
    required this.onFastenersPressed,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final List<Map<String, dynamic>> diagnostics;
  final VoidCallback onFastenersPressed;

  @override
  Widget build(BuildContext context) {
    final lines = _accessoryAggregateLines(contextData, draft, diagnostics);
    final totalQuantity = lines.fold<num>(0, (sum, line) => sum + line.quantity);
    final activeQuantity = lines.fold<num>(0, (sum, line) => sum + (line.enabled ? line.quantity : 0));
    final totalAmount = lines.fold<num>(0, (sum, line) => sum + line.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Accessory / Zubehör', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: onFastenersPressed,
              icon: const Icon(Icons.construction_outlined),
              label: const Text('Fasteners'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Accessory components are moved out of Set contents and collected here from all blocks. Equal catalog item/SKU/unit/length lines are summed; disabling a line excludes all its source components from calculation.',
        ),
        const SizedBox(height: 16),
        if (lines.isEmpty)
          const _HintCard(
            icon: Icons.build_outlined,
            title: 'No accessories in Set contents',
            text: 'Add or update Set contents first. All catalog items with item type accessory will be shown here automatically instead of inside Set contents.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Accessory lines', value: '${lines.length}'),
              _InfoChip(label: 'Active qty', value: _formatInputQuantity(activeQuantity)),
              _InfoChip(label: 'Total qty', value: _formatInputQuantity(totalQuantity)),
              _InfoChip(label: 'Cost', value: totalAmount > 0 ? _moneyFormat.format(totalAmount) : '—'),
            ],
          ),
          const SizedBox(height: 12),
          _AccessoryTable(
            lines: lines,
            onToggleLine: (line) {
              notifier.setSetContentItemsEnabled(
                line.sourceRefs.map((ref) => (tabIndex: ref.tabIndex, itemIndex: ref.itemIndex)).toList(growable: false),
                !line.enabled,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _AccessoryTable extends StatelessWidget {
  const _AccessoryTable({required this.lines, required this.onToggleLine});

  static const _toggleWidth = _SetContentTabTable._toggleWidth;

  final List<_AccessoryAggregateLine> lines;
  final ValueChanged<_AccessoryAggregateLine> onToggleLine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const Divider(height: 1),
            for (var i = 0; i < lines.length; i++) ...[
              _row(context, lines[i]),
              if (i < lines.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cell(context, const Text('Pr. Nr.'), width: 82, header: true),
          _cell(context, const Text('Accessory name'), flex: 5, header: true),
          _cell(context, const Text('Qty'), width: 72, header: true),
          _cell(context, const Text('Unit'), width: 64, header: true),
          _cell(context, const Text('Cost'), width: 104, header: true),
          const SizedBox(width: _toggleWidth),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _AccessoryAggregateLine line) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = line.enabled;
    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cell(context, Text(line.primaryCode ?? '—'), width: 82),
        _cell(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(line.name, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (line.secondaryInfo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  line.secondaryInfo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
          flex: 5,
        ),
        _cell(context, Text(_formatInputQuantity(line.quantity)), width: 72),
        _cell(context, Text(_formatUnitLabel(line.unitCode)), width: 64),
        _cell(context, Text(line.hasAmount ? _moneyFormat.format(line.amount) : '—'), width: 104),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: enabled ? Colors.transparent : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: enabled ? 1 : 0.46,
              child: rowContent,
            ),
          ),
          SizedBox(
            width: _toggleWidth,
            child: IconButton(
              tooltip: enabled ? 'Exclude accessory line from calculation' : 'Include accessory line in calculation',
              onPressed: () => onToggleLine(line),
              icon: Icon(enabled ? Icons.check_circle_outline : Icons.remove_circle_outline),
              color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
}

class _AccessorySourceRef {
  const _AccessorySourceRef({
    required this.tabIndex,
    required this.itemIndex,
    required this.enabled,
  });

  final int tabIndex;
  final int itemIndex;
  final bool enabled;
}

class _AccessoryAggregateLine {
  _AccessoryAggregateLine({
    required this.key,
    required this.catalogItemId,
    required this.catalogVariantId,
    required this.name,
    required this.unitCode,
    required this.quantity,
    required this.primaryCode,
    required this.secondaryInfo,
    required this.blockLabels,
    required this.sourceRefs,
    this.amount = 0,
    this.hasAmount = false,
  });

  final String key;
  final String catalogItemId;
  final String? catalogVariantId;
  final String name;
  final String unitCode;
  num quantity;
  final String? primaryCode;
  final String secondaryInfo;
  final List<String> blockLabels;
  final List<_AccessorySourceRef> sourceRefs;
  num amount;
  bool hasAmount;

  bool get enabled => sourceRefs.any((entry) => entry.enabled);
}

List<_AccessoryAggregateLine> _accessoryAggregateLines(
  CalculatorContext contextData,
  CalculatorDraft draft,
  List<Map<String, dynamic>> diagnostics,
) {
  final result = <String, _AccessoryAggregateLine>{};
  var activeOptionIndex = 0;

  for (var tabIndex = 0; tabIndex < draft.setContents.length; tabIndex++) {
    final tab = draft.setContents[tabIndex];
    for (var itemIndex = 0; itemIndex < tab.items.length; itemIndex++) {
      final item = tab.items[itemIndex];
      Map<String, dynamic>? diagnostic;
      if (item.enabled) {
        diagnostic = activeOptionIndex < diagnostics.length ? diagnostics[activeOptionIndex] : null;
        activeOptionIndex += 1;
      }

      if (!_isAccessorySetContentItem(contextData, item)) continue;

      final catalogItem = contextData.optionCatalogItems
          .where((entry) => entry.id == item.catalogItemId)
          .cast<CalculatorCatalogItemOption?>()
          .firstOrNull;
      final variant = contextData.optionCatalogVariants
          .where((entry) => entry.id == item.catalogVariantId)
          .cast<CalculatorCatalogVariantOption?>()
          .firstOrNull;
      final unitCode = item.salesUnitCode
          ?? item.unitCode
          ?? catalogItem?.defaultSalesUnitCode
          ?? catalogItem?.measureTypeCode
          ?? 'piece';
      final key = '${item.catalogItemId}|${item.catalogVariantId ?? ''}|$unitCode|${item.lengthMm ?? ''}';
      final primaryCode = _firstNonEmptyText([
        item.articleNo,
        variant?.articleNo,
        item.profileNo,
        variant?.profileNo,
        item.baseCode,
        catalogItem?.baseCode,
        item.variantSku,
        variant?.variantSku,
      ]);
      final name = _joinDistinctTextParts([
        item.name ?? catalogItem?.name,
        variant?.variantSku ?? item.variantSku,
      ]);
      final secondaryInfo = _joinDistinctTextParts([
        item.itemTypeCode ?? catalogItem?.itemTypeCode,
        variant?.colorName,
        _formatLengthMm(item.lengthMm ?? variant?.lengthMm),
      ]);
      final blockLabel = tab.label.isEmpty ? tab.id : tab.label;
      final amount = _num(diagnostic?['amount']);
      final hasAmount = item.enabled && diagnostic != null && diagnostic.containsKey('amount');

      final existing = result[key];
      final sourceRef = _AccessorySourceRef(tabIndex: tabIndex, itemIndex: itemIndex, enabled: item.enabled);
      if (existing == null) {
        result[key] = _AccessoryAggregateLine(
          key: key,
          catalogItemId: item.catalogItemId,
          catalogVariantId: item.catalogVariantId,
          name: name,
          unitCode: unitCode,
          quantity: item.quantity,
          primaryCode: primaryCode,
          secondaryInfo: secondaryInfo == 'Option' ? '' : secondaryInfo,
          blockLabels: [blockLabel],
          sourceRefs: [sourceRef],
          amount: amount,
          hasAmount: hasAmount,
        );
      } else {
        existing.quantity += item.quantity;
        existing.amount += amount;
        existing.hasAmount = existing.hasAmount || hasAmount;
        existing.sourceRefs.add(sourceRef);
        if (!existing.blockLabels.contains(blockLabel)) existing.blockLabels.add(blockLabel);
      }
    }
  }

  final lines = result.values.toList(growable: false)
    ..sort((a, b) {
      final codeCompare = (a.primaryCode ?? '').compareTo(b.primaryCode ?? '');
      if (codeCompare != 0) return codeCompare;
      return a.name.compareTo(b.name);
    });
  return lines;
}

String? _firstNonEmptyText(Iterable<String?> values) {
  for (final raw in values) {
    final value = raw?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

class _OptionsStep extends StatefulWidget {
  const _OptionsStep({
    required this.contextData,
    required this.draft,
    required this.notifier,
    required this.optionDiagnostics,
    required this.mediaRepository,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final List<Map<String, dynamic>> optionDiagnostics;
  final AdminResourceRepository mediaRepository;

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
              _CatalogOptionMediaPreview(
                item: selectedItem,
                variant: selectedVariant,
                repository: widget.mediaRepository,
              ),
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
    final item = widget.contextData.optionCatalogItems
        .where((entry) => entry.id == id)
        .cast<CalculatorCatalogItemOption?>()
        .firstOrNull;
    return item ?? (widget.contextData.customPaintCatalogItem?.id == id ? widget.contextData.customPaintCatalogItem : null);
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
          Icon(Icons.image_not_supported_outlined),
          SizedBox(height: 6),
          Text('no media\npreview', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CatalogOptionMediaPreview extends StatelessWidget {
  const _CatalogOptionMediaPreview({
    required this.item,
    required this.variant,
    required this.repository,
  });

  final CalculatorCatalogItemOption item;
  final CalculatorCatalogVariantOption? variant;
  final AdminResourceRepository repository;

  @override
  Widget build(BuildContext context) {
    final mediaRef = _mediaFileRef;
    if (mediaRef == null) {
      return const _SectionPreviewPlaceholder();
    }

    return _CatalogOptionMediaFrame(
      mediaRef: mediaRef,
      detailMediaRef: _detailMediaFileRef ?? mediaRef,
      repository: repository,
    );
  }

  MediaFileRef? get _mediaFileRef {
    final variantFileId = variant?.imageFileId?.trim();
    final itemFileId = item.mediaFileId?.trim();
    final fileId = variantFileId != null && variantFileId.isNotEmpty
        ? variantFileId
        : itemFileId != null && itemFileId.isNotEmpty
            ? itemFileId
            : null;
    if (fileId == null) return null;

    final variantDisplayName = variant?.displayName;
    final variantName = variantDisplayName?.trim();
    final itemName = item.displayName.trim();
    final label = variantName != null && variantName.isNotEmpty
        ? variantName
        : itemName.isNotEmpty
            ? itemName
            : 'Catalog item media';

    return MediaFileRef(
      fileId: fileId,
      fieldKey: variantFileId == fileId ? 'variant.image_file_id' : 'catalog_media.file_id',
      label: label,
    );
  }

  MediaFileRef? get _detailMediaFileRef {
    final variantLargeFileId = variant?.imageLargeFileId?.trim();
    final itemLargeFileId = item.mediaLargeFileId?.trim();
    final fileId = variantLargeFileId != null && variantLargeFileId.isNotEmpty
        ? variantLargeFileId
        : itemLargeFileId != null && itemLargeFileId.isNotEmpty
            ? itemLargeFileId
            : null;
    if (fileId == null) return null;

    final variantDisplayName = variant?.displayName;
    final variantName = variantDisplayName?.trim();
    final itemName = item.displayName.trim();
    final label = variantName != null && variantName.isNotEmpty
        ? variantName
        : itemName.isNotEmpty
            ? itemName
            : 'Catalog item media';

    return MediaFileRef(
      fileId: fileId,
      fieldKey: variantLargeFileId == fileId ? 'variant.image_large_file_id' : 'catalog_media.media_large_file_id',
      label: label,
    );
  }
}

class _CatalogOptionMediaFrame extends StatefulWidget {
  const _CatalogOptionMediaFrame({
    required this.mediaRef,
    required this.detailMediaRef,
    required this.repository,
  });

  final MediaFileRef mediaRef;
  final MediaFileRef detailMediaRef;
  final AdminResourceRepository repository;

  @override
  State<_CatalogOptionMediaFrame> createState() => _CatalogOptionMediaFrameState();
}

class _CatalogOptionMediaFrameState extends State<_CatalogOptionMediaFrame> {
  late Future<ApiBinaryResponse> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = widget.repository.viewMediaFile(widget.mediaRef.fileId);
  }

  @override
  void didUpdateWidget(covariant _CatalogOptionMediaFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaRef.fileId != widget.mediaRef.fileId) {
      _imageFuture = widget.repository.viewMediaFile(widget.mediaRef.fileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 104,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<ApiBinaryResponse>(
            future: _imageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final response = snapshot.data;
              if (snapshot.hasError || response == null || response.bytes.isEmpty) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              }

              return Padding(
                padding: const EdgeInsets.all(6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Image.memory(
                    response.bytes,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: colorScheme.surface.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(18),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: 'Preview media',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MediaPreviewDialog(
                    repository: widget.repository,
                    files: [widget.detailMediaRef],
                  ),
                ),
                icon: const Icon(Icons.open_in_full_rounded),
              ),
            ),
          ),
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
    final item = contextData.optionCatalogItems
        .where((entry) => entry.id == id)
        .cast<CalculatorCatalogItemOption?>()
        .firstOrNull;
    return item ?? (contextData.customPaintCatalogItem?.id == id ? contextData.customPaintCatalogItem : null);
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
    required this.onPrint,
    required this.isSavingQuote,
    this.loadedQuote,
    this.savedQuote,
  });

  final AsyncValue<CalculatorResult?> resultAsync;
  final CalculatorDraft draft;
  final LoadedQuote? loadedQuote;
  final VoidCallback onSaveQuote;
  final VoidCallback onPrint;
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
                  canPrint: loadedQuote != null || savedQuote != null,
                  onSaveQuote: onSaveQuote,
                  onPrint: onPrint,
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
                canPrint: loadedQuote != null || savedQuote != null,
                onSaveQuote: onSaveQuote,
                onPrint: onPrint,
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
    required this.canPrint,
    required this.onSaveQuote,
    required this.onPrint,
  });

  final bool canSaveQuote;
  final bool canSaveAsOption;
  final bool isSavingQuote;
  final SavedQuote? savedQuote;
  final bool canPrint;
  final VoidCallback onSaveQuote;
  final VoidCallback onPrint;

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
            onPressed: canPrint && !isSavingQuote ? onPrint : null,
            icon: const Icon(Icons.print_outlined),
            label: const Text('print'),
          ),
        ],
      ),
    );
  }
}


class _PrintDialog extends StatefulWidget {
  const _PrintDialog({
    required this.quoteId,
    required this.repository,
  });

  final String quoteId;
  final CalculatorRepository repository;

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  late final Future<PrintDialogData> _dataFuture;
  PrintTemplateOption? _selectedTemplate;
  List<GeneratedDocument> _documents = const [];
  bool _isPrinting = false;
  String? _statusText;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<PrintDialogData> _load() async {
    final data = await widget.repository.fetchPrintDialogData(widget.quoteId);
    _selectedTemplate = data.templates.isNotEmpty ? data.templates.first : null;
    _documents = data.recentDocuments.take(3).toList(growable: false);
    return data;
  }

  Future<void> _print() async {
    final template = _selectedTemplate;
    if (template == null || _isPrinting) return;

    setState(() {
      _isPrinting = true;
      _statusText = null;
      _errorText = null;
    });

    try {
      final document = await widget.repository.printPdf(
        quoteId: widget.quoteId,
        documentTemplateId: template.id,
      );
      if (!mounted) return;
      setState(() {
        _documents = [
          document,
          ..._documents.where((entry) => entry.id != document.id),
        ].take(3).toList(growable: false);
        _statusText = 'PDF generated';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = '$error');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<PrintDialogData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _HintCard(
                icon: Icons.error_outline,
                title: 'Print data failed',
                text: '${snapshot.error}',
              );
            }

            final data = snapshot.data!;
            final templates = data.templates;
            if (templates.isEmpty) {
              return const _HintCard(
                icon: Icons.print_disabled_outlined,
                title: 'No print templates',
                text: 'No active document_templates with settings_json.print.enabled = true and source_asset_file_id were found.',
              );
            }

            final selectedId = templates.any((entry) => entry.id == _selectedTemplate?.id)
                ? _selectedTemplate!.id
                : templates.first.id;
            _selectedTemplate = templates.firstWhere((entry) => entry.id == selectedId);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Document type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final template in templates)
                      DropdownMenuItem(
                        value: template.id,
                        child: Text(
                          template.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isPrinting
                      ? null
                      : (value) {
                          final next = templates.where((entry) => entry.id == value).firstOrNull;
                          if (next == null) return;
                          setState(() => _selectedTemplate = next);
                        },
                ),
                if (_statusText != null) ...[
                  const SizedBox(height: 12),
                  Text(_statusText!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 18),
                Text('Generated documents', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_documents.isEmpty)
                  const Text('No generated PDF yet.')
                else
                  ..._documents.map((document) => _GeneratedDocumentTile(
                        document: document,
                        repository: widget.repository,
                      )),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _selectedTemplate == null || _isPrinting ? null : _print,
          icon: _isPrinting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_outlined),
          label: const Text('Print'),
        ),
      ],
    );
  }
}

class _GeneratedDocumentTile extends StatelessWidget {
  const _GeneratedDocumentTile({
    required this.document,
    required this.repository,
  });

  final GeneratedDocument document;
  final CalculatorRepository repository;

  Future<void> _openPdf(BuildContext context) async {
    final fileId = document.fileId.trim();
    if (fileId.isEmpty) {
      final url = document.url;
      if (url != null && url.isNotEmpty) {
        openExternalUrlInNewTab(url);
      }
      return;
    }

    try {
      final response = await repository.viewMediaFile(fileId);
      openMediaBytes(
        response.bytes,
        filename: response.filename ?? document.filename,
        contentType: response.contentType,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open PDF failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if ((document.documentTypeCode ?? '').isNotEmpty) document.documentTypeCode,
      if ((document.createdAt ?? '').isNotEmpty) document.createdAt,
    ].whereType<String>().join(' · ');
    final canOpen = document.fileId.trim().isNotEmpty || (document.url ?? '').isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(document.filename, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, overflow: TextOverflow.ellipsis),
        trailing: TextButton.icon(
          onPressed: canOpen ? () => _openPdf(context) : null,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('View / Download PDF'),
        ),
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

    final baseLines = result.visibleLines.take(1).toList(growable: false);
    final afterBase = result.visibleLines.skip(baseLines.length).toList(growable: false);
    final setContentLineCount = result.setContentDiagnostics
        .where((entry) => entry['price_found'] == true && _num(entry['amount']) > 0)
        .length;
    final setContentLines = afterBase.take(setContentLineCount).toList(growable: false);
    final optionLines = afterBase.skip(setContentLines.length).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (baseLines.isNotEmpty) ...[
          _sectionHeader(context, 'Base price'),
          ..._lineTiles(baseLines),
        ],
        if (setContentLines.isNotEmpty) ...[
          _sectionHeader(context, 'Set contents', '${setContentLines.length} priced line(s)'),
          ..._lineTiles(setContentLines),
        ],
        if (optionLines.isNotEmpty) ...[
          _sectionHeader(context, 'Options / additional handling', '${optionLines.length} priced line(s)'),
          ..._lineTiles(optionLines),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, [String? suffix]) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            Text(suffix, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  List<Widget> _lineTiles(List<Map<String, dynamic>> lines) {
    final widgets = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      widgets.add(_lineTile(lines[i]));
      if (i < lines.length - 1) widgets.add(const Divider(height: 1));
    }
    return widgets;
  }

  Widget _lineTile(Map<String, dynamic> line) {
    final unitPrice = _num(line['unitPrice']);
    final note = '${line['note'] ?? ''}'.trim();
    final unit = _formatUnitLabel('${line['unit'] ?? ''}');
    final subtitleParts = <String>[
      'Qty ${line['quantity'] ?? 1} $unit',
      if (unitPrice > 0) '${_moneyFormat.format(unitPrice)} / $unit',
      if (note.isNotEmpty) note,
    ];
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text('${line['label'] ?? 'Line'}', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitleParts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(_moneyFormat.format(_num(line['amount']))),
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
    case 'set_contents':
      return draft.setContents.isNotEmpty;
    case 'accessory':
      return draft.setContents.isNotEmpty;
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


int _accessorySourceItemCountFromDraft(CalculatorDraft draft) {
  var count = 0;
  for (final tab in draft.setContents) {
    for (final item in tab.items) {
      if (!item.enabled) continue;
      final itemTypeCode = (item.itemTypeCode ?? '').trim().toLowerCase();
      if (itemTypeCode == 'accessory' || itemTypeCode.contains('accessory')) {
        count += 1;
      }
    }
  }
  return count;
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
    case 'set_contents':
      return draft.setContents.isEmpty
          ? 'auto from rule set'
          : '${draft.setContents.length} block(s), ${draft.setContents.fold<int>(0, (sum, tab) => sum + tab.items.length)} items';
    case 'accessory':
      final accessorySourceItems = _accessorySourceItemCountFromDraft(draft);
      return accessorySourceItems == 0
          ? (draft.setContents.isEmpty ? 'none' : 'from Set contents')
          : '$accessorySourceItems source item(s)';
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


String? _normalizeRalCode(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toUpperCase().replaceFirst(RegExp(r'^RAL\s*'), '').replaceAll(RegExp(r'\s+'), '');
  return normalized.isEmpty ? null : normalized;
}

String? _stringFromRaw(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

Color? _colorFromHex(String? value) {
  if (value == null) return null;
  final normalized = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) return null;
  return Color(int.parse('FF$normalized', radix: 16));
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

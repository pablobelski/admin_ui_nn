import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../data/roof_geometry_calculation.dart';
import 'calculator_providers.dart';
import 'model_geometry_preview.dart';

const _steps = <_StepDefinition>[
  _StepDefinition('product', 'Product', Icons.inventory_2_outlined),
  _StepDefinition('template', 'Template', Icons.account_tree_outlined),
  _StepDefinition('model', 'Model', Icons.view_in_ar_outlined),
  _StepDefinition('color', 'Color', Icons.palette_outlined),
  _StepDefinition('dimensions', 'Dimensions', Icons.straighten_outlined),
  _StepDefinition('covering', 'Covering', Icons.layers_outlined),
  _StepDefinition('set_contents', 'Set contents', Icons.view_list_outlined),
  _StepDefinition('accessory', 'Accessory', Icons.build_outlined),
  _StepDefinition('options', 'Options', Icons.tune_outlined),
  _StepDefinition('delivery', 'Delivery', Icons.local_shipping_outlined),
  _StepDefinition('summary', 'Summary', Icons.summarize_outlined),
];

final _moneyFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');
const _customRalOptionCode = '__custom_ral__';
final _catalogMediaFutureCache = <String, Future<ApiBinaryResponse>>{};

Future<ApiBinaryResponse> _catalogMediaFuture(
  AdminResourceRepository repository,
  String fileId,
) {
  return _catalogMediaFutureCache.putIfAbsent(
    fileId,
    () => repository.viewMediaFile(fileId),
  );
}

class CalculatorWorkspacePage extends ConsumerStatefulWidget {
  const CalculatorWorkspacePage({super.key});

  @override
  ConsumerState<CalculatorWorkspacePage> createState() => _CalculatorWorkspacePageState();
}

class _CalculatorWorkspacePageState extends ConsumerState<CalculatorWorkspacePage> {
  var _selectedStep = 0;
  var _isSavingQuote = false;
  SavedQuote? _savedQuote;
  CalculatorResult? _calculatedResult;
  String? _calculatedPriceSignature;
  int? _highlightedModuleIndex;
  int? _highlightedGlassFieldIndex;

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(calculatorContextProvider);
    final draft = ref.watch(calculatorDraftProvider);
    final resultAsync = ref.watch(calculatorResultProvider);
    final loadedQuote = ref.watch(loadedQuoteProvider);
    final quoteNumberPreview = ref.watch(calculatorQuoteNumberPreviewProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1280;
    final currentResult = resultAsync.asData?.value;
    final calculatedPriceSignature = _priceSignatureForResult(
      currentResult,
      loadedQuote,
    );
    final needsRecalculation = currentResult != null &&
        calculatedPriceSignature != null &&
        _priceSignature(draft) != calculatedPriceSignature;

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
        final buyerContact = calculatorContext.buyerContactFor(draft);
        final calculationNumber = loadedQuote?.quoteNo ?? quoteNumberPreview.asData?.value;
        final isCalculationSaved = loadedQuote != null && !draft.differsFromLoadedQuote(loadedQuote);
        final canCalculate = draft.templateId != null &&
            draft.widthMm != null &&
            draft.depthMm != null &&
            roofModelState.isSelected(draft.modelCode);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              selectedIndex: _selectedStep,
              disabledStepKeys: disabledStepKeys,
              draft: draft,
              buyerContact: buyerContact,
              onStepSelected: (index) => _selectStep(index),
              onNewCalculation: () => _confirmNewCalculation(context),
              onRefresh: () {
                ref.invalidate(calculatorContextProvider);
                ref.read(calculatorResultProvider.notifier).clear();
                setState(() {
                  _savedQuote = null;
                  _calculatedResult = null;
                  _calculatedPriceSignature = null;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            onModelChanged: (value) => _changeModel(context, value),
                            canCalculate: canCalculate,
                            roofModelState: roofModelState,
                            isLoadedCalculation: loadedQuote != null,
                            onModuleFocusChanged: (value) => setState(() {
                              _highlightedModuleIndex = value;
                              _highlightedGlassFieldIndex = null;
                            }),
                            onGlassFieldFocusChanged: (value) => setState(() => _highlightedGlassFieldIndex = value),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _ResultPanel(
                            resultAsync: resultAsync,
                            draft: draft,
                            calculatorContext: calculatorContext,
                            roofModelState: roofModelState,
                            selectedStep: _selectedStep,
                            highlightedModuleIndex: _highlightedModuleIndex,
                            highlightedGlassFieldIndex: _highlightedGlassFieldIndex,
                            mediaRepository: ref.read(resourceRepositoryProvider),
                            loadedQuote: loadedQuote,
                            savedQuote: _savedQuote,
                            calculationNumber: calculationNumber,
                            isCalculationSaved: isCalculationSaved,
                            needsRecalculation: needsRecalculation,
                            isSavingQuote: _isSavingQuote,
                            onSaveQuote: () => _showSaveQuoteDialog(context),
                            onPrint: () => _showPrintDialog(context),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: _StepCard(
                            selectedStep: _selectedStep,
                            calculatorContext: calculatorContext,
                            draft: draft,
                            selectedTemplate: selectedTemplate,
                            onNext: () => _moveStep(disabledStepKeys, 1),
                            onBack: () => _moveStep(disabledStepKeys, -1),
                            onCalculate: () => _calculate(context),
                            onModelChanged: (value) => _changeModel(context, value),
                            canCalculate: canCalculate,
                            roofModelState: roofModelState,
                            isLoadedCalculation: loadedQuote != null,
                            onModuleFocusChanged: (value) => setState(() {
                              _highlightedModuleIndex = value;
                              _highlightedGlassFieldIndex = null;
                            }),
                            onGlassFieldFocusChanged: (value) => setState(() => _highlightedGlassFieldIndex = value),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 360,
                          child: _ResultPanel(
                            resultAsync: resultAsync,
                            draft: draft,
                            calculatorContext: calculatorContext,
                            roofModelState: roofModelState,
                            selectedStep: _selectedStep,
                            highlightedModuleIndex: _highlightedModuleIndex,
                            highlightedGlassFieldIndex: _highlightedGlassFieldIndex,
                            mediaRepository: ref.read(resourceRepositoryProvider),
                            loadedQuote: loadedQuote,
                            savedQuote: _savedQuote,
                            calculationNumber: calculationNumber,
                            isCalculationSaved: isCalculationSaved,
                            needsRecalculation: needsRecalculation,
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

  void _selectStep(int index) {
    final key = _steps[index].key;
    setState(() {
      _selectedStep = index;
      if (key != 'set_contents') {
        _highlightedGlassFieldIndex = null;
      }
      if (!{'dimensions', 'set_contents', 'covering'}.contains(key)) {
        _highlightedModuleIndex = null;
      }
    });
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

    _selectStep(next);
  }

  String? _priceSignatureForResult(
    CalculatorResult? result,
    LoadedQuote? loadedQuote,
  ) {
    if (result == null) return null;
    if (identical(result, _calculatedResult) && _calculatedPriceSignature != null) {
      return _calculatedPriceSignature;
    }
    if (loadedQuote != null) {
      return _priceSignature(
        CalculatorDraft.fromCalculationJson(
          loadedQuote.input,
          productFamilyId: loadedQuote.productFamilyId,
        ),
      );
    }

    final rawInput = result.raw['input'];
    if (rawInput is! Map) return null;
    return _priceSignature(
      CalculatorDraft.fromCalculationJson(
        Map<String, dynamic>.from(rawInput),
      ),
    );
  }

  Future<void> _changeModel(BuildContext context, String? value) async {
    final draft = ref.read(calculatorDraftProvider);
    final normalized = value?.trim();
    final nextModel = normalized == null || normalized.isEmpty ? null : normalized;
    if (nextModel == draft.modelCode) return;

    final currentResult = ref.read(calculatorResultProvider).asData?.value;
    final hasSetContents = draft.setContents.any((tab) => tab.items.isNotEmpty);
    final hasAccessories = currentResult?.derivedAccessories.isNotEmpty == true;
    final notifier = ref.read(calculatorDraftProvider.notifier);
    if (!hasSetContents && !hasAccessories) {
      notifier.setModel(nextModel);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change model and recalculate?'),
        content: const Text(
          'The existing Set contents and Accessory result depend on the selected model. '
          'After the change, Set contents will be recalculated first and then the full calculation will run.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    notifier.setModel(nextModel, preserveSetContents: nextModel != null);
    if (nextModel == null) return;

    try {
      ref.read(calculatorSetContentsRefreshTickProvider.notifier).bump();
      final preview = await ref.read(calculatorSetContentsProvider.future);
      notifier.setSetContents(preview.tabs);
      if (!context.mounted) return;
      await _calculate(context);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model recalculation failed: $error')),
      );
    }
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
      _calculatedResult = null;
      _calculatedPriceSignature = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New calculation started')),
    );
  }

  bool _validateKommissionName(BuildContext context) {
    final value = ref.read(calculatorDraftProvider).quoteNoExternal?.trim() ?? '';
    if (value.isNotEmpty) return true;
    setState(() => _selectedStep = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fill Kommission name first.')),
    );
    return false;
  }

  Future<void> _calculate(BuildContext context) async {
    final draft = ref.read(calculatorDraftProvider);
    if (!_validateKommissionName(context)) return;
    if (draft.templateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a template first.')),
      );
      return;
    }

    final priceSignature = _priceSignature(draft);
    setState(() {
      _savedQuote = null;
      _calculatedResult = null;
      _calculatedPriceSignature = null;
    });
    final resultNotifier = ref.read(calculatorResultProvider.notifier);
    resultNotifier.setLoading();
    try {
      final result = await ref.read(calculatorRepositoryProvider).calculate(draft);
      _calculatedResult = result;
      _calculatedPriceSignature = priceSignature;
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
    if (!_validateKommissionName(context)) return;
    final canSaveCalculation = ref.read(calculatorResultProvider).maybeWhen(
      data: (value) => value != null,
      error: (_, __) => true,
      orElse: () => false,
    );
    if (!canSaveCalculation) {
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
        _calculatedResult = null;
        _calculatedPriceSignature = null;
        ref.read(calculatorResultProvider.notifier).clear();
      } else {
        _calculatedResult = loadedResult;
        _calculatedPriceSignature = _priceSignature(
          CalculatorDraft.fromCalculationJson(
            savedLoadedQuote.input,
            productFamilyId: savedLoadedQuote.productFamilyId,
          ),
        );
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
    required this.selectedIndex,
    required this.disabledStepKeys,
    required this.draft,
    required this.buyerContact,
    required this.onStepSelected,
  });

  final VoidCallback onRefresh;
  final VoidCallback onNewCalculation;
  final int selectedIndex;
  final Set<String> disabledStepKeys;
  final CalculatorDraft draft;
  final CalculatorBuyerContact buyerContact;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final buyerName = buyerContact.organizationName?.trim() ?? '';
    final buyerContactDetails = [
      buyerContact.contactName,
      buyerContact.email,
      buyerContact.phone,
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' · ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final left = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Center(
                child: Icon(
                  Icons.build_circle_outlined,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calculator Workspace', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: _StepScroller(
                      selectedIndex: selectedIndex,
                      disabledStepKeys: disabledStepKeys,
                      draft: draft,
                      onSelect: onStepSelected,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final actions = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
            ),
            if (buyerName.isNotEmpty || buyerContactDetails.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (buyerName.isNotEmpty)
                        Text(
                          buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      if (buyerName.isNotEmpty && buyerContactDetails.isNotEmpty)
                        const SizedBox(height: 2),
                      if (buyerContactDetails.isNotEmpty)
                        Text(
                          buyerContactDetails,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );

        if (constraints.maxWidth >= 1180) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: actions),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const SizedBox(height: 8), actions],
        );
      },
    );
  }

}

class _StepScroller extends StatelessWidget {
  const _StepScroller({
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
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, index) {
        final step = _steps[index];
        final disabled = disabledStepKeys.contains(step.key);
        final complete = !disabled && _isStepComplete(step.key, draft);
        final selected = index == selectedIndex;
        return _StepNavTab(
          step: step,
          selected: selected,
          disabled: disabled,
          complete: complete,
          onTap: disabled ? null : () => onSelect(index),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 4),
      itemCount: _steps.length,
    );
  }
}

class _StepNavTab extends StatelessWidget {
  const _StepNavTab({
    required this.step,
    required this.selected,
    required this.disabled,
    required this.complete,
    required this.onTap,
  });

  final _StepDefinition step;
  final bool selected;
  final bool disabled;
  final bool complete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = disabled
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
        : selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.72)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.58);
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.68)
        : colorScheme.outlineVariant.withValues(alpha: disabled ? 0.35 : 0.78);
    final iconColor = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
        : selected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
    final tooltip = disabled
        ? '${step.title}\nNot configured for selected template'
        : step.title;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: SizedBox(
        width: complete ? 52 : 42,
        height: 40,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: const _StepNavTabClipper(),
              child: Material(
                color: backgroundColor,
                child: InkWell(
                  onTap: onTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            disabled ? Icons.lock_outline : step.icon,
                            size: 18,
                            color: iconColor,
                          ),
                          if (complete) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.check,
                              size: 13,
                              color: disabled
                                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                                  : colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      if (selected)
                        Positioned(
                          left: 7,
                          right: 13,
                          bottom: 4,
                          child: Container(
                            height: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _StepNavTabBorderPainter(
                  color: borderColor,
                  selected: selected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepNavTabBorderPainter extends CustomPainter {
  const _StepNavTabBorderPainter({
    required this.color,
    required this.selected,
  });

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _StepNavTabClipper().getClip(size);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.2 : 0.8
      ..color = color;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _StepNavTabBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.selected != selected;
  }
}

class _StepNavTabClipper extends CustomClipper<Path> {
  const _StepNavTabClipper();

  @override
  Path getClip(Size size) {
    final nose = (size.height * 0.28).clamp(8.0, 12.0).toDouble();
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - nose, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - nose, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _StepNavTabClipper oldClipper) => false;
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
    required this.onModelChanged,
    required this.canCalculate,
    required this.roofModelState,
    required this.isLoadedCalculation,
    required this.onModuleFocusChanged,
    required this.onGlassFieldFocusChanged,
  });

  final int selectedStep;
  final CalculatorContext calculatorContext;
  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onCalculate;
  final ValueChanged<String?> onModelChanged;
  final bool canCalculate;
  final _RoofModelStepState roofModelState;
  final bool isLoadedCalculation;
  final ValueChanged<int?> onModuleFocusChanged;
  final ValueChanged<int?> onGlassFieldFocusChanged;

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
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _buildStepFrame(context, ref, step.key),
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
          'Calculated segments will be rebuilt from the current roof geometry. Only real manual changes, excluded segments, manual components and derived-accessory overrides are reapplied by their stable segment IDs.',
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
      ref.read(calculatorSetContentsRefreshTickProvider.notifier).bump();
      final preview = await ref.read(calculatorSetContentsProvider.future);
      notifier.setSetContents(preview.tabs);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculated segments updated; saved overrides were reapplied.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set contents update failed: $error')),
      );
    }
  }

  Widget _buildStepFrame(BuildContext context, WidgetRef ref, String key) {
    if (key == 'set_contents' || key == 'accessory') {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _buildStep(context, ref, key),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildStep(context, ref, key),
    );
  }

  Widget _buildStep(BuildContext context, WidgetRef ref, String key) {
    final notifier = ref.read(calculatorDraftProvider.notifier);
    switch (key) {
      case 'product':
        return _ProductStep(
          contextData: calculatorContext,
          draft: draft,
          isLoadedCalculation: isLoadedCalculation,
          mediaRepository: ref.read(resourceRepositoryProvider),
          onOrganizationChanged: notifier.setOrganization,
          onProductFamilyChanged: notifier.setProductFamily,
          onPriceModeChanged: notifier.setPriceMode,
          onQuoteNoExternalChanged: notifier.setQuoteNoExternal,
          onExternalNotesChanged: notifier.setExternalNotes,
          onRelatedCustomerChanged: notifier.setRelatedCustomer,
          onBrandingChanged: notifier.setBranding,
          onEngravingEnabledChanged: notifier.setEngravingEnabled,
          onOpenOrganization: (organizationId) => ref
              .read(selectedResourceProvider.notifier)
              .select('organizations', filters: {'id': organizationId}),
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
          mediaRepository: ref.read(resourceRepositoryProvider),
          onChanged: onModelChanged,
          onWallMountedChanged: notifier.setWallMounted,
        );
      case 'dimensions':
        return _DimensionsStep(
          draft: draft,
          notifier: notifier,
          selectedRoofModel: roofModelState.selectedForCode(draft.modelCode),
          selectedTemplate: selectedTemplate,
          isLoadedCalculation: isLoadedCalculation,
          onModuleFocusChanged: onModuleFocusChanged,
        );
      case 'covering':
        return _CoveringStep(
          draft: draft,
          selectedTemplate: selectedTemplate,
          selectedRoofModel: roofModelState.selectedForCode(draft.modelCode),
          notifier: notifier,
          options: calculatorContext.references['tds_glass_covering'] ?? const [],
          isLoadedCalculation: isLoadedCalculation,
          onModuleFocusChanged: onModuleFocusChanged,
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
          isLoadedCalculation: isLoadedCalculation,
          diagnostics: result?.manualComponentDiagnostics ?? const [],
          mediaRepository: ref.read(resourceRepositoryProvider),
          weights: result?.weights ?? const {},
          onModuleFocusChanged: onModuleFocusChanged,
          onGlassFieldFocusChanged: onGlassFieldFocusChanged,
          onUpdateFromDefaults: () => _confirmAndReloadSetContents(context, ref, notifier),
          onOpenRuleSet: (id) => ref
              .read(selectedResourceProvider.notifier)
              .select('rule_sets', filters: {'id': id}),
          onOpenRuleMatrix: (matrixId, ruleSetId) => ref
              .read(selectedResourceProvider.notifier)
              .select(
                'rule_matrices',
                filters: {
                  'id': matrixId,
                  if (ruleSetId != null && ruleSetId.isNotEmpty) 'rule_set_id': ruleSetId,
                },
              ),
        );
      case 'accessory':
        final result = ref.watch(calculatorResultProvider).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );
        final accessoryPreview = ref.watch(calculatorSetContentsProvider).asData?.value;
        return _AccessoryStep(
          contextData: calculatorContext,
          draft: draft,
          notifier: notifier,
          derivedAccessories: result?.derivedAccessories ?? accessoryPreview?.derivedAccessories ?? const [],
          derivedDiagnostics: result?.derivedAccessoryDiagnostics ?? const [],
          manualDiagnostics: result?.manualComponentDiagnostics ?? const [],
          mediaRepository: ref.read(resourceRepositoryProvider),
          weights: result?.weights ?? const {},
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
          weights: result?.weights ?? const {},
        );
      case 'delivery':
        return _DeliveryStep(
          draft: draft,
          options: calculatorContext.references['handover_types'] ?? const [],
          onHandoverChanged: notifier.setHandover,
          onCompletionWeekChanged: notifier.setCompletionWeek,
        );
      case 'summary':
      default:
        return _SummaryStep(
          draft: draft,
          selectedTemplate: selectedTemplate,
          selectedRoofModel: roofModelState.selectedForCode(draft.modelCode),
          coveringName: _coveringDisplayName(
            calculatorContext.references['tds_glass_covering'] ?? const [],
            draft.coveringCode,
          ),
        );
    }
  }
}

class _ProductStep extends StatefulWidget {
  const _ProductStep({
    required this.contextData,
    required this.draft,
    required this.isLoadedCalculation,
    required this.mediaRepository,
    required this.onOrganizationChanged,
    required this.onProductFamilyChanged,
    required this.onPriceModeChanged,
    required this.onQuoteNoExternalChanged,
    required this.onExternalNotesChanged,
    required this.onRelatedCustomerChanged,
    required this.onBrandingChanged,
    required this.onEngravingEnabledChanged,
    required this.onOpenOrganization,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final bool isLoadedCalculation;
  final AdminResourceRepository mediaRepository;
  final ValueChanged<String?> onOrganizationChanged;
  final ValueChanged<String?> onProductFamilyChanged;
  final ValueChanged<String?> onPriceModeChanged;
  final ValueChanged<String> onQuoteNoExternalChanged;
  final ValueChanged<String> onExternalNotesChanged;
  final ValueChanged<String?> onRelatedCustomerChanged;
  final ValueChanged<Map<String, dynamic>> onBrandingChanged;
  final ValueChanged<bool> onEngravingEnabledChanged;
  final ValueChanged<String> onOpenOrganization;

  @override
  State<_ProductStep> createState() => _ProductStepState();
}

class _ProductStepState extends State<_ProductStep> {
  late final TextEditingController _quoteNoExternal;
  late final TextEditingController _externalNotes;
  late final TextEditingController _organizationSearch;
  late final FocusNode _organizationFocus;
  late final TextEditingController _relatedCustomerSearch;
  late final FocusNode _relatedCustomerFocus;
  bool _byRelatedCustomer = false;
  String? _selectedRelatedCustomerId;

  @override
  void initState() {
    super.initState();
    _quoteNoExternal = TextEditingController(text: widget.draft.quoteNoExternal ?? '');
    _externalNotes = TextEditingController(text: widget.draft.externalNotes ?? '');
    _organizationSearch = TextEditingController(text: _organizationById(widget.draft.organizationId)?.label ?? '');
    _organizationFocus = FocusNode();
    _relatedCustomerSearch = TextEditingController();
    _relatedCustomerFocus = FocusNode();
    _byRelatedCustomer = _brandingSourceCode(widget.draft.branding) == 'selected_organization' ||
        (widget.draft.relatedCustomerId ?? '').isNotEmpty;
    _selectedRelatedCustomerId = widget.draft.relatedCustomerId;
    _scheduleBrandingSync();
  }

  @override
  void didUpdateWidget(covariant _ProductStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_quoteNoExternal, widget.draft.quoteNoExternal);
    _sync(_externalNotes, widget.draft.externalNotes);
    _sync(_organizationSearch, _organizationById(widget.draft.organizationId)?.label);
    if (oldWidget.draft.organizationId != widget.draft.organizationId) {
      _byRelatedCustomer = false;
      _selectedRelatedCustomerId = null;
      _relatedCustomerSearch.clear();
    }
    if (oldWidget.draft.relatedCustomerId != widget.draft.relatedCustomerId &&
        widget.draft.relatedCustomerId != _selectedRelatedCustomerId) {
      _selectedRelatedCustomerId = widget.draft.relatedCustomerId;
    }
    _scheduleBrandingSync();
  }

  void _sync(TextEditingController controller, String? value) {
    final text = value ?? '';
    if (controller.text != text) controller.text = text;
  }

  void _scheduleBrandingSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isLoadedCalculation) return;
      final relatedCustomers = widget.contextData.relatedCustomersFor(widget.draft.organizationId);
      final canUseRelatedCustomer = relatedCustomers.isNotEmpty;
      final shouldUseRelatedBranding = _byRelatedCustomer && canUseRelatedCustomer;
      if (_byRelatedCustomer && !canUseRelatedCustomer) {
        setState(() {
          _byRelatedCustomer = false;
          _selectedRelatedCustomerId = null;
        });
        widget.onRelatedCustomerChanged(null);
      }
      _applyBranding(byRelatedCustomer: shouldUseRelatedBranding);
    });
  }

  String _brandingSourceCode(Map<String, dynamic> branding) {
    final value = branding['source_code'] ?? branding['sourceCode'];
    return value == null ? '' : '$value'.trim();
  }

  bool _brandingEngravingEnabled() {
    final value = widget.draft.branding['engraving_enabled'] ?? widget.draft.branding['engravingEnabled'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return ['true', '1', 'yes', 'y'].contains(value.trim().toLowerCase());
    }
    return false;
  }

  CalculatorOption? _organizationById(String? organizationId) {
    final id = organizationId?.trim() ?? '';
    if (id.isEmpty) return null;
    return widget.contextData.organizations.where((entry) => entry.id == id).firstOrNull;
  }

  CalculatorBranding? _brandingFromOrganization(CalculatorOption? organization) {
    if (organization == null) return null;
    final branding = CalculatorBranding.fromJson(organization.raw);
    return branding.hasLogo || (branding.engravingText ?? '').isNotEmpty ? branding : null;
  }

  Map<String, dynamic> _brandingJsonFor({
    required bool byRelatedCustomer,
    bool? engravingEnabled,
  }) {
    final branding = byRelatedCustomer
        ? _brandingFromOrganization(_organizationById(widget.draft.organizationId))
        : widget.contextData.headBranding;
    if (branding == null) return const {};
    return branding.toCalculationJson(
      sourceCode: byRelatedCustomer ? 'selected_organization' : 'head_company',
      engravingEnabled: byRelatedCustomer ? (engravingEnabled ?? _brandingEngravingEnabled()) : false,
    );
  }

  void _applyBranding({required bool byRelatedCustomer, bool? engravingEnabled}) {
    final next = _brandingJsonFor(
      byRelatedCustomer: byRelatedCustomer,
      engravingEnabled: engravingEnabled,
    );
    if (_sameStringMap(widget.draft.branding, next)) return;
    widget.onBrandingChanged(next);
  }

  bool _sameStringMap(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in {...a.keys, ...b.keys}) {
      if ('${a[key] ?? ''}' != '${b[key] ?? ''}') return false;
    }
    return true;
  }

  CalculatorBranding? _activeBranding(bool canUseRelatedCustomer) {
    return _byRelatedCustomer && canUseRelatedCustomer
        ? _brandingFromOrganization(_organizationById(widget.draft.organizationId))
        : widget.contextData.headBranding;
  }

  @override
  void dispose() {
    _quoteNoExternal.dispose();
    _externalNotes.dispose();
    _organizationSearch.dispose();
    _organizationFocus.dispose();
    _relatedCustomerSearch.dispose();
    _relatedCustomerFocus.dispose();
    super.dispose();
  }

  String _relatedCustomerName(CalculatorOption option) {
    final rawName = option.raw['short_name'] ?? option.raw['display_name'] ?? option.raw['legal_name'];
    final value = rawName == null ? '' : '$rawName'.trim();
    return value.isNotEmpty ? value : option.label;
  }

  CalculatorOption? _selectedRelatedCustomer(List<CalculatorOption> relatedCustomers) {
    for (final option in relatedCustomers) {
      if (option.id == _selectedRelatedCustomerId) return option;
    }
    final currentName = widget.draft.quoteNoExternal?.trim() ?? '';
    if (currentName.isNotEmpty) {
      for (final option in relatedCustomers) {
        if (_relatedCustomerName(option) == currentName) return option;
      }
    }
    return null;
  }

  void _setByRelatedCustomer(bool value, List<CalculatorOption> relatedCustomers) {
    if (!value) {
      setState(() {
        _byRelatedCustomer = false;
        _selectedRelatedCustomerId = null;
      });
      _relatedCustomerSearch.clear();
      widget.onRelatedCustomerChanged(null);
      _applyBranding(byRelatedCustomer: false, engravingEnabled: false);
      return;
    }

    if (relatedCustomers.isEmpty) return;
    final selected = _selectedRelatedCustomer(relatedCustomers) ?? relatedCustomers.first;
    setState(() {
      _byRelatedCustomer = true;
      _selectedRelatedCustomerId = selected.id;
    });
    _relatedCustomerSearch.text = _relatedCustomerName(selected);
    widget.onRelatedCustomerChanged(selected.id);
    widget.onQuoteNoExternalChanged(_relatedCustomerName(selected));
    _applyBranding(byRelatedCustomer: true);
  }

  String? _buyerOrganizationId(CalculatorOption? relatedCustomer) {
    if (_byRelatedCustomer && relatedCustomer != null) {
      final raw = relatedCustomer.raw;
      for (final key in const ['child_organization_id', 'organization_id', 'branding_organization_id']) {
        final value = raw[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    final organizationId = widget.draft.organizationId?.trim() ?? '';
    return organizationId.isEmpty ? null : organizationId;
  }

  @override
  Widget build(BuildContext context) {
    final relatedCustomers = widget.contextData.relatedCustomersFor(widget.draft.organizationId);
    final canUseRelatedCustomer = relatedCustomers.isNotEmpty;
    final selectedRelatedCustomer = _selectedRelatedCustomer(relatedCustomers);
    if (!_relatedCustomerFocus.hasFocus) {
      _sync(_relatedCustomerSearch, selectedRelatedCustomer == null ? null : _relatedCustomerName(selectedRelatedCustomer));
    }
    final activeBranding = _activeBranding(canUseRelatedCustomer);
    final engravingText = activeBranding?.engravingText?.trim() ?? '';
    final engravingEnabled = _brandingEngravingEnabled();
    final buyerContact = widget.contextData.buyerContactFor(widget.draft);

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
        _SearchableOptionField<CalculatorOption>(
          label: 'Organization',
          controller: _organizationSearch,
          focusNode: _organizationFocus,
          options: widget.contextData.organizations,
          displayStringForOption: (option) => option.label,
          searchStringForOption: (option) => [
            option.label,
            option.code,
            option.raw['legal_name'],
            option.raw['display_name'],
            option.raw['short_name'],
          ].whereType<Object>().join(' '),
          onSelected: (option) {
            widget.onOrganizationChanged(option.id);
            if (_byRelatedCustomer) {
              setState(() {
                _byRelatedCustomer = false;
                _selectedRelatedCustomerId = null;
              });
              _relatedCustomerSearch.clear();
              widget.onRelatedCustomerChanged(null);
            }
            _applyBranding(byRelatedCustomer: false, engravingEnabled: false);
          },
        ),
        if (buyerContact.hasOrganization || buyerContact.hasContact) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                final organizationId = _buyerOrganizationId(selectedRelatedCustomer);
                if (organizationId != null) widget.onOpenOrganization(organizationId);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (buyerContact.hasOrganization)
                            Text(
                              buyerContact.organizationName!,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          if (buyerContact.hasContact) ...[
                            const SizedBox(height: 4),
                            Text(
                              [buyerContact.contactName, buyerContact.email, buyerContact.phone]
                                  .whereType<String>()
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        _DropdownField(
          label: 'Product family',
          value: widget.draft.productFamilyId,
          options: widget.contextData.productFamilies,
          idSelector: (option) => option.id,
          onChanged: widget.onProductFamilyChanged,
          emptyLabel: '— All templates —',
        ),
        const SizedBox(height: 16),
        _DropdownField(
          label: 'Price mode',
          value: widget.draft.priceMode,
          options: widget.contextData.priceModes,
          idSelector: (option) => option.code,
          onChanged: widget.onPriceModeChanged,
          emptyLabel: null,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Customer fields', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('By Related Customer', style: Theme.of(context).textTheme.bodyMedium),
            Switch(
              value: _byRelatedCustomer && canUseRelatedCustomer,
              onChanged: canUseRelatedCustomer ? (value) => _setByRelatedCustomer(value, relatedCustomers) : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_byRelatedCustomer && canUseRelatedCustomer)
          _SearchableOptionField<CalculatorOption>(
            label: 'Kommission name *',
            hintText: 'Search related customer',
            controller: _relatedCustomerSearch,
            focusNode: _relatedCustomerFocus,
            options: relatedCustomers,
            displayStringForOption: _relatedCustomerName,
            searchStringForOption: (option) => [
              _relatedCustomerName(option),
              option.label,
              option.code,
              option.raw['legal_name'],
              option.raw['display_name'],
              option.raw['short_name'],
            ].whereType<Object>().join(' '),
            onSelected: (selected) {
              setState(() => _selectedRelatedCustomerId = selected.id);
              widget.onRelatedCustomerChanged(selected.id);
              widget.onQuoteNoExternalChanged(_relatedCustomerName(selected));
              _applyBranding(byRelatedCustomer: true);
            },
          )
        else
          TextField(
            controller: _quoteNoExternal,
            decoration: const InputDecoration(
              labelText: 'Kommission name *',
              helperText: 'Customer-side calculation name / external quote number. Required.',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: widget.onQuoteNoExternalChanged,
          ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 104,
                child: _BrandingLogoPlaque(
                  branding: activeBranding,
                  repository: widget.mediaRepository,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _externalNotes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Quote notes',
                    helperText: 'Customer-side notes for this quote.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: widget.onExternalNotesChanged,
                ),
              ),
            ],
          ),
        ),
        if (_byRelatedCustomer && canUseRelatedCustomer) ...[
          const SizedBox(height: 16),
          _EngravingTextToggle(
            text: engravingText,
            enabled: engravingEnabled && engravingText.isNotEmpty,
            onChanged: engravingText.isEmpty
                ? null
                : (value) {
                    widget.onEngravingEnabledChanged(value);
                    _applyBranding(byRelatedCustomer: true, engravingEnabled: value);
                  },
          ),
        ],
      ],
    );
  }
}


class _BrandingLogoPlaque extends StatelessWidget {
  const _BrandingLogoPlaque({
    required this.branding,
    required this.repository,
  });

  final CalculatorBranding? branding;
  final AdminResourceRepository repository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logoFileId = branding?.logoFileId?.trim() ?? '';
    final label = branding == null ? 'Logo —' : 'Logo ${branding!.shortLabel}';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.all(6),
      ),
      child: Center(
        child: logoFileId.isEmpty
            ? Icon(Icons.image_not_supported_outlined, color: colorScheme.onSurfaceVariant)
            : FutureBuilder<ApiBinaryResponse>(
                future: _catalogMediaFuture(repository, logoFileId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final response = snapshot.data;
                  if (snapshot.hasError || response == null || response.bytes.isEmpty) {
                    return Icon(Icons.broken_image_outlined, color: colorScheme.onSurfaceVariant);
                  }
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Image.memory(
                        response.bytes,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EngravingTextToggle extends StatelessWidget {
  const _EngravingTextToggle({
    required this.text,
    required this.enabled,
    required this.onChanged,
  });

  final String text;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final engravingText = text.trim();
    final hasText = engravingText.isNotEmpty;
    final active = enabled && hasText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Switch(
            value: active,
            onChanged: hasText ? onChanged : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: active ? 1 : 0.45,
              child: SelectableText.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Engraving text: ',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: hasText ? engravingText : '—'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
        else ...[
          _TemplateInfoCard(template: selectedTemplate!),
          const SizedBox(height: 16),
          _TemplateConstantsCard(template: selectedTemplate!),
        ],
      ],
    );
  }
}


class _TemplateConstantsCard extends StatelessWidget {
  const _TemplateConstantsCard({required this.template});

  final CalculatorTemplateOption template;

  @override
  Widget build(BuildContext context) {
    final entries = _templateConstantEntries(template);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.data_object_outlined, size: 19, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Template constants', style: Theme.of(context).textTheme.titleSmall),
                ),
                Text('${entries.length}', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Effective constants from the selected template Parameters module.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty)
              Text(
                'No Parameters-module constants are configured for this template.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (var i = 0; i < entries.length; i++) ...[
                _TemplateConstantRow(entry: entries[i]),
                if (i < entries.length - 1) const Divider(height: 18),
              ],
          ],
        ),
      ),
    );
  }
}

class _TemplateConstantRow extends StatelessWidget {
  const _TemplateConstantRow({required this.entry});

  final _TemplateConstantEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final name = SelectableText(
          entry.path,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        );
        final value = SelectableText(
          entry.value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
        final description = Text(
          entry.description,
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name,
              const SizedBox(height: 4),
              value,
              const SizedBox(height: 3),
              description,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 230, child: name),
            const SizedBox(width: 12),
            SizedBox(width: 130, child: value),
            const SizedBox(width: 12),
            Expanded(child: description),
          ],
        );
      },
    );
  }
}

class _TemplateConstantEntry {
  const _TemplateConstantEntry({
    required this.path,
    required this.value,
    required this.description,
  });

  final String path;
  final String value;
  final String description;
}

List<_TemplateConstantEntry> _templateConstantEntries(CalculatorTemplateOption template) {
  final moduleData = template.parametersModuleData;
  final nested = moduleData['tds_glass_params'] ?? moduleData['tdsGlassParams'];
  final rawSource = nested is Map
      ? Map<String, dynamic>.from(nested)
      : moduleData;
  final values = <String, Object?>{};

  void flatten(Object? value, String path) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
      if (entries.isEmpty && path.isNotEmpty) {
        values[path] = const <String, dynamic>{};
      }
      for (final entry in entries) {
        final key = '${entry.key}'.trim();
        flatten(entry.value, path.isEmpty ? key : '$path.$key');
      }
      return;
    }
    if (path.isNotEmpty) values[path] = value;
  }

  flatten(template.roofParameters, '');
  flatten(rawSource, '');
  return values.entries
      .map(
        (entry) => _TemplateConstantEntry(
          path: entry.key,
          value: _templateConstantValue(entry.value),
          description: _templateConstantDescription(entry.key),
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _templateConstantValue(Object? value) {
  if (value == null) return '—';
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return jsonEncode(value);
}

String _templateConstantDescription(String path) {
  final key = path.split('.').last;
  final normalizedKey = _constantCamelKey(key);
  const descriptions = <String, String>{
    'beamWidthMm': 'Structural beam width used in roof field and beam-spacing formulas, in millimetres.',
    'backOffsetMm': 'Rear deduction from the module depth when calculating the effective beam length, in millimetres.',
    'frontOffsetMm': 'Front deduction from the module depth when calculating the effective beam length, in millimetres.',
    'glassListFrontAddMm': 'Additional front length applied to glass-list profiles, in millimetres.',
    'glassFrontAddMm': 'Additional front length applied to calculated glass panels, in millimetres.',
    'glassOverlapMm': 'Glass overlap included in the calculated glass-field width, in millimetres.',
    'defaultMaxGlassFieldWidthMm': 'Default maximum permitted glass-field width, in millimetres.',
    'screwSpacingMm': 'Target spacing between fixing screws, in millimetres.',
    'profileSplitThresholdMm': 'Profile length above which the profile is split into multiple pieces, in millimetres.',
    'gutterSplitThresholdMm': 'Gutter length above which the gutter is split into multiple pieces, in millimetres.',
    'coatingMaxLengthMm': 'Maximum profile length that can be coated in a special colour, in millimetres.',
    'manualProfileReviewLengthMm': 'Profile length above which the calculation components must be reviewed manually, in millimetres.',
    'defaultGlassDepthFieldCount': 'Minimum number of glass panels along the roof depth when the single-field beam-length threshold is exceeded.',
    'glassDepthJointGapMm': 'Gap deducted between glass panels split along the roof depth, in millimetres.',
    'singleGlassFieldMaxBeamLengthMm': 'Maximum calculated beam length for one glass field along the roof depth, in millimetres.',
    'coatingMinOrderValue': 'Minimum charge used for the special-colour coating calculation.',
    'coatingExtraPct': 'Additional percentage applied by the coating calculation.',
    'postLengthMm': 'Standard stock length used for post quantity calculations, in millimetres.',
    'pvcPipeLengthMm': 'Standard stock length used for PVC pipe quantity calculations, in millimetres.',
    'wallSealExtraM': 'Additional wall-seal allowance added to the calculated length, in metres.',
  };
  final known = descriptions[normalizedKey];
  if (known != null) return known;

  if (path.startsWith('componentArticleMap.') || path.startsWith('component_article_map.')) {
    return 'Catalog article number used for the ${_constantWords(key)} construction component.';
  }
  if (path.startsWith('accessoryArticleMap.') || path.startsWith('accessory_article_map.')) {
    return 'Catalog article number used for the ${_constantWords(key)} accessory.';
  }
  if (path.startsWith('glassCountOffsetsByModel.') || path.startsWith('glass_count_offsets_by_model.')) {
    final parts = path.split('.');
    final model = parts.length > 1 ? parts[1] : 'selected';
    final role = parts.length > 2 ? parts[2] : 'module';
    return 'Glass-count adjustment for model $model and module role $role.';
  }
  return 'Template constant used by the selected calculation template.';
}


String _constantCamelKey(String value) {
  final parts = value.split('_');
  if (parts.length == 1) return value;
  return parts.first +
      parts.skip(1).map((part) {
        if (part.isEmpty) return '';
        return '${part[0].toUpperCase()}${part.substring(1)}';
      }).join();
}

String _constantWords(String value) {
  return value
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}')
      .toLowerCase();
}


class _DimensionsStep extends StatefulWidget {
  const _DimensionsStep({
    required this.draft,
    required this.notifier,
    required this.selectedRoofModel,
    required this.selectedTemplate,
    required this.isLoadedCalculation,
    required this.onModuleFocusChanged,
  });

  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final CalculatorOption? selectedRoofModel;
  final CalculatorTemplateOption? selectedTemplate;
  final bool isLoadedCalculation;
  final ValueChanged<int?> onModuleFocusChanged;

  @override
  State<_DimensionsStep> createState() => _DimensionsStepState();
}

class _DimensionsStepState extends State<_DimensionsStep> {
  late final TextEditingController _width;
  late final TextEditingController _depth;
  late final TextEditingController _height;
  late final TextEditingController _rearHeight;
  late final TextEditingController _frontHeight;
  late final TextEditingController _angle;
  String? _angleErrorText;

  @override
  void initState() {
    super.initState();
    _width = TextEditingController(text: widget.draft.widthMm?.toString() ?? '');
    _depth = TextEditingController(text: widget.draft.depthMm?.toString() ?? '');
    _height = TextEditingController(text: widget.draft.heightMm?.toString() ?? '');
    _rearHeight = TextEditingController(text: _effectiveRearHeight(widget.draft)?.toString() ?? '');
    _frontHeight = TextEditingController(text: widget.draft.roofFrontHeightMm?.toString() ?? '');
    _angle = TextEditingController(text: _effectiveAngle(widget.draft)?.toString() ?? '');
    _angleErrorText = _angleValidationMessage(_angle.text);
    _syncModelDrivenState();
  }

  @override
  void didUpdateWidget(covariant _DimensionsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_width, widget.draft.widthMm);
    _sync(_depth, widget.draft.depthMm);
    _sync(_height, widget.draft.heightMm);
    _sync(_rearHeight, _effectiveRearHeight(widget.draft));
    _sync(_frontHeight, widget.draft.roofFrontHeightMm);
    _sync(_angle, _effectiveAngle(widget.draft));
    _angleErrorText = _angleValidationMessage(_angle.text);
    _syncModelDrivenState();
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
    _rearHeight.dispose();
    _frontHeight.dispose();
    _angle.dispose();
    super.dispose();
  }

  int get _minRoofAngleDeg => widget.selectedTemplate?.minRoofAngleDeg ?? 2;

  int get _maxRoofAngleDeg => widget.selectedTemplate?.maxRoofAngleDeg ?? 14;

  int _clampRoofAngle(int value) => value.clamp(_minRoofAngleDeg, _maxRoofAngleDeg).toInt();

  String? _angleValidationMessage(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter $_minRoofAngleDeg–$_maxRoofAngleDeg°';
    if (parsed < _minRoofAngleDeg || parsed > _maxRoofAngleDeg) {
      return 'Allowed $_minRoofAngleDeg–$_maxRoofAngleDeg°';
    }
    return null;
  }

  void _syncModelDrivenState() {
    final roles = _moduleRolesFor(widget.selectedRoofModel);
    final needsModuleSeed = !widget.isLoadedCalculation && widget.draft.setContents.isEmpty;
    final firstModule = widget.draft.setContents.firstOrNull;
    final needsDimensionSeed = !widget.isLoadedCalculation &&
        firstModule != null &&
        ((widget.draft.widthMm != null && firstModule.moduleWidthMm == null) ||
            (widget.draft.depthMm != null && firstModule.moduleDepthMm == null));
    final rawDefaultAngle = _defaultAngleFor(widget.selectedRoofModel);
    final defaultAngle = rawDefaultAngle == null ? null : _clampRoofAngle(rawDefaultAngle);
    final needsAngleSeed = !widget.isLoadedCalculation &&
        widget.draft.roofAngleDeg == null &&
        defaultAngle != null;
    final rearHeight = _effectiveRearHeight(widget.draft);
    final frontHeight = widget.draft.roofFrontHeightMm;
    final needsFrontHeightCorrection = !widget.isLoadedCalculation &&
        rearHeight != null &&
        frontHeight != null &&
        frontHeight > rearHeight;
    if (!needsModuleSeed && !needsDimensionSeed && !needsAngleSeed && !needsFrontHeightCorrection) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isLoadedCalculation) return;
      if (needsModuleSeed || needsDimensionSeed) widget.notifier.setSetContentModuleRoles(roles);
      if (needsAngleSeed) {
        widget.notifier.setRoofAngleValue(defaultAngle);
        _recalculateFrontHeightFromAngle(defaultAngle);
      } else if (needsFrontHeightCorrection) {
        widget.notifier.setRoofFrontHeightValue(rearHeight);
      }
    });
  }

  int? _effectiveRearHeight(CalculatorDraft draft) => draft.roofRearHeightMm ?? draft.heightMm;

  int? _effectiveAngle(CalculatorDraft draft) {
    if (draft.roofAngleDeg != null) return _clampRoofAngle(draft.roofAngleDeg!);
    final rear = _effectiveRearHeight(draft);
    final front = draft.roofFrontHeightMm;
    final depth = _effectiveDepth(draft);
    if (rear == null || front == null || depth == null || depth <= 0) return _defaultAngleFor(widget.selectedRoofModel);
    return _clampRoofAngle((math.atan((rear - front) / depth) * 180 / math.pi).round());
  }

  int? _effectiveDepth(CalculatorDraft draft) {
    if (draft.depthMm != null) return draft.depthMm;
    return draft.setContents
        .map((tab) => tab.moduleDepthMm)
        .whereType<int>()
        .fold<int?>(null, (maxDepth, value) => maxDepth == null || value > maxDepth ? value : maxDepth);
  }

  void _onHeightChanged(String value) {
    widget.notifier.setHeight(value);
    final parsed = int.tryParse(value.trim());
    if (parsed != null && widget.draft.roofAngleDeg != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _recalculateFrontHeightFromAngle(widget.draft.roofAngleDeg, rearHeight: parsed),
      );
    }
  }

  void _onDepthChanged(String value) {
    widget.notifier.setDepth(value);
    final parsed = int.tryParse(value.trim());
    if (parsed != null && widget.draft.roofAngleDeg != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _recalculateFrontHeightFromAngle(widget.draft.roofAngleDeg, depthMm: parsed),
      );
    }
  }

  void _onAngleChanged(String value) {
    final error = _angleValidationMessage(value);
    if (_angleErrorText != error) setState(() => _angleErrorText = error);
    final angle = int.tryParse(value.trim());
    if (angle == null) {
      widget.notifier.setRoofAngle(value);
      return;
    }
    if (error != null) return;
    widget.notifier.setRoofAngleValue(angle);
    _recalculateFrontHeightFromAngle(angle);
  }

  void _onFrontHeightChanged(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      widget.notifier.setRoofFrontHeight(value);
      return;
    }
    final rear = _effectiveRearHeight(widget.draft);
    final depth = _effectiveDepth(widget.draft);
    final front = rear != null && parsed > rear ? rear : parsed;
    if (front != parsed) _sync(_frontHeight, front > 0 ? front : null);
    widget.notifier.setRoofFrontHeightValue(front > 0 ? front : null);
    if (rear == null || depth == null || depth <= 0) return;
    final rawAngle = (math.atan((rear - front) / depth) * 180 / math.pi).round();
    final angle = _clampRoofAngle(rawAngle);
    widget.notifier.setRoofAngleValue(angle);
    if (rawAngle != angle) _recalculateFrontHeightFromAngle(angle, rearHeight: rear, depthMm: depth);
  }

  void _recalculateFrontHeightFromAngle(int? angle, {int? rearHeight, int? depthMm}) {
    final rear = rearHeight ?? _effectiveRearHeight(widget.draft);
    final depth = depthMm ?? _effectiveDepth(widget.draft);
    if (angle == null || rear == null || depth == null || depth <= 0) return;
    final calculatedFront = (rear - math.tan(angle * math.pi / 180) * depth).round();
    final front = calculatedFront > rear ? rear : calculatedFront;
    widget.notifier.setRoofFrontHeightValue(front > 0 ? front : null);
  }

  void _updateModulesFromModel() {
    widget.onModuleFocusChanged(null);
    widget.notifier.setSetContentModuleRoles(_moduleRolesFor(widget.selectedRoofModel));
  }

  @override
  Widget build(BuildContext context) {
    final moduleRoles = _moduleRolesFor(widget.selectedRoofModel);
    final roofCalculation = calculateRoofGeometryForDraft(
      draft: widget.draft,
      template: widget.selectedTemplate,
      model: widget.selectedRoofModel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dimensions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Enter the main dimensions and module dimensions. Modules follow the selected roof model segment_order and are highlighted in the geometry preview while editing.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _NumberField(label: 'Width mm', controller: _width, onChanged: widget.notifier.setWidth),
            _NumberField(label: 'Depth mm', controller: _depth, onChanged: _onDepthChanged),
            _NumberField(label: 'Height mm', controller: _height, onChanged: _onHeightChanged),
          ],
        ),
        const SizedBox(height: 24),
        _RoofCalculationParamsCard(
          forceOddBeams: widget.draft.forceOddBeams,
          onForceOddBeamsChanged: widget.notifier.setForceOddBeams,
        ),
        const SizedBox(height: 16),
        _SetContentModuleDimensionsEditor(
          draft: widget.draft,
          moduleRoles: moduleRoles,
          selectedRoofModel: widget.selectedRoofModel,
          onUpdateModules: _updateModulesFromModel,
          onIncrementModuleCount: widget.notifier.incrementSetContentModuleCount,
          onRemoveModule: widget.notifier.removeSetContentTab,
          onModuleGeometryChanged: widget.notifier.updateSetContentModuleGeometry,
          onModuleFocusChanged: widget.onModuleFocusChanged,
          calculatedModules: roofCalculation.modules,
        ),
        const SizedBox(height: 16),
        _RoofSlopeControls(
          rearHeightController: _rearHeight,
          frontHeightController: _frontHeight,
          angleController: _angle,
          minAngleDeg: _minRoofAngleDeg,
          maxAngleDeg: _maxRoofAngleDeg,
          angleErrorText: _angleErrorText,
          onFrontHeightChanged: _onFrontHeightChanged,
          onAngleChanged: _onAngleChanged,
        ),
      ],
    );
  }
}

class _SetContentModuleDimensionsEditor extends StatelessWidget {
  const _SetContentModuleDimensionsEditor({
    required this.draft,
    required this.moduleRoles,
    required this.selectedRoofModel,
    required this.onUpdateModules,
    required this.onIncrementModuleCount,
    required this.onRemoveModule,
    required this.onModuleGeometryChanged,
    required this.onModuleFocusChanged,
    required this.calculatedModules,
  });

  final CalculatorDraft draft;
  final List<String> moduleRoles;
  final CalculatorOption? selectedRoofModel;
  final VoidCallback onUpdateModules;
  final VoidCallback onIncrementModuleCount;
  final ValueChanged<int> onRemoveModule;
  final void Function(int tabIndex, String key, String value) onModuleGeometryChanged;
  final ValueChanged<int?> onModuleFocusChanged;
  final List<RoofModuleCalculation> calculatedModules;

  @override
  Widget build(BuildContext context) {
    final tabs = draft.setContents.isEmpty
        ? [
            CalculatorSetContentTab(
              id: 'part-1',
              label: _moduleDisplayLabel(moduleRoles.firstOrNull ?? 'main', 1),
              geometryKey: {'role': moduleRoles.firstOrNull ?? 'main'},
              items: const [],
            ),
          ]
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
                      Text('Set Content modules', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      const Text(
                        'Modules are generated from the selected roof model segment_order. Each module keeps only width and depth here; height is controlled globally.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Update modules from selected roof model',
                        onPressed: onUpdateModules,
                        icon: const Icon(Icons.sync, size: 17),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Add module',
                        onPressed: onIncrementModuleCount,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < tabs.length; i++) ...[
              _moduleRow(context, tabs[i], i),
              if (i < tabs.length - 1) const Divider(height: 20),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HintCard(
                icon: Icons.warning_amber_outlined,
                title: 'Module dimensions need review',
                text: warnings.join('\n'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moduleRow(BuildContext context, CalculatorSetContentTab tab, int index) {
    final role = tab.moduleRole.isNotEmpty
        ? tab.moduleRole
        : (index < moduleRoles.length ? moduleRoles[index] : 'module_${index + 1}');
    final configuredModuleCount = moduleRoles.isEmpty ? 1 : moduleRoles.length;
    final canRemove = index >= configuredModuleCount;
    final calculated = calculatedModules
        .where((entry) => entry.role == role || entry.moduleIndex == index + 1)
        .cast<RoofModuleCalculation?>()
        .firstOrNull;
    return Focus(
      key: ValueKey('set-content-module-focus-${tab.id}'),
      onFocusChange: (hasFocus) => onModuleFocusChanged(hasFocus ? index + 1 : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_moduleDisplayLabel(role, index + 1)),
                ),
              ),
              const SizedBox(width: 12),
              _dimensionField(
                context,
                tabId: tab.id,
                fieldKey: 'width_mm',
                label: '${_widthCodeFor(role, index)} width',
                value: tab.moduleWidthMm,
                maxValue: draft.widthMm,
                index: index,
              ),
              const SizedBox(width: 12),
              _dimensionField(
                context,
                tabId: tab.id,
                fieldKey: 'depth_mm',
                label: 'TK${_dimensionNumberForRole(role, index)} depth',
                value: tab.moduleDepthMm,
                maxValue: draft.depthMm,
                index: index,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 44,
                child: canRemove
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton(
                          tooltip: 'Remove manually added module',
                          onPressed: () => onRemoveModule(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          if (calculated != null)
            Padding(
              padding: const EdgeInsets.only(left: 130, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _CalculationValueChip(label: 'Beams', value: '${calculated.beamCount}'),
                  _CalculationValueChip(label: 'Beam length', value: '${calculated.beamLengthMm} mm'),
                  _CalculationValueChip(
                    label: 'Glass offset',
                    value: calculated.glassCountOffset > 0
                        ? '+${calculated.glassCountOffset}'
                        : '${calculated.glassCountOffset}',
                  ),
                ],
              ),
            ),
        ],
      ),
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
    final error = _dimensionError(value, maxValue, fieldKey);
    return _ModuleDimensionField(
      key: ValueKey('set-content-module-$tabId-$fieldKey'),
      value: value,
      label: '$label mm',
      errorText: error,
      onTap: () => onModuleFocusChanged(index + 1),
      onChanged: (input) {
        onModuleFocusChanged(index + 1);
        onModuleGeometryChanged(index, fieldKey, input);
      },
    );
  }

  String _widthCodeFor(String role, int index) {
    final roofText = '${selectedRoofModel?.code ?? ''} ${selectedRoofModel?.label ?? ''}'.toLowerCase();
    final prefix = roofText.contains('rinne') ? 'BR' : 'BW';
    return '$prefix${_dimensionNumberForRole(role, index)}';
  }

  int _dimensionNumberForRole(String role, int index) {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole == 'main') return 1;
    if (normalizedRole == 'small') return 2;
    return index + 1;
  }

  String? _dimensionError(int? value, int? maxValue, String fieldKey) {
    if (value == null || maxValue == null || maxValue <= 0) return null;
    if (value > maxValue) return '>${_formatLengthMm(maxValue)}';
    if (fieldKey == 'width_mm') {
      final values = draft.setContents.map((tab) => tab.moduleWidthMm).whereType<int>().toList(growable: false);
      if (values.length == draft.setContents.length && values.length > 1) {
        final sum = values.fold<int>(0, (total, item) => total + item);
        if (sum != maxValue) return 'Σ ${_formatLengthMm(sum)} ≠ ${_formatLengthMm(maxValue)}';
      }
    }
    return null;
  }

  List<String> _warningsFor(List<CalculatorSetContentTab> tabs) {
    final warnings = <String>[];
    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final label = _moduleDisplayLabel(tab.moduleRole, i + 1);
      if (draft.widthMm != null && tab.moduleWidthMm != null && tab.moduleWidthMm! > draft.widthMm!) {
        warnings.add('$label: width ${_formatLengthMm(tab.moduleWidthMm)} is greater than main width ${_formatLengthMm(draft.widthMm)}.');
      }
    }

    final widthValues = tabs.map((tab) => tab.moduleWidthMm).whereType<int>().toList(growable: false);
    if (draft.widthMm != null && widthValues.length == tabs.length && widthValues.length > 1) {
      final sum = widthValues.fold<int>(0, (total, value) => total + value);
      if (sum != draft.widthMm!) {
        warnings.add('Sum of module widths ${_formatLengthMm(sum)} must equal main width ${_formatLengthMm(draft.widthMm)}.');
      }
    }

    return warnings;
  }
}


class _CalculationValueChip extends StatelessWidget {
  const _CalculationValueChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _ModuleDimensionField extends StatefulWidget {
  const _ModuleDimensionField({
    super.key,
    required this.value,
    required this.label,
    required this.errorText,
    required this.onTap,
    required this.onChanged,
  });

  final int? value;
  final String label;
  final String? errorText;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  State<_ModuleDimensionField> createState() => _ModuleDimensionFieldState();
}

class _ModuleDimensionFieldState extends State<_ModuleDimensionField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ModuleDimensionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value?.toString() ?? '';
    final currentValue = int.tryParse(_controller.text.trim());
    if (_controller.text != nextText && (!_focusNode.hasFocus || currentValue != widget.value)) {
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: 'mm',
          errorText: widget.errorText,
        ),
        onTap: widget.onTap,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _RoofSlopeControls extends StatelessWidget {
  const _RoofSlopeControls({
    required this.rearHeightController,
    required this.frontHeightController,
    required this.angleController,
    required this.minAngleDeg,
    required this.maxAngleDeg,
    required this.angleErrorText,
    required this.onFrontHeightChanged,
    required this.onAngleChanged,
  });

  final TextEditingController rearHeightController;
  final TextEditingController frontHeightController;
  final TextEditingController angleController;
  final int minAngleDeg;
  final int maxAngleDeg;
  final String? angleErrorText;
  final ValueChanged<String> onFrontHeightChanged;
  final ValueChanged<String> onAngleChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roof slope / angle', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Rear height follows the global Height value. Front height and angle keep each other in sync. Allowed angle: $minAngleDeg–$maxAngleDeg°.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _NumberField(label: 'Rear height, mm', controller: rearHeightController, onChanged: (_) {}, readOnly: true),
                _NumberField(label: 'Front height, mm', controller: frontHeightController, onChanged: onFrontHeightChanged),
                _NumberField(
                  label: 'Roof angle',
                  controller: angleController,
                  onChanged: onAngleChanged,
                  suffixText: '°',
                  errorText: angleErrorText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoofCalculationParamsCard extends StatelessWidget {
  const _RoofCalculationParamsCard({
    required this.forceOddBeams,
    required this.onForceOddBeamsChanged,
  });

  final bool forceOddBeams;
  final ValueChanged<bool> onForceOddBeamsChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calculation parameters', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.82,
                    alignment: Alignment.centerLeft,
                    child: Switch(
                      value: forceOddBeams,
                      onChanged: onForceOddBeamsChanged,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text('Force odd beams', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoveringCalculationParamsCard extends StatelessWidget {
  const _CoveringCalculationParamsCard({
    required this.maxGlassFieldWidthController,
    required this.maximumWidthMm,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController maxGlassFieldWidthController;
  final int maximumWidthMm;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calculation parameters', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _NumberField(
                label: 'Max glass field width',
                controller: maxGlassFieldWidthController,
                onChanged: onChanged,
                errorText: errorText,
              ),
              const SizedBox(height: 4),
              Text('Maximum for selected glass: $maximumWidthMm mm'),
            ],
          ),
        ),
      ),
    );
  }
}

String _roofParametersConfigurationMessage(CalculatorTemplateOption template) {
  final missing = template.roofParameterMissingKeys;
  final missingText = missing.isEmpty ? '' : ' Missing parameters: ${missing.join(', ')}.';
  return 'Open Templates → Configurator templates, select "${template.name}", then open its Template modules and configure an active module with code "parameters". '
      'Fill the tds_glass_params values in Default data JSON.$missingText';
}

List<String> _moduleRolesFor(CalculatorOption? model) => roofModuleRolesForModel(model);

Map<String, dynamic> _optionMetadata(CalculatorOption? model) {
  if (model == null) return const {};
  final rawMetadata = model.raw['metadata_json'] ?? model.raw['metadata'];
  if (rawMetadata is Map) return Map<String, dynamic>.from(rawMetadata);
  return model.raw;
}

int? _defaultAngleFor(CalculatorOption? model) {
  final metadata = _optionMetadata(model);
  return _intFromFlexible(metadata['default_angle'] ?? metadata['defaultAngle']);
}

int? _intFromFlexible(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _moduleDisplayLabel(String role, int index) {
  final value = role.trim();
  if (value.isEmpty) return 'Module $index';
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
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
    required this.mediaRepository,
    required this.onChanged,
    required this.onWallMountedChanged,
  });

  final _RoofModelStepState roofModelState;
  final CalculatorDraft draft;
  final AdminResourceRepository mediaRepository;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool> onWallMountedChanged;

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
        _ModelCalculationParamsCard(
          wallMounted: draft.wallMounted,
          onWallMountedChanged: onWallMountedChanged,
        ),
        const SizedBox(height: 20),
        _RoofModelMediaPreview(
          model: roofModelState.selectedForCode(draft.modelCode),
          repository: mediaRepository,
        ),
      ],
    );
  }
}


class _ModelCalculationParamsCard extends StatelessWidget {
  const _ModelCalculationParamsCard({
    required this.wallMounted,
    required this.onWallMountedChanged,
  });

  final bool wallMounted;
  final ValueChanged<bool> onWallMountedChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calculation parameters', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.82,
                    alignment: Alignment.centerLeft,
                    child: Switch(
                      value: wallMounted,
                      onChanged: onWallMountedChanged,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text('Wandmontage', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _RoofModelMediaPreview extends StatelessWidget {
  const _RoofModelMediaPreview({
    required this.model,
    required this.repository,
  });

  final CalculatorOption? model;
  final AdminResourceRepository repository;

  @override
  Widget build(BuildContext context) {
    final mediaRef = _mediaRef;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: mediaRef == null
          ? Row(
              children: [
                Icon(Icons.image_not_supported_outlined, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    model == null
                        ? 'Select a roof model to show its default reference image.'
                        : 'No default image is linked to this roof model yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            )
          : _RoofModelMediaFrame(
              mediaRef: mediaRef,
              repository: repository,
            ),
    );
  }

  MediaFileRef? get _mediaRef {
    final currentModel = model;
    if (currentModel == null) return null;
    final fileId = _firstString(
      currentModel.raw['media_file_id'],
      currentModel.raw['default_media_file_id'],
      currentModel.raw['image_file_id'],
    );
    if (fileId == null || fileId.isEmpty) return null;

    return MediaFileRef(
      fileId: fileId,
      fieldKey: 'catalog_media.file_id',
      label: currentModel.label.isNotEmpty ? currentModel.label : 'Roof model image',
    );
  }
}

class _RoofModelMediaFrame extends StatefulWidget {
  const _RoofModelMediaFrame({
    required this.mediaRef,
    required this.repository,
  });

  final MediaFileRef mediaRef;
  final AdminResourceRepository repository;

  @override
  State<_RoofModelMediaFrame> createState() => _RoofModelMediaFrameState();
}

class _RoofModelMediaFrameState extends State<_RoofModelMediaFrame> {
  late Future<ApiBinaryResponse> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _catalogMediaFuture(widget.repository, widget.mediaRef.fileId);
  }

  @override
  void didUpdateWidget(covariant _RoofModelMediaFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaRef.fileId != widget.mediaRef.fileId) {
      _imageFuture = _catalogMediaFuture(widget.repository, widget.mediaRef.fileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<ApiBinaryResponse>(
            future: _imageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final response = snapshot.data;
              if (snapshot.hasError || response == null || response.bytes.isEmpty) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              }

              return Padding(
                padding: const EdgeInsets.all(8),
                child: Image.memory(
                  response.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              );
            },
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: colorScheme.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(18),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: 'Preview media',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MediaPreviewDialog(
                    repository: widget.repository,
                    files: [widget.mediaRef],
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

String? _firstString(Object? first, [Object? second, Object? third]) {
  for (final value in [first, second, third]) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _coveringDisplayName(
  List<CalculatorOption> options,
  String? coveringCode,
) {
  return options
          .where((option) => option.code == coveringCode || option.id == coveringCode)
          .firstOrNull
          ?.label ??
      coveringCode;
}

class _CoveringStep extends StatefulWidget {
  const _CoveringStep({
    required this.draft,
    required this.selectedTemplate,
    required this.selectedRoofModel,
    required this.notifier,
    required this.options,
    required this.isLoadedCalculation,
    required this.onModuleFocusChanged,
  });

  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;
  final CalculatorOption? selectedRoofModel;
  final CalculatorDraftNotifier notifier;
  final List<CalculatorOption> options;
  final bool isLoadedCalculation;
  final ValueChanged<int?> onModuleFocusChanged;

  @override
  State<_CoveringStep> createState() => _CoveringStepState();
}

class _CoveringStepState extends State<_CoveringStep> {
  late final TextEditingController _maxGlassFieldWidth;
  String? _maxGlassFieldErrorText;
  int? _selectedModuleIndex;

  @override
  void initState() {
    super.initState();
    _maxGlassFieldWidth = TextEditingController(
      text: (widget.draft.maxGlassFieldWidthMm
              ?? widget.selectedTemplate?.defaultMaxGlassFieldWidthMm
              ?? 750)
          .toString(),
    );
    _maxGlassFieldErrorText = _maxGlassFieldValidationMessage(_maxGlassFieldWidth.text);
    _syncTemplateParameter();
  }

  @override
  void didUpdateWidget(covariant _CoveringStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = (widget.draft.maxGlassFieldWidthMm
            ?? widget.selectedTemplate?.defaultMaxGlassFieldWidthMm
            ?? 750)
        .toString();
    if (_maxGlassFieldWidth.text != nextText) _maxGlassFieldWidth.text = nextText;
    _maxGlassFieldErrorText = _maxGlassFieldValidationMessage(_maxGlassFieldWidth.text);
    _syncTemplateParameter();
  }

  int _coveringMaxGlassFieldWidth([String? coveringCode]) =>
      widget.selectedTemplate?.maxGlassFieldWidthFor(coveringCode ?? widget.draft.coveringCode) ?? 750;

  int get _defaultMaxGlassFieldWidth =>
      widget.selectedTemplate?.defaultMaxGlassFieldWidthMm ?? 750;

  String? _maxGlassFieldValidationMessage(String value, [String? coveringCode]) {
    final parsed = int.tryParse(value.trim());
    final maximum = _coveringMaxGlassFieldWidth(coveringCode);
    if (parsed == null || parsed <= 0) return 'Enter 1–$maximum mm';
    if (parsed > maximum) return 'Maximum $maximum mm for selected glass';
    return null;
  }

  void _syncTemplateParameter() {
    if (widget.isLoadedCalculation) return;
    final maximum = _coveringMaxGlassFieldWidth();
    final current = widget.draft.maxGlassFieldWidthMm;
    final target = math.min(current ?? _defaultMaxGlassFieldWidth, maximum).toInt();
    if (current == target) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isLoadedCalculation) return;
      widget.notifier.setMaxGlassFieldWidthValue(target);
    });
  }

  void _onMaxGlassFieldWidthChanged(String value) {
    final error = _maxGlassFieldValidationMessage(value);
    if (_maxGlassFieldErrorText != error) setState(() => _maxGlassFieldErrorText = error);
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0 || error != null) return;
    widget.notifier.setMaxGlassFieldWidthValue(parsed);
  }

  void _onCoveringChanged(String? value) {
    widget.notifier.setCovering(value);
    final maximum = _coveringMaxGlassFieldWidth(value);
    final current = widget.draft.maxGlassFieldWidthMm ?? _defaultMaxGlassFieldWidth;
    final target = math.min(current, maximum).toInt();
    _maxGlassFieldWidth.text = target.toString();
    setState(() => _maxGlassFieldErrorText = null);
    widget.notifier.setMaxGlassFieldWidthValue(target);
  }

  @override
  void dispose() {
    _maxGlassFieldWidth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roofCalculation = calculateRoofGeometryForDraft(
      draft: widget.draft,
      template: widget.selectedTemplate,
      model: widget.selectedRoofModel,
    );
    final coveringName = _coveringDisplayName(
      widget.options,
      widget.draft.coveringCode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SelectStep(
          title: 'Covering / Eindeckung',
          description:
              'For TDS/SkyView Glas the existing reference domain tds_glass_covering is used. Poly options should be moved into a dedicated domain or template schema.',
          value: widget.draft.coveringCode,
          options: widget.options,
          onChanged: _onCoveringChanged,
          emptyLabel: '— Covering not selected —',
        ),
        const SizedBox(height: 16),
        _CoveringCalculationParamsCard(
          maxGlassFieldWidthController: _maxGlassFieldWidth,
          maximumWidthMm: _coveringMaxGlassFieldWidth(),
          errorText: _maxGlassFieldErrorText,
          onChanged: _onMaxGlassFieldWidthChanged,
        ),
        if (roofCalculation.modules.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CalculatedGlassCard(
            modules: roofCalculation.modules,
            coveringCode: widget.draft.coveringCode,
            coveringName: coveringName,
            selectedModuleIndex: _selectedModuleIndex,
            onModuleSelected: (index) {
              setState(() => _selectedModuleIndex = index);
              widget.onModuleFocusChanged(index);
            },
          ),
        ],
        if (widget.selectedTemplate != null && !widget.selectedTemplate!.hasCompleteRoofParameters) ...[
          const SizedBox(height: 16),
          _ErrorCard(
            title: 'Roof calculation parameters are not configured',
            message: _roofParametersConfigurationMessage(widget.selectedTemplate!),
          ),
        ],
      ],
    );
  }
}


class _CalculatedGlassCard extends StatelessWidget {
  const _CalculatedGlassCard({
    required this.modules,
    required this.coveringCode,
    required this.coveringName,
    required this.selectedModuleIndex,
    required this.onModuleSelected,
  });

  final List<RoofModuleCalculation> modules;
  final String? coveringCode;
  final String? coveringName;
  final int? selectedModuleIndex;
  final ValueChanged<int> onModuleSelected;

  @override
  Widget build(BuildContext context) {
    final totalWeight = modules.fold<double>(
      0,
      (sum, module) => sum + _glassWeightKg(module.glassAreaM2, coveringCode),
    );
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Calculated glass', style: Theme.of(context).textTheme.labelLarge)),
                _CalculationValueChip(label: 'Glasgewicht', value: '${totalWeight.toStringAsFixed(1)} kg'),
              ],
            ),
            const SizedBox(height: 10),
            for (final module in modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selectedModuleIndex == module.moduleIndex
                      ? const Color(0xFFF1F3F5).withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onModuleSelected(module.moduleIndex),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedModuleIndex == module.moduleIndex
                              ? const Color(0xFFAEB4BC)
                              : colorScheme.outlineVariant.withValues(alpha: 0.45),
                          width: selectedModuleIndex == module.moduleIndex
                              ? 1.2
                              : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  _moduleDisplayLabel(module.role, module.moduleIndex),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _CalculationValueChip(label: 'Type', value: coveringName ?? '—'),
                                    _CalculationValueChip(label: 'Quantity', value: '${module.glassCount}'),
                                    _CalculationValueChip(
                                      label: 'Size',
                                      value: '${module.glassWidthMm} × ${module.glassLengthMm} mm',
                                    ),
                                    _CalculationValueChip(
                                      label: 'Area',
                                      value: '${module.glassAreaM2.toStringAsFixed(1)} m²',
                                    ),
                                    _CalculationValueChip(
                                      label: 'Weight',
                                      value: '${_glassWeightKg(module.glassAreaM2, coveringCode).toStringAsFixed(1)} kg',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (module.glassDepthFieldCount > 1) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 110),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  for (var fieldIndex = 1;
                                      fieldIndex <= module.glassDepthFieldCount;
                                      fieldIndex++)
                                    _CalculationValueChip(
                                      label: 'Glass field $fieldIndex/${module.glassDepthFieldCount}',
                                      value:
                                          '${(module.glassCount / module.glassDepthFieldCount).round()} sheets · ${module.glassWidthMm} × ${module.glassLengthMm} mm',
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
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


class _DeliveryStep extends StatefulWidget {
  const _DeliveryStep({
    required this.draft,
    required this.options,
    required this.onHandoverChanged,
    required this.onCompletionWeekChanged,
  });

  final CalculatorDraft draft;
  final List<CalculatorOption> options;
  final ValueChanged<String?> onHandoverChanged;
  final ValueChanged<int?> onCompletionWeekChanged;

  @override
  State<_DeliveryStep> createState() => _DeliveryStepState();
}

class _DeliveryStepState extends State<_DeliveryStep> {
  late final TextEditingController _weekController;

  @override
  void initState() {
    super.initState();
    _weekController = TextEditingController(text: widget.draft.completionWeek?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _DeliveryStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.completionWeek == widget.draft.completionWeek) return;
    final text = widget.draft.completionWeek?.toString() ?? '';
    if (_weekController.text != text) _weekController.text = text;
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeek = _isoWeekNumber(now);
    final lastWeek = _isoWeekNumber(DateTime(now.year, 12, 28));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delivery / handover', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Delivery type and planned completion week are stored with the calculation and quote.'),
        const SizedBox(height: 20),
        _DropdownField(
          label: 'Delivery / handover',
          value: widget.draft.handoverTypeCode,
          options: widget.options,
          idSelector: (option) => option.code,
          onChanged: widget.onHandoverChanged,
          emptyLabel: '— Delivery not selected —',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 260,
          child: TextFormField(
            controller: _weekController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Fertigst. KW',
              suffixText: 'KW',
              helperText: 'Allowed: KW $currentWeek–$lastWeek (${now.year})',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final week = int.tryParse(value);
              if (week == null || week < currentWeek || week > lastWeek) {
                return 'Enter a week from $currentWeek to $lastWeek';
              }
              return null;
            },
            onChanged: (value) {
              final week = int.tryParse(value);
              widget.onCompletionWeekChanged(
                week != null && week >= currentWeek && week <= lastWeek ? week : null,
              );
            },
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frame color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Стандартные цвета берутся из reference domain colors. Для нестандартного RAL надбавка рассчитывается по окрашиваемым погонным метрам алюминиевых профилей.',
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
            'Sonderfarbe рассчитывается отдельно и не получает скидку организации.',
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
    required this.isLoadedCalculation,
    required this.diagnostics,
    required this.mediaRepository,
    required this.weights,
    required this.onModuleFocusChanged,
    required this.onGlassFieldFocusChanged,
    required this.onUpdateFromDefaults,
    required this.onOpenRuleSet,
    required this.onOpenRuleMatrix,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final AsyncValue<CalculatorSetContentsPreview> preview;
  final bool isLoadedCalculation;
  final List<Map<String, dynamic>> diagnostics;
  final AdminResourceRepository mediaRepository;
  final Map<String, dynamic> weights;
  final ValueChanged<int?> onModuleFocusChanged;
  final ValueChanged<int?> onGlassFieldFocusChanged;
  final Future<void> Function() onUpdateFromDefaults;
  final ValueChanged<String> onOpenRuleSet;
  final void Function(String matrixId, String? ruleSetId) onOpenRuleMatrix;

  @override
  State<_SetContentsStep> createState() => _SetContentsStepState();
}

class _SetContentsStepState extends State<_SetContentsStep> {
  int _selectedModuleTabIndex = 0;
  final Map<int, int> _selectedGlassFieldByTab = <int, int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.draft.setContents.isNotEmpty) {
        widget.onModuleFocusChanged(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    widget.preview.whenData((preview) {
      final needsSeed = widget.draft.setContents.isEmpty ||
          widget.draft.setContents.every((tab) => tab.items.isEmpty);
      if (needsSeed && preview.tabs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.notifier.seedSetContentsIfEmpty(
            preview.tabs,
            preserveStructure: widget.isLoadedCalculation,
          );
        });
      }
    });

    final preview = widget.preview.asData?.value;
    final tabs = widget.draft.setContents.isNotEmpty
        ? widget.draft.setContents
        : preview?.tabs ?? const <CalculatorSetContentTab>[];
    final isLoading = widget.preview.isLoading && widget.draft.setContents.isEmpty;
    final source = preview?.source ?? const <String, dynamic>{};
    final standardBom = preview?.standardBom ?? const <Map<String, dynamic>>[];
    final setDeltaBom = preview?.setDeltaBom ?? const <Map<String, dynamic>>[];
    final hasMissingSetPieceAbzug = setDeltaBom.any(
      _isMissingSetPieceAbzugCase,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set contents / Calculated segments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'The module structure is fixed by the selected roof model. Calculated profile segments describe the physical construction and are not added to the price as ordinary options. Use Override only for a deliberate production correction; add separate manual components when required.',
        ),
        const SizedBox(height: 10),
        if (isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ],
        if (source.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: 'Rule set',
                value: '${source['rule_set_name'] ?? source['rule_set_id'] ?? '—'}',
                onTap: '${source['rule_set_id'] ?? ''}'.trim().isEmpty
                    ? null
                    : () => widget.onOpenRuleSet('${source['rule_set_id']}'),
              ),
              _InfoChip(
                label: 'Matrix',
                value: '${source['matrix_name'] ?? source['matrix_code'] ?? '—'}',
                onTap: '${source['rule_matrix_id'] ?? ''}'.trim().isEmpty
                    ? null
                    : () => widget.onOpenRuleMatrix(
                          '${source['rule_matrix_id']}',
                          '${source['rule_set_id'] ?? ''}'.trim().isEmpty
                              ? null
                              : '${source['rule_set_id']}',
                        ),
              ),
              _InfoChip(label: 'Row', value: '${source['row_no'] ?? '—'}'),
              _InfoChip(label: 'Standard lines', value: '${standardBom.length}'),
              _InfoChip(label: 'Delta lines', value: '${setDeltaBom.length}'),
              if (widget.weights.isNotEmpty)
                _InfoChip(label: 'Set weight', value: _weightText(widget.weights, 'set_kg', 'set_complete')),
            ],
          ),
          const SizedBox(height: 8),
        ],
        widget.preview.maybeWhen(
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HintCard(
              icon: Icons.warning_amber_outlined,
              title: 'Set contents could not be calculated',
              text: '$error',
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        Expanded(
          child: DefaultTabController(
            key: ValueKey('set-content-main-tabs-${tabs.map((tab) => tab.moduleRole).join('-')}'),
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        onTap: (index) {
                          if (index == 0) {
                            final fieldIndex = _selectedGlassFieldByTab[_selectedModuleTabIndex] ?? 0;
                            widget.onModuleFocusChanged(_selectedModuleTabIndex + 1);
                            widget.onGlassFieldFocusChanged(fieldIndex == 0 ? null : fieldIndex);
                          } else {
                            widget.onModuleFocusChanged(null);
                            widget.onGlassFieldFocusChanged(null);
                          }
                        },
                        tabs: const [
                          Tab(text: 'Modules set'),
                          Tab(text: 'Standard set'),
                          Tab(text: 'Current set delta'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: widget.draft.templateId == null ? null : widget.onUpdateFromDefaults,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recalculate'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [
                      tabs.isEmpty
                          ? const _HintCard(
                              icon: Icons.view_list_outlined,
                              title: 'No calculated segments',
                              text: 'Complete the model, dimensions and roof Parameters module first. A missing standard rule row does not prevent geometry BOM calculation, but it prevents set-delta pricing.',
                            )
                          : _setContentTabs(
                              context,
                              tabs,
                              hasMissingSetPieceAbzug:
                                  hasMissingSetPieceAbzug,
                            ),
                      _BomSummaryList(
                        contextData: widget.contextData,
                        mediaRepository: widget.mediaRepository,
                        title: 'Standard set from price grid',
                        subtitle: 'Used only as the comparison basis for Zusatzgröße / Abzug.',
                        emptyText: 'No standard-set components were returned by the matched price-grid row.',
                        lines: standardBom,
                      ),
                      _BomSummaryList(
                        contextData: widget.contextData,
                        mediaRepository: widget.mediaRepository,
                        title: 'Current set delta',
                        subtitle: 'Only these differences are price-relevant; the calculated BOM itself is not.',
                        emptyText: 'The current calculated set has no price-relevant differences from the standard set.',
                        lines: setDeltaBom,
                        showDeltaDirection: true,
                        includedMissingSetPieceAbzugArticleNos: widget
                            .draft.missingSetPieceAbzugArticleNos
                            .toSet(),
                        onSetMissingSetPieceAbzugForArticles: widget.notifier
                            .setMissingSetPieceAbzugForArticles,
                        onSetMissingSetPieceAbzugForArticle: widget.notifier
                            .setMissingSetPieceAbzugForArticle,
                      ),
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

  Widget _setContentTabs(
    BuildContext context,
    List<CalculatorSetContentTab> tabs, {
    required bool hasMissingSetPieceAbzug,
  }) {
    return DefaultTabController(
      key: ValueKey('set-content-tabs-${tabs.map((tab) => tab.moduleRole).join('-')}'),
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: (index) {
                    setState(() => _selectedModuleTabIndex = index);
                    widget.onModuleFocusChanged(index + 1);
                    final fieldIndex =
                        _selectedGlassFieldByTab[index] ?? 0;
                    widget.onGlassFieldFocusChanged(
                      fieldIndex == 0 ? null : fieldIndex,
                    );
                  },
                  tabs: [for (final tab in tabs) Tab(text: tab.label)],
                ),
              ),
              if (hasMissingSetPieceAbzug) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Tooltip(
                      message:
                          'At least one profile has fewer pieces than the matched standard set. Review Current set delta before pricing the Abzug.',
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_outlined,
                              size: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Set quantity Abzug requires review',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                for (var tabIndex = 0; tabIndex < tabs.length; tabIndex++)
                  _SetContentTabTable(
                    contextData: widget.contextData,
                    mediaRepository: widget.mediaRepository,
                    tab: tabs[tabIndex],
                    tabIndex: tabIndex,
                    diagnostics: _diagnosticsForTab(tabs, tabIndex),
                    onToggleItem: (itemIndex) => widget.notifier.toggleSetContentItemEnabled(tabIndex, itemIndex),
                    onQuantityChanged: (itemIndex, quantity) => widget.notifier.updateSetContentItemQuantity(tabIndex, itemIndex, quantity),
                    onLengthChanged: (itemIndex, lengthMm) => widget.notifier.updateSetContentItemLength(tabIndex, itemIndex, lengthMm),
                    onOverrideChanged: (itemIndex, enabled) => widget.notifier.setSetContentItemOverride(tabIndex, itemIndex, enabled),
                    onResetItem: (itemIndex) => widget.notifier.resetSetContentItemOverride(tabIndex, itemIndex),
                    onAddManual: () => _showAddManualComponent(tabIndex),
                    selectedGlassFieldIndex: _selectedGlassFieldByTab[tabIndex] ?? 0,
                    onGlassFieldSelected: (fieldIndex) {
                      setState(() => _selectedGlassFieldByTab[tabIndex] = fieldIndex ?? 0);
                      widget.onModuleFocusChanged(tabIndex + 1);
                      widget.onGlassFieldFocusChanged(fieldIndex);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddManualComponent(int tabIndex) async {
    final candidates = widget.contextData.templateSetCatalogItemsFor(widget.draft.templateId);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Catalog Items are configured in the selected template set.'),
        ),
      );
      return;
    }

    final selection = await showDialog<_ManualComponentSelection>(
      context: context,
      builder: (_) => _ManualComponentDialog(
        candidates: candidates,
        variants: widget.contextData.templateSetCatalogVariants,
        mediaRepository: widget.mediaRepository,
      ),
    );
    if (selection == null) return;
    widget.notifier.addManualSetContentItem(
      tabIndex,
      selection.item,
      variant: selection.variant,
      quantity: selection.quantity,
      salesUnitCode: selection.salesUnitCode,
      lengthMm: selection.lengthMm,
    );
  }

  List<Map<String, dynamic>> _diagnosticsForTab(List<CalculatorSetContentTab> tabs, int tabIndex) {
    final manualBefore = tabs.take(tabIndex).fold<int>(
      0,
      (sum, tab) => sum + tab.items.where((entry) => entry.enabled && entry.isManual).length,
    );
    final manualCount = tabs[tabIndex].items.where((entry) => entry.enabled && entry.isManual).length;
    return widget.diagnostics.skip(manualBefore).take(manualCount).toList(growable: false);
  }
}


class _ManualComponentSelection {
  const _ManualComponentSelection({
    required this.item,
    required this.quantity,
    required this.salesUnitCode,
    this.variant,
    this.lengthMm,
  });

  final CalculatorCatalogItemOption item;
  final CalculatorCatalogVariantOption? variant;
  final num quantity;
  final String salesUnitCode;
  final int? lengthMm;
}

class _ManualComponentDialog extends StatefulWidget {
  const _ManualComponentDialog({
    required this.candidates,
    required this.variants,
    required this.mediaRepository,
  });

  final List<CalculatorCatalogItemOption> candidates;
  final List<CalculatorCatalogVariantOption> variants;
  final AdminResourceRepository mediaRepository;

  @override
  State<_ManualComponentDialog> createState() => _ManualComponentDialogState();
}

class _ManualComponentDialogState extends State<_ManualComponentDialog> {
  final _itemController = TextEditingController();
  final _variantController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _lengthController = TextEditingController();
  final _itemFocusNode = FocusNode();
  final _variantFocusNode = FocusNode();

  String? _itemId;
  String? _variantId;
  String? _salesUnitCode;

  @override
  void dispose() {
    _itemController.dispose();
    _variantController.dispose();
    _quantityController.dispose();
    _lengthController.dispose();
    _itemFocusNode.dispose();
    _variantFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedItem;
    final variants = item == null ? const <CalculatorCatalogVariantOption>[] : _variantsFor(item.id);
    final variant = _selectedVariant;
    final requiresVariant = item != null && variants.isNotEmpty;
    final units = _salesUnitOptions(item, variant);
    final selectedUnit = units.contains(_salesUnitCode) ? _salesUnitCode! : units.first;
    final canAdd = item != null && (!requiresVariant || variant != null);

    return AlertDialog(
      title: const Text('Add manual component from template set'),
      content: SizedBox(
        width: 780,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'All Catalog Items configured in the selected template set are available, independent of the current geometry conditions and filters. Additional handling is intentionally not available here.',
                ),
                const SizedBox(height: 14),
                _SearchableOptionField<CalculatorCatalogItemOption>(
                  label: 'Catalog item from template set',
                  hintText: 'Type article number or name',
                  controller: _itemController,
                  focusNode: _itemFocusNode,
                  options: widget.candidates,
                  displayStringForOption: _itemLabel,
                  searchStringForOption: _itemSearchText,
                  leadingBuilder: (candidate) => _CatalogNomenclatureMedia(
                    item: candidate,
                    repository: widget.mediaRepository,
                    size: 36,
                  ),
                  onSelected: _selectItem,
                ),
                if (item != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CatalogOptionMediaPreview(
                        item: item,
                        variant: variant,
                        repository: widget.mediaRepository,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(item.displayName, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 10),
                            _SearchableOptionField<CalculatorCatalogVariantOption>(
                              label: variants.isEmpty ? 'Catalog variant / SKU (none available)' : 'Catalog variant / SKU',
                              hintText: variants.isEmpty ? 'This Catalog Item has no variants' : 'Type SKU, article, color or length',
                              controller: _variantController,
                              focusNode: _variantFocusNode,
                              enabled: variants.isNotEmpty,
                              options: variants,
                              displayStringForOption: _variantLabel,
                              searchStringForOption: _variantSearchText,
                              leadingBuilder: (candidate) => _CatalogNomenclatureMedia(
                                item: item,
                                variant: candidate,
                                repository: widget.mediaRepository,
                                size: 36,
                              ),
                              onSelected: _selectVariant,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Quantity'),
                                  ),
                                ),
                                SizedBox(
                                  width: 150,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey('manual-unit-${item.id}-${variant?.id ?? ''}-$selectedUnit'),
                                    initialValue: selectedUnit,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Sales unit'),
                                    items: [
                                      for (final unit in units)
                                        DropdownMenuItem(value: unit, child: Text(_formatUnitLabel(unit))),
                                    ],
                                    onChanged: (value) => setState(() => _salesUnitCode = value),
                                  ),
                                ),
                                if (_isProfile(item))
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _lengthController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Length', suffixText: 'mm'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: canAdd ? () => _submit(item, variant, selectedUnit) : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  CalculatorCatalogItemOption? get _selectedItem => widget.candidates
      .where((entry) => entry.id == _itemId)
      .cast<CalculatorCatalogItemOption?>()
      .firstOrNull;

  CalculatorCatalogVariantOption? get _selectedVariant => widget.variants
      .where((entry) => entry.id == _variantId)
      .cast<CalculatorCatalogVariantOption?>()
      .firstOrNull;

  List<CalculatorCatalogVariantOption> _variantsFor(String itemId) => widget.variants
      .where((entry) => entry.catalogItemId == itemId)
      .toList(growable: false);

  void _selectItem(CalculatorCatalogItemOption item) {
    final variants = _variantsFor(item.id);
    final onlyVariant = variants.length == 1 ? variants.first : null;
    setState(() {
      _itemId = item.id;
      _variantId = onlyVariant?.id;
      _itemController.text = _itemLabel(item);
      _variantController.text = onlyVariant == null ? '' : _variantLabel(onlyVariant);
      _salesUnitCode = _defaultSalesUnit(item, onlyVariant);
      _lengthController.text = '${onlyVariant?.lengthMm ?? item.defaultLengthMm ?? ''}';
    });
    if (onlyVariant == null && variants.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _variantFocusNode.requestFocus();
      });
    }
  }

  void _selectVariant(CalculatorCatalogVariantOption variant) {
    final item = _selectedItem;
    setState(() {
      _variantId = variant.id;
      _variantController.text = _variantLabel(variant);
      _salesUnitCode = _defaultSalesUnit(item, variant);
      _lengthController.text = '${variant.lengthMm ?? item?.defaultLengthMm ?? ''}';
    });
  }

  void _submit(
    CalculatorCatalogItemOption item,
    CalculatorCatalogVariantOption? variant,
    String salesUnitCode,
  ) {
    final quantity = num.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    final lengthMm = _isProfile(item) ? int.tryParse(_lengthController.text.trim()) : null;
    Navigator.of(context).pop(
      _ManualComponentSelection(
        item: item,
        variant: variant,
        quantity: quantity <= 0 ? 1 : quantity,
        salesUnitCode: salesUnitCode,
        lengthMm: lengthMm,
      ),
    );
  }

  bool _isProfile(CalculatorCatalogItemOption item) => item.itemTypeCode.toLowerCase().contains('profile');

  String _itemLabel(CalculatorCatalogItemOption item) =>
      _joinDistinctTextParts([item.profileNo, item.baseCode, item.name]);

  String _itemSearchText(CalculatorCatalogItemOption item) =>
      _joinDistinctTextParts([item.profileNo, item.baseCode, item.name, item.shortName, item.itemTypeCode]);

  String _variantLabel(CalculatorCatalogVariantOption variant) => _joinDistinctTextParts([
        variant.variantSku,
        variant.articleNo,
        variant.profileNo,
        variant.colorName,
        variant.colorCode,
        _formatLengthMm(variant.lengthMm),
      ]);

  String _variantSearchText(CalculatorCatalogVariantOption variant) => _joinDistinctTextParts([
        _variantLabel(variant),
        variant.systemCode,
        variant.systemName,
        variant.glassTypeCode,
        variant.coatingTypeCode,
      ]);

  List<String> _salesUnitOptions(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
  ) {
    final values = <String?>[
      ...?variant?.allowedSalesUnitCodes,
      ...?item?.allowedSalesUnitCodes,
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
    for (final value in values) {
      final normalized = _normalizeUnitCode(value);
      if (normalized == null || result.contains(normalized)) continue;
      result.add(normalized);
    }
    return result.isEmpty ? const ['piece'] : result;
  }

  String _defaultSalesUnit(
    CalculatorCatalogItemOption? item,
    CalculatorCatalogVariantOption? variant,
  ) {
    final units = _salesUnitOptions(item, variant);
    for (final value in [
      variant?.defaultSalesUnitCode,
      item?.defaultSalesUnitCode,
      item?.measureTypeCode,
    ]) {
      final normalized = _normalizeUnitCode(value);
      if (normalized != null && units.contains(normalized)) return normalized;
    }
    return units.first;
  }

  String? _normalizeUnitCode(String? value) {
    final text = value?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (text == null || text.isEmpty) return null;
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
}

const _missingSetPieceAbzugArticleNos = {'15698', '15184', '15189'};

String _bomArticleNo(Map<String, dynamic> line) {
  return '${line['article_no'] ?? line['profile_no'] ?? ''}'.trim();
}

bool _isMissingSetPieceAbzugCase(Map<String, dynamic> line) {
  final source = line['source'] is Map
      ? Map<String, dynamic>.from(line['source'] as Map)
      : const <String, dynamic>{};
  if (source['legacy_missing_set_piece_abzug_case'] == true) return true;
  return source['delta_kind'] == 'abzug' &&
      _missingSetPieceAbzugArticleNos.contains(_bomArticleNo(line)) &&
      _num(source['legacy_missing_standard_pieces']) > 0;
}

class _BomSummaryList extends StatefulWidget {
  const _BomSummaryList({
    required this.contextData,
    required this.mediaRepository,
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.lines,
    this.showDeltaDirection = false,
    this.includedMissingSetPieceAbzugArticleNos = const {},
    this.onSetMissingSetPieceAbzugForArticles,
    this.onSetMissingSetPieceAbzugForArticle,
  });

  final CalculatorContext contextData;
  final AdminResourceRepository mediaRepository;
  final String title;
  final String subtitle;
  final String emptyText;
  final List<Map<String, dynamic>> lines;
  final bool showDeltaDirection;
  final Set<String> includedMissingSetPieceAbzugArticleNos;
  final void Function(Iterable<String> articleNos, bool included)?
      onSetMissingSetPieceAbzugForArticles;
  final void Function(String articleNo, bool included)?
      onSetMissingSetPieceAbzugForArticle;

  @override
  State<_BomSummaryList> createState() => _BomSummaryListState();
}

class _BomSummaryListState extends State<_BomSummaryList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missingSetPieceCases = widget.lines
        .where(_isMissingSetPieceAbzugCase)
        .toList(growable: false);
    final missingSetPieceArticles = missingSetPieceCases
        .map(_bomArticleNo)
        .where((article) => article.isNotEmpty)
        .toSet();
    final allMissingSetPieceAbzugIncluded =
        missingSetPieceArticles.isNotEmpty &&
        missingSetPieceArticles.every(
          widget.includedMissingSetPieceAbzugArticleNos.contains,
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (missingSetPieceArticles.isNotEmpty &&
                        widget.onSetMissingSetPieceAbzugForArticles != null)
                      Tooltip(
                        message:
                            'Include or exclude all Abzug positions where the calculated set contains fewer pieces than the matched standard set.',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Include all set shortage Abzug',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(width: 4),
                            Switch.adaptive(
                              value: allMissingSetPieceAbzugIncluded,
                              onChanged: (value) => widget
                                  .onSetMissingSetPieceAbzugForArticles!(
                                missingSetPieceArticles,
                                value,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          if (missingSetPieceArticles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 11, 4),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'Include in price',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 5),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          if (widget.lines.isEmpty)
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(widget.emptyText))))
          else
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  itemCount: widget.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = widget.lines[index];
                    final articleNo = _bomArticleNo(line);
                    final isMissingSetPieceCase =
                        _isMissingSetPieceAbzugCase(line);
                    return ListTile(
                      dense: true,
                      leading: _CatalogNomenclatureMedia(
                        item: _catalogItemForBomLine(widget.contextData, line),
                        repository: widget.mediaRepository,
                      ),
                      title: Text('${line['article_no'] ?? line['profile_no'] ?? '—'} · ${line['name'] ?? 'Component'}'),
                      subtitle: Text(_bomLineDescription(line)),
                      trailing: _BomSummaryTrailing(
                        quantityText: '${_num(line['quantity'])} ${_formatUnitLabel('${line['unit_code'] ?? 'piece'}')}',
                        deltaKind: widget.showDeltaDirection ? _deltaKind(line) : null,
                        includeMissingSetPieceAbzug:
                            isMissingSetPieceCase
                                ? widget
                                    .includedMissingSetPieceAbzugArticleNos
                                    .contains(articleNo)
                                : null,
                        onIncludeMissingSetPieceAbzugChanged:
                            isMissingSetPieceCase &&
                                    articleNo.isNotEmpty &&
                                    widget.onSetMissingSetPieceAbzugForArticle !=
                                        null
                                ? (value) => widget
                                    .onSetMissingSetPieceAbzugForArticle!(
                                      articleNo,
                                      value,
                                    )
                                : null,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _deltaKind(Map<String, dynamic> line) {
    final source = line['source'] is Map
        ? Map<String, dynamic>.from(line['source'] as Map)
        : const <String, dynamic>{};
    final kind = '${source['delta_kind'] ?? ''}'.trim().toLowerCase();
    if (kind == 'positive' || kind == 'abzug') return kind;
    return null;
  }

  String _bomLineDescription(Map<String, dynamic> line) {
    final source = line['source'] is Map ? Map<String, dynamic>.from(line['source'] as Map) : const <String, dynamic>{};
    final kind = source['delta_kind']?.toString();
    if (kind != null) {
      return 'Standard ${source['standard_quantity'] ?? '—'} · calculated ${source['calculated_quantity'] ?? '—'} · $kind';
    }
    final segments = line['segments'] is List ? line['segments'] as List : const [];
    if (segments.isEmpty) return '${source['source_type'] ?? 'standard_set'}';
    return segments.whereType<Map>().map((raw) {
      final segment = Map<String, dynamic>.from(raw);
      return '${segment['module'] ?? 'main'}: ${segment['quantity'] ?? 0} × ${_formatLengthNumber(_num(segment['length_mm']))} mm';
    }).join(' · ');
  }
}

class _BomSummaryTrailing extends StatelessWidget {
  const _BomSummaryTrailing({
    required this.quantityText,
    required this.deltaKind,
    this.includeMissingSetPieceAbzug,
    this.onIncludeMissingSetPieceAbzugChanged,
  });

  final String quantityText;
  final String? deltaKind;
  final bool? includeMissingSetPieceAbzug;
  final ValueChanged<bool>? onIncludeMissingSetPieceAbzugChanged;

  @override
  Widget build(BuildContext context) {
    final isPositive = deltaKind == 'positive';
    final isAbzug = deltaKind == 'abzug';
    if (!isPositive && !isAbzug && includeMissingSetPieceAbzug == null) {
      return Text(quantityText);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final icon = isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final color = isPositive ? colorScheme.primary : colorScheme.error;
    final tooltip = isPositive ? 'Positive set delta' : 'Abzug';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (includeMissingSetPieceAbzug != null) ...[
          SizedBox(
            width: 40,
            child: Tooltip(
              message: includeMissingSetPieceAbzug!
                  ? 'This missing-set-quantity Abzug is included in price.'
                  : 'This missing-set-quantity Abzug is excluded from price.',
              child: Checkbox(
                value: includeMissingSetPieceAbzug,
                onChanged: onIncludeMissingSetPieceAbzugChanged == null
                    ? null
                    : (value) => onIncludeMissingSetPieceAbzugChanged!(
                          value ?? false,
                        ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(quantityText),
        if (isPositive || isAbzug) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltip,
            child: Icon(icon, size: 18, color: color),
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      avatar: onTap == null ? null : const Icon(Icons.open_in_new, size: 15),
      label: Text('$label: $value', overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: chip,
    );
  }
}


List<CalculatorCatalogItemOption> _catalogItemsForBomLines(
  CalculatorContext contextData,
  List<Map<String, dynamic>> lines,
) {
  final result = <CalculatorCatalogItemOption>[];
  final seen = <String>{};
  for (final line in lines) {
    final item = _catalogItemForBomLine(contextData, line);
    if (item == null || !seen.add(item.id)) continue;
    result.add(item);
  }
  result.sort((a, b) => '${a.profileNo ?? a.baseCode} ${a.name}'.compareTo('${b.profileNo ?? b.baseCode} ${b.name}'));
  return result;
}

CalculatorCatalogItemOption? _catalogItemForBomLine(
  CalculatorContext contextData,
  Map<String, dynamic> line,
) {
  final source = line['source'] is Map
      ? Map<String, dynamic>.from(line['source'] as Map)
      : line['source_component'] is Map
          ? Map<String, dynamic>.from(line['source_component'] as Map)
          : const <String, dynamic>{};
  return _findCatalogItem(
    contextData,
    id: _stringFromRaw(line['catalog_item_id'] ?? source['catalog_item_id']),
    codes: [
      _stringFromRaw(line['article_no']),
      _stringFromRaw(line['profile_no']),
      _stringFromRaw(line['base_code']),
      _stringFromRaw(source['article_no']),
      _stringFromRaw(source['profile_no']),
      _stringFromRaw(source['base_code']),
      _stringFromRaw(source['target_code']),
    ],
  );
}

CalculatorCatalogItemOption? _catalogItemForSetContent(
  CalculatorContext contextData,
  CalculatorSetContentItem item,
) {
  return _findCatalogItem(
    contextData,
    id: item.catalogItemId,
    codes: [item.articleNo, item.profileNo, item.baseCode],
  );
}

CalculatorCatalogItemOption? _findCatalogItem(
  CalculatorContext contextData, {
  String? id,
  Iterable<String?> codes = const [],
}) {
  final normalizedId = id?.trim();
  final allCatalogItems = <CalculatorCatalogItemOption>[
    ...contextData.optionCatalogItems,
    ...contextData.templateSetCatalogItems,
  ];
  CalculatorCatalogItemOption? idMatch;
  if (normalizedId != null && normalizedId.isNotEmpty) {
    idMatch = allCatalogItems
        .where((entry) => entry.id == normalizedId)
        .cast<CalculatorCatalogItemOption?>()
        .firstOrNull;
    if (idMatch != null && _catalogItemHasMedia(idMatch)) return idMatch;
  }

  final wanted = <String>{};
  for (final code in codes) {
    wanted.addAll(_catalogCodeKeys(code));
  }
  if (wanted.isEmpty) return idMatch;

  CalculatorCatalogItemOption? canonicalMatch;
  CalculatorCatalogItemOption? prefixedMatch;
  for (final item in allCatalogItems) {
    final itemKeys = <String>{
      ..._catalogCodeKeys(item.profileNo),
      ..._catalogCodeKeys(item.baseCode),
      ..._catalogCodeKeys(_stringFromRaw(item.raw['article_no'])),
    };
    if (itemKeys.intersection(wanted).isEmpty) continue;
    final baseCode = item.baseCode.trim();
    if (!baseCode.contains(':')) {
      if (_catalogItemHasMedia(item)) return item;
      canonicalMatch ??= item;
    } else {
      prefixedMatch ??= item;
    }
  }
  return canonicalMatch ?? idMatch ?? prefixedMatch;
}

bool _catalogItemHasMedia(CalculatorCatalogItemOption item) {
  return (item.mediaLargeFileId?.trim().isNotEmpty ?? false)
      || (item.mediaFileId?.trim().isNotEmpty ?? false);
}

Set<String> _catalogCodeKeys(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return const <String>{};
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  final result = <String>{compact};
  final separator = compact.lastIndexOf(':');
  if (separator >= 0 && separator < compact.length - 1) {
    result.add(compact.substring(separator + 1));
  }
  return result;
}

class _CatalogNomenclatureMedia extends StatelessWidget {
  const _CatalogNomenclatureMedia({
    required this.item,
    required this.repository,
    this.variant,
    this.size = 40,
  });

  final CalculatorCatalogItemOption? item;
  final CalculatorCatalogVariantOption? variant;
  final AdminResourceRepository repository;
  final double size;

  @override
  Widget build(BuildContext context) {
    final catalogItem = item;
    if (catalogItem == null) {
      return _SectionPreviewPlaceholder(size: size);
    }
    return _CatalogOptionMediaPreview(
      item: catalogItem,
      variant: variant,
      repository: repository,
      size: size,
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
    if (item.isDerivedOverride || _isAccessorySetContentItem(contextData, item)) continue;
    rows.add(_SetContentVisibleRow(itemIndex: i, item: item));
  }
  return rows;
}

class _SetContentTabTable extends StatefulWidget {
  const _SetContentTabTable({
    required this.contextData,
    required this.mediaRepository,
    required this.tab,
    required this.tabIndex,
    required this.diagnostics,
    required this.onQuantityChanged,
    required this.onLengthChanged,
    required this.onToggleItem,
    required this.onOverrideChanged,
    required this.onResetItem,
    required this.onAddManual,
    required this.selectedGlassFieldIndex,
    required this.onGlassFieldSelected,
  });

  static const _mediaWidth = 48.0;
  static const _profileWidth = 76.0;
  static const _qtyWidth = 88.0;
  static const _unitWidth = 58.0;
  static const _lengthWidth = 116.0;
  static const _stateWidth = 132.0;
  static const _actionsWidth = 88.0;
  static const _columnGap = 12.0;

  final CalculatorContext contextData;
  final AdminResourceRepository mediaRepository;
  final CalculatorSetContentTab tab;
  final int tabIndex;
  final List<Map<String, dynamic>> diagnostics;
  final void Function(int itemIndex, num quantity) onQuantityChanged;
  final void Function(int itemIndex, num? lengthMm) onLengthChanged;
  final void Function(int itemIndex) onToggleItem;
  final void Function(int itemIndex, bool enabled) onOverrideChanged;
  final void Function(int itemIndex) onResetItem;
  final VoidCallback onAddManual;
  final int selectedGlassFieldIndex;
  final ValueChanged<int?> onGlassFieldSelected;

  @override
  State<_SetContentTabTable> createState() => _SetContentTabTableState();
}

class _SetContentTabTableState extends State<_SetContentTabTable> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _SetContentTabTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fieldCount = widget.tab.geometryInt('glass_depth_field_count') ?? 1;
    if (widget.selectedGlassFieldIndex > fieldCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onGlassFieldSelected(null);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRows = _visibleSetContentRows(widget.contextData, widget.tab);
    final fieldCount = widget.tab.geometryInt('glass_depth_field_count') ?? 1;
    final selectedGlassFieldIndex = widget.selectedGlassFieldIndex <= fieldCount
        ? widget.selectedGlassFieldIndex
        : 0;
    final rows = selectedGlassFieldIndex == 0
        ? allRows
        : allRows
            .where(
              (row) =>
                  row.item.glassFieldIndex == selectedGlassFieldIndex ||
                  row.item.cutGroupIndex == selectedGlassFieldIndex,
            )
            .toList(growable: false);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.tab.label} · ${rows.where((row) => row.item.isCalculated).length} calculated · ${rows.where((row) => row.item.isManual).length} manual',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (fieldCount > 1) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 390,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('glass-field-filter-${widget.tabIndex}-$fieldCount-$selectedGlassFieldIndex'),
                      initialValue: selectedGlassFieldIndex,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Production split by depth',
                        isDense: true,
                      ),
                      items: _glassFieldOptions(fieldCount),
                      onChanged: (value) {
                        final next = value ?? 0;
                        widget.onGlassFieldSelected(next == 0 ? null : next);
                      },
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: widget.onAddManual,
                  tooltip: 'Manual component',
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(height: 34, child: _header(context)),
          const Divider(height: 1),
          if (rows.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  selectedGlassFieldIndex == 0
                      ? 'No calculated or manual profile segments in this module.'
                      : 'No component segments are assigned to Glass field or cut group $selectedGlassFieldIndex/$fieldCount.',
                ),
              ),
            )
          else
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _row(context, rows[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _fixed(context, const Text('Media'), _SetContentTabTable._mediaWidth, true),
            _gap(),
            _fixed(context, const Text('Profile'), _SetContentTabTable._profileWidth, true),
            _gap(),
            _expanded(context, const Text('Name / source'), true),
            _gap(),
            _fixed(context, const Text('Qty'), _SetContentTabTable._qtyWidth, true),
            _gap(),
            _fixed(context, const Text('Unit'), _SetContentTabTable._unitWidth, true),
            _gap(),
            _fixed(context, const Text('Cut length'), _SetContentTabTable._lengthWidth, true),
            _gap(),
            _fixed(context, const Text('Stock / state'), _SetContentTabTable._stateWidth, true),
            _gap(),
            const SizedBox(width: _SetContentTabTable._actionsWidth),
          ],
        ),
      );

  Widget _row(BuildContext context, _SetContentVisibleRow visible) {
    final item = visible.item;
    final index = visible.itemIndex;
    final editable = item.isManual || item.isOverridden;
    final manualIndex = widget.tab.items.take(index).where((entry) => entry.enabled && entry.isManual).length;
    final diagnostic = item.isManual && manualIndex < widget.diagnostics.length ? widget.diagnostics[manualIndex] : null;
    final amount = _num(diagnostic?['amount']);
    final colorScheme = Theme.of(context).colorScheme;
    final sourceLabel = item.isCalculated
        ? (item.overrideState == 'excluded'
            ? 'Calculated · excluded'
            : item.isOverridden
                ? 'Calculated · overridden'
                : 'Calculated · automatic')
        : 'Manual component';
    final productionLabel = item.glassFieldIndex != null && item.glassFieldCount != null
        ? 'Glass field ${item.glassFieldIndex}/${item.glassFieldCount}'
        : item.cutGroupIndex != null && (item.cutGroupCount ?? 1) > 1
            ? 'Cut group ${item.cutGroupIndex}/${item.cutGroupCount}'
            : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      color: item.enabled ? Colors.transparent : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          _fixed(
            context,
            _CatalogNomenclatureMedia(
              item: _catalogItemForSetContent(widget.contextData, item),
              repository: widget.mediaRepository,
            ),
            _SetContentTabTable._mediaWidth,
          ),
          _gap(),
          _fixed(context, Text(item.profileNo ?? item.articleNo ?? item.baseCode ?? '—'), _SetContentTabTable._profileWidth),
          _gap(),
          _expanded(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.name ?? 'Component', maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [sourceLabel, if (productionLabel != null) productionLabel, if (item.segmentId != null) item.segmentId!].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _gap(),
          _fixed(
            context,
            TextFormField(
              key: ValueKey('set-qty-${widget.tabIndex}-$index-${item.quantity}-${item.overrideState}'),
              initialValue: _formatInputQuantity(item.quantity),
              enabled: item.enabled && editable,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
              onChanged: (value) => widget.onQuantityChanged(index, num.tryParse(value.replaceAll(',', '.')) ?? item.quantity),
            ),
            _SetContentTabTable._qtyWidth,
          ),
          _gap(),
          _fixed(context, Text(_formatUnitLabel(item.salesUnitCode ?? item.unitCode ?? 'piece')), _SetContentTabTable._unitWidth),
          _gap(),
          _fixed(
            context,
            item.isProfile
                ? TextFormField(
                    key: ValueKey('set-length-${widget.tabIndex}-$index-${item.lengthMm}-${item.overrideState}'),
                    initialValue: item.lengthMm == null ? '' : _formatDecimalNumber(item.lengthMm!),
                    enabled: item.enabled && editable,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, suffixText: 'mm'),
                    onChanged: (value) => widget.onLengthChanged(
                      index,
                      num.tryParse(value.trim().replaceAll(',', '.')),
                    ),
                  )
                : Text(_formatLengthMm(item.lengthMm) ?? '—'),
            _SetContentTabTable._lengthWidth,
          ),
          _gap(),
          _fixed(
            context,
            item.isCalculated
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.stockLengthMm == null ? 'Stock —' : 'Stock ${item.stockLengthMm} mm'),
                      Text('Base / delta', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  )
                : Text(amount != 0 ? _moneyFormat.format(amount) : 'Manual'),
            _SetContentTabTable._stateWidth,
          ),
          _gap(),
          SizedBox(
            width: _SetContentTabTable._actionsWidth,
            child: Row(
              children: [
                if (item.isCalculated)
                  IconButton(
                    tooltip: item.isOverridden ? 'Reset to calculated values' : 'Override calculated values',
                    onPressed: item.isOverridden
                        ? () => widget.onResetItem(index)
                        : () => widget.onOverrideChanged(index, true),
                    icon: Icon(item.isOverridden ? Icons.restart_alt : Icons.edit_outlined, size: 20),
                  )
                else
                  const SizedBox(width: 40),
                IconButton(
                  tooltip: item.enabled ? 'Exclude segment' : 'Include segment',
                  onPressed: () => widget.onToggleItem(index),
                  icon: Icon(item.enabled ? Icons.check_circle_outline : Icons.remove_circle_outline, size: 20),
                  color: item.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(width: _SetContentTabTable._columnGap);

  List<DropdownMenuItem<int>> _glassFieldOptions(int fieldCount) {
    final totalGlassCount = widget.tab.geometryInt('glass_count') ?? 0;
    final glassCountAcrossWidth = widget.tab.geometryInt('glass_count_across_width') ??
        (fieldCount > 0 ? (totalGlassCount / fieldCount).round() : totalGlassCount);
    final glassWidthMm = widget.tab.geometryInt('glass_width_mm');
    final glassLengthMm = widget.tab.geometryInt('glass_length_mm');
    final sizeText = '${glassWidthMm ?? '—'} × ${glassLengthMm ?? '—'} mm';

    return [
      DropdownMenuItem<int>(
        value: 0,
        child: Text(
          'All fields · $fieldCount fields · $totalGlassCount sheets',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      for (var fieldIndex = 1; fieldIndex <= fieldCount; fieldIndex++)
        DropdownMenuItem<int>(
          value: fieldIndex,
          child: Text(
            'Glass field $fieldIndex/$fieldCount · $glassCountAcrossWidth sheets · $sizeText',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  Widget _fixed(BuildContext context, Widget child, double width, [bool header = false]) => SizedBox(
        width: width,
        child: DefaultTextStyle.merge(
          style: header ? Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700) : Theme.of(context).textTheme.bodySmall,
          child: child,
        ),
      );

  Widget _expanded(BuildContext context, Widget child, [bool header = false]) => Expanded(
        flex: 5,
        child: DefaultTextStyle.merge(
          style: header ? Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700) : Theme.of(context).textTheme.bodySmall,
          child: child,
        ),
      );
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
    required this.derivedAccessories,
    required this.derivedDiagnostics,
    required this.manualDiagnostics,
    required this.mediaRepository,
    required this.weights,
    required this.onFastenersPressed,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final List<Map<String, dynamic>> derivedAccessories;
  final List<Map<String, dynamic>> derivedDiagnostics;
  final List<Map<String, dynamic>> manualDiagnostics;
  final AdminResourceRepository mediaRepository;
  final Map<String, dynamic> weights;
  final VoidCallback onFastenersPressed;

  @override
  Widget build(BuildContext context) {
    final lines = _accessoryDisplayLines(
      contextData,
      draft,
      derivedAccessories,
      derivedDiagnostics,
      manualDiagnostics,
    );
    final totalAmount = lines.fold<num>(0, (sum, line) => sum + line.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Accessory / Derived Zubehör', style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(width: 12),
            FilledButton.tonal(onPressed: onFastenersPressed, child: const Text('+ Fasteners')),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Required accessories are recalculated from the effective profile BOM after segment overrides: PVC fittings from PVC pipes, stopplates from beams, wall seal from wall-profile metres and glass seal from beam, glass-list, side-list, gutter and wall-profile lengths. Manual accessory items remain separate.',
        ),
        const SizedBox(height: 12),
        if (lines.isEmpty)
          const _HintCard(
            icon: Icons.build_outlined,
            title: 'No derived accessories',
            text: 'Complete Dimensions and Set contents first. Derived accessories appear as soon as the effective BOM contains their source profiles.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'Derived', value: '${lines.where((line) => line.isDerived).length}'),
              _InfoChip(label: 'Manual', value: '${lines.where((line) => !line.isDerived).length}'),
              _InfoChip(label: 'Priced', value: '${lines.where((line) => line.hasAmount).length}'),
              _InfoChip(label: 'Cost', value: totalAmount == 0 ? '—' : _moneyFormat.format(totalAmount)),
              if (weights.isNotEmpty)
                _InfoChip(label: 'Weight', value: _weightText(weights, 'accessories_kg', 'accessories_complete')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      children: [
                        const SizedBox(width: 48, child: Text('Media')),
                        const SizedBox(width: 10),
                        const SizedBox(width: 84, child: Text('Article')),
                        const Expanded(child: Text('Name / source')),
                        const SizedBox(width: 90, child: Text('Qty')),
                        const SizedBox(width: 12),
                        const SizedBox(width: 70, child: Text('Unit')),
                        const SizedBox(width: 100, child: Text('Price')),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _AccessoryDisplayRow(
                        contextData: contextData,
                        mediaRepository: mediaRepository,
                        line: lines[index],
                        onQuantityChanged: (quantity) {
                          final line = lines[index];
                          if (line.isDerived) {
                            notifier.upsertDerivedAccessoryOverride(line.raw, quantity, line.enabled);
                          } else if (line.tabIndex != null && line.itemIndex != null) {
                            notifier.updateSetContentItemQuantity(line.tabIndex!, line.itemIndex!, quantity);
                          }
                        },
                        onToggle: () {
                          final line = lines[index];
                          if (line.isDerived) {
                            notifier.upsertDerivedAccessoryOverride(line.raw, line.quantity, !line.enabled);
                          } else if (line.tabIndex != null && line.itemIndex != null) {
                            notifier.toggleSetContentItemEnabled(line.tabIndex!, line.itemIndex!);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccessoryDisplayLine {
  const _AccessoryDisplayLine({
    required this.raw,
    required this.name,
    required this.articleNo,
    required this.quantity,
    required this.unitCode,
    required this.sourceText,
    required this.isDerived,
    required this.enabled,
    required this.amount,
    required this.hasAmount,
    this.tabIndex,
    this.itemIndex,
  });

  final Map<String, dynamic> raw;
  final String name;
  final String articleNo;
  final num quantity;
  final String unitCode;
  final String sourceText;
  final bool isDerived;
  final bool enabled;
  final num amount;
  final bool hasAmount;
  final int? tabIndex;
  final int? itemIndex;
}

List<_AccessoryDisplayLine> _accessoryDisplayLines(
  CalculatorContext contextData,
  CalculatorDraft draft,
  List<Map<String, dynamic>> derived,
  List<Map<String, dynamic>> derivedDiagnostics,
  List<Map<String, dynamic>> manualDiagnostics,
) {
  final overrideBySegment = <String, CalculatorSetContentItem>{};
  final manual = <_AccessoryDisplayLine>[];
  var manualDiagnosticIndex = 0;
  for (var tabIndex = 0; tabIndex < draft.setContents.length; tabIndex++) {
    final tab = draft.setContents[tabIndex];
    for (var itemIndex = 0; itemIndex < tab.items.length; itemIndex++) {
      final item = tab.items[itemIndex];
      if (item.isDerivedOverride && item.segmentId != null) {
        overrideBySegment[item.segmentId!] = item;
        continue;
      }
      if (!item.isManual) continue;
      final diagnostic = item.enabled && manualDiagnosticIndex < manualDiagnostics.length
          ? manualDiagnostics[manualDiagnosticIndex]
          : null;
      if (item.enabled) manualDiagnosticIndex += 1;
      if (!_isAccessorySetContentItem(contextData, item)) continue;
      manual.add(_AccessoryDisplayLine(
        raw: item.raw,
        name: item.name ?? 'Manual accessory',
        articleNo: item.articleNo ?? item.profileNo ?? item.baseCode ?? '—',
        quantity: item.quantity,
        unitCode: item.salesUnitCode ?? item.unitCode ?? 'piece',
        sourceText: '${tab.label} · manual',
        isDerived: false,
        enabled: item.enabled,
        amount: _num(diagnostic?['amount']),
        hasAmount: diagnostic != null && diagnostic.containsKey('amount'),
        tabIndex: tabIndex,
        itemIndex: itemIndex,
      ));
    }
  }

  final result = <_AccessoryDisplayLine>[];
  for (var i = 0; i < derived.length; i++) {
    final line = derived[i];
    final source = line['source'] is Map ? Map<String, dynamic>.from(line['source'] as Map) : const <String, dynamic>{};
    final segments = line['segments'] is List ? line['segments'] as List : const [];
    final segment = segments.isNotEmpty && segments.first is Map
        ? Map<String, dynamic>.from(segments.first as Map)
        : const <String, dynamic>{};
    final segmentId = '${segment['segment_id'] ?? ''}';
    final override = overrideBySegment[segmentId];
    final diagnostic = i < derivedDiagnostics.length ? derivedDiagnostics[i] : null;
    final derivedFrom = source['derived_from'] is List
        ? (source['derived_from'] as List).map((entry) => '$entry').join(', ')
        : '${source['derived_from'] ?? 'calculated BOM'}';
    result.add(_AccessoryDisplayLine(
      raw: line,
      name: '${line['name'] ?? 'Accessory'}',
      articleNo: '${line['article_no'] ?? line['profile_no'] ?? '—'}',
      quantity: override?.quantity ?? _num(line['quantity']),
      unitCode: '${line['unit_code'] ?? 'piece'}',
      sourceText: 'Derived from $derivedFrom',
      isDerived: true,
      enabled: override?.enabled ?? true,
      amount: _num(diagnostic?['amount']),
      hasAmount: diagnostic != null && diagnostic.containsKey('amount'),
    ));
  }
  result.addAll(manual);
  return result;
}

class _AccessoryDisplayRow extends StatelessWidget {
  const _AccessoryDisplayRow({
    required this.contextData,
    required this.mediaRepository,
    required this.line,
    required this.onQuantityChanged,
    required this.onToggle,
  });

  final CalculatorContext contextData;
  final AdminResourceRepository mediaRepository;
  final _AccessoryDisplayLine line;
  final ValueChanged<num> onQuantityChanged;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: line.enabled ? 1 : 0.48,
      duration: const Duration(milliseconds: 140),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: _CatalogNomenclatureMedia(
                item: _catalogItemForBomLine(contextData, line.raw),
                repository: mediaRepository,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 84, child: Text(line.articleNo)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.name),
                  Text(line.sourceText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: TextFormField(
                key: ValueKey('derived-accessory-${line.articleNo}-${line.quantity}-${line.enabled}'),
                initialValue: _formatInputQuantity(line.quantity),
                enabled: line.enabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onChanged: (value) => onQuantityChanged(num.tryParse(value.replaceAll(',', '.')) ?? line.quantity),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 70, child: Text(_formatUnitLabel(line.unitCode))),
            SizedBox(width: 100, child: Text(line.hasAmount ? _moneyFormat.format(line.amount) : '—')),
            IconButton(
              tooltip: line.enabled ? 'Exclude accessory' : 'Include accessory',
              onPressed: onToggle,
              icon: Icon(line.enabled ? Icons.check_circle_outline : Icons.remove_circle_outline),
              color: line.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsStep extends StatefulWidget {
  const _OptionsStep({
    required this.contextData,
    required this.draft,
    required this.notifier,
    required this.optionDiagnostics,
    required this.mediaRepository,
    required this.weights,
  });

  final CalculatorContext contextData;
  final CalculatorDraft draft;
  final CalculatorDraftNotifier notifier;
  final List<Map<String, dynamic>> optionDiagnostics;
  final AdminResourceRepository mediaRepository;
  final Map<String, dynamic> weights;

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
        if (widget.weights.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _InfoChip(
              label: 'Options / Zusätzliche Artikeln weight',
              value: _weightText(widget.weights, 'options_kg', 'options_complete'),
            ),
          ),
        ],
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
                leadingBuilder: (item) => _CatalogNomenclatureMedia(
                  item: item,
                  repository: widget.mediaRepository,
                  size: 36,
                ),
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
                      leadingBuilder: (variant) => _CatalogNomenclatureMedia(
                        item: selectedItem,
                        variant: variant,
                        repository: widget.mediaRepository,
                        size: 36,
                      ),
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
          mediaRepository: widget.mediaRepository,
          options: widget.draft.options,
          optionDiagnostics: widget.optionDiagnostics,
          onQuantityChanged: widget.notifier.updateOptionQuantity,
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
  const _SectionPreviewPlaceholder({this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) {
    final compact = size < 64;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: compact
          ? const Icon(Icons.image_not_supported_outlined, size: 18)
          : const Column(
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
    this.size = 104,
  });

  final CalculatorCatalogItemOption item;
  final CalculatorCatalogVariantOption? variant;
  final AdminResourceRepository repository;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mediaRef = _mediaFileRef;
    if (mediaRef == null) {
      return _SectionPreviewPlaceholder(size: size);
    }

    return _CatalogOptionMediaFrame(
      mediaRef: mediaRef,
      detailMediaRef: _detailMediaFileRef ?? mediaRef,
      repository: repository,
      size: size,
      showPreviewAction: size >= 64,
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
    this.size = 104,
    this.showPreviewAction = true,
  });

  final MediaFileRef mediaRef;
  final MediaFileRef detailMediaRef;
  final AdminResourceRepository repository;
  final double size;
  final bool showPreviewAction;

  @override
  State<_CatalogOptionMediaFrame> createState() => _CatalogOptionMediaFrameState();
}

class _CatalogOptionMediaFrameState extends State<_CatalogOptionMediaFrame> {
  late Future<ApiBinaryResponse> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _catalogMediaFuture(widget.repository, widget.mediaRef.fileId);
  }

  @override
  void didUpdateWidget(covariant _CatalogOptionMediaFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaRef.fileId != widget.mediaRef.fileId) {
      _imageFuture = _catalogMediaFuture(widget.repository, widget.mediaRef.fileId);
    }
  }

  void _openPreview() {
    showDialog<void>(
      context: context,
      builder: (_) => MediaPreviewDialog(
        repository: widget.repository,
        files: [widget.detailMediaRef],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openPreview,
      child: Container(
        width: widget.size,
        height: widget.size,
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
            if (widget.showPreviewAction)
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
                    onPressed: _openPreview,
                    icon: const Icon(Icons.open_in_full_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedOptionsTable extends StatelessWidget {
  const _SelectedOptionsTable({
    required this.contextData,
    required this.mediaRepository,
    required this.options,
    required this.optionDiagnostics,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CalculatorContext contextData;
  final AdminResourceRepository mediaRepository;
  final List<CalculatorSelectedOption> options;
  final List<Map<String, dynamic>> optionDiagnostics;
  final void Function(int index, num quantity) onQuantityChanged;
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
          _cell(context, const Text('Media'), width: 48, header: true),
          _cell(context, const Text('Profile no'), width: 74, header: true),
          _cell(context, const Text('Name / additional handling'), flex: 5, header: true),
          _cell(context, const Text('Qty'), width: 64, header: true),
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
          _cell(
            context,
            _CatalogNomenclatureMedia(
              item: item,
              variant: variant,
              repository: mediaRepository,
            ),
            width: 48,
          ),
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
          _cell(
            context,
            TextFormField(
              key: ValueKey('selected-option-qty-$index-${option.catalogItemId ?? option.optionCode ?? ''}-${option.catalogVariantId ?? ''}'),
              initialValue: _formatInputQuantity(option.quantity),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
              onChanged: (value) => onQuantityChanged(index, num.tryParse(value.replaceAll(',', '.')) ?? option.quantity),
            ),
            width: 64,
          ),
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
    required this.selectedRoofModel,
    required this.coveringName,
  });

  final CalculatorDraft draft;
  final CalculatorTemplateOption? selectedTemplate;
  final CalculatorOption? selectedRoofModel;
  final String? coveringName;

  @override
  Widget build(BuildContext context) {
    final roofCalculation = calculateRoofGeometryForDraft(
      draft: draft,
      template: selectedTemplate,
      model: selectedRoofModel,
    );
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
        _SummaryRow('Covering', coveringName ?? '—'),
        _SummaryRow('Color', draft.colorCode ?? '—'),
        _SummaryRow(
          'Delivery',
          [draft.handoverTypeCode, if (draft.completionWeek != null) 'Fertigst. KW ${draft.completionWeek}']
              .whereType<String>()
              .join(' · '),
        ),
        _SummaryRow('Options', draft.options.isEmpty ? '—' : '${draft.options.length} selected'),
        if (roofCalculation.angleDeg != null)
          _SummaryRow('Roof angle', '${roofCalculation.angleDeg}°'),
        for (final module in roofCalculation.modules) ...[
          _SummaryRow(
            '${_moduleDisplayLabel(module.role, module.moduleIndex)} beams',
            '${module.beamCount} × ${module.beamLengthMm} mm · glass offset ${module.glassCountOffset > 0 ? '+' : ''}${module.glassCountOffset}',
          ),
          _SummaryRow(
            '${_moduleDisplayLabel(module.role, module.moduleIndex)} glass',
            '${module.glassCount} × ${module.glassWidthMm} × ${module.glassLengthMm} mm · ${module.glassAreaM2.toStringAsFixed(1)} m²',
          ),
        ],
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
    required this.calculatorContext,
    required this.roofModelState,
    required this.selectedStep,
    required this.highlightedModuleIndex,
    required this.highlightedGlassFieldIndex,
    required this.mediaRepository,
    required this.onSaveQuote,
    required this.onPrint,
    required this.isSavingQuote,
    required this.calculationNumber,
    required this.isCalculationSaved,
    required this.needsRecalculation,
    this.loadedQuote,
    this.savedQuote,
  });

  final AsyncValue<CalculatorResult?> resultAsync;
  final CalculatorDraft draft;
  final CalculatorContext calculatorContext;
  final _RoofModelStepState roofModelState;
  final int selectedStep;
  final int? highlightedModuleIndex;
  final int? highlightedGlassFieldIndex;
  final AdminResourceRepository mediaRepository;
  final LoadedQuote? loadedQuote;
  final VoidCallback onSaveQuote;
  final VoidCallback onPrint;
  final bool isSavingQuote;
  final String? calculationNumber;
  final bool isCalculationSaved;
  final bool needsRecalculation;
  final SavedQuote? savedQuote;

  bool get _showPreviewTab {
    final modelIndex = _steps.indexWhere((step) => step.key == 'model');
    return loadedQuote != null ||
        (roofModelState.required && modelIndex >= 0 && selectedStep >= modelIndex);
  }

  @override
  Widget build(BuildContext context) {
    final showPreviewTab = _showPreviewTab;
    final resultTabsKey = loadedQuote == null
        ? const ValueKey<String>('calculator-result-tabs')
        : ObjectKey(loadedQuote);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _failedCalculationPanel(context, error, showPreviewTab),
        data: (result) {
          if (result == null && !showPreviewTab) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _noCalculationTab()),
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

          if (result == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DefaultTabController(
                    key: resultTabsKey,
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Preview'),
                            Tab(text: 'Result'),
                          ],
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                            child: TabBarView(
                              children: [
                                _GeometryPreviewTab(
                                  draft: draft,
                                  calculatorContext: calculatorContext,
                                  roofModelState: roofModelState,
                                  mediaRepository: mediaRepository,
                                  savedInput: loadedQuote?.input,
                                  calculationNumber: calculationNumber,
                                  highlightedModuleIndex: highlightedModuleIndex,
                                  highlightedGlassFieldIndex: highlightedGlassFieldIndex,
                                ),
                                _noCalculationTab(),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                  key: resultTabsKey,
                  length: showPreviewTab ? 6 : 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                        child: _PriceHeader(
                          result: result,
                          calculationNumber: calculationNumber ?? 'new quote',
                          isCalculationSaved: isCalculationSaved,
                          needsRecalculation: needsRecalculation,
                        ),
                      ),
                      TabBar(
                        isScrollable: true,
                        tabs: [
                          if (showPreviewTab) const Tab(text: 'Preview'),
                          const Tab(text: 'Lines'),
                          const Tab(text: 'BOM'),
                          const Tab(text: 'Sources'),
                          const Tab(text: 'Trace'),
                          const Tab(text: 'JSON'),
                        ],
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: TabBarView(
                            children: [
                              if (showPreviewTab)
                                _GeometryPreviewTab(
                                  draft: draft,
                                  calculatorContext: calculatorContext,
                                  roofModelState: roofModelState,
                                  mediaRepository: mediaRepository,
                                  result: result,
                                  savedInput: loadedQuote?.input,
                                  calculationNumber: calculationNumber,
                                  highlightedModuleIndex: highlightedModuleIndex,
                                  highlightedGlassFieldIndex: highlightedGlassFieldIndex,
                                ),
                              _LinesTab(result: result),
                              _BomTab(result: result),
                              _ScrollableResultCard(child: JsonViewCard(title: 'Price sources', data: result.sources)),
                              _SimpleRowsTab(rows: result.trace, empty: 'No trace.'),
                              _ScrollableResultCard(child: JsonViewCard(title: 'Raw calculation result', data: result.raw)),
                            ],
                          ),
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

  Widget _failedCalculationPanel(BuildContext context, Object error, bool showPreviewTab) {
    final message = error is ApiException ? error.displayMessage : '$error';
    final errorJson = <String, dynamic>{
      'status': 'failed',
      'message': message,
    };
    final traceRows = <Map<String, dynamic>>[
      {
        'step': 'calculation_failed',
        'message': message,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CalculationErrorBanner(message: message),
        Expanded(
          child: DefaultTabController(
            length: showPreviewTab ? 6 : 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [
                    if (showPreviewTab) const Tab(text: 'Preview'),
                    const Tab(text: 'Lines'),
                    const Tab(text: 'BOM'),
                    const Tab(text: 'Sources'),
                    const Tab(text: 'Trace'),
                    const Tab(text: 'JSON'),
                  ],
                ),
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBarView(
                      children: [
                        if (showPreviewTab)
                          _GeometryPreviewTab(
                            draft: draft,
                            calculatorContext: calculatorContext,
                            roofModelState: roofModelState,
                            mediaRepository: mediaRepository,
                            calculationNumber: calculationNumber,
                            highlightedModuleIndex: highlightedModuleIndex,
                            highlightedGlassFieldIndex: highlightedGlassFieldIndex,
                          ),
                        const Center(child: Text('No price lines were generated because calculation failed.')),
                        const Center(child: Text('No BOM lines were generated because calculation failed.')),
                        _ScrollableResultCard(child: JsonViewCard(title: 'Price sources', data: errorJson)),
                        _SimpleRowsTab(rows: traceRows, empty: 'No trace.'),
                        _ScrollableResultCard(child: JsonViewCard(title: 'Raw calculation error', data: errorJson)),
                      ],
                    ),
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
  }

  Widget _noCalculationTab() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: _HintCard(
        icon: Icons.calculate_outlined,
        title: 'No calculation yet',
        text: 'Fill the steps and run Calculate. Internal result will include sources, options diagnostics, BOM and trace.',
      ),
    );
  }
}

class _CalculationErrorBanner extends StatelessWidget {
  const _CalculationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Calculation failed',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calculation error copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 116),
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
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

class _GeometryPreviewTab extends StatelessWidget {
  const _GeometryPreviewTab({
    required this.draft,
    required this.calculatorContext,
    required this.roofModelState,
    required this.mediaRepository,
    this.result,
    this.savedInput,
    this.calculationNumber,
    this.highlightedModuleIndex,
    this.highlightedGlassFieldIndex,
  });

  final CalculatorDraft draft;
  final CalculatorContext calculatorContext;
  final _RoofModelStepState roofModelState;
  final AdminResourceRepository mediaRepository;
  final CalculatorResult? result;
  final Map<String, dynamic>? savedInput;
  final String? calculationNumber;
  final int? highlightedModuleIndex;
  final int? highlightedGlassFieldIndex;

  @override
  Widget build(BuildContext context) {
    final selectedModel = roofModelState.options
        .where((option) => option.code == draft.modelCode)
        .cast<CalculatorOption?>()
        .firstOrNull;
    final selectedTemplate = calculatorContext.templates
        .where((template) => template.id == draft.templateId)
        .cast<CalculatorTemplateOption?>()
        .firstOrNull;
    final localRoofCalculation = calculateRoofGeometryForDraft(
      draft: draft,
      template: selectedTemplate,
      model: selectedModel,
    );
    final serverRoofCalculation = result == null
        ? null
        : roofGeometryCalculationFromSources(result!.sources);
    final hasDraftGeometry = draft.setContents.any(
      (tab) => tab.moduleWidthMm != null || tab.moduleDepthMm != null,
    );
    final roofCalculation = hasDraftGeometry
        ? localRoofCalculation
        : (serverRoofCalculation ?? localRoofCalculation);
    // Keep local module geometry responsive while editing, but use the
    // authoritative matrix/BOM post quantity when a calculation result exists.
    final serverPostCount = serverRoofCalculation?.postCount ?? 0;
    final previewPostCount = serverPostCount > 0
        ? serverPostCount
        : roofCalculation.postCount;
    final colorPreview = _colorPreviewDataFor(calculatorContext, draft.colorCode);
    final coveringName = _coveringDisplayName(
      calculatorContext.references['tds_glass_covering'] ?? const [],
      draft.coveringCode,
    );
    final buyerContact = calculatorContext.buyerContactFor(draft);
    final draftHandoverTypeCode = draft.handoverTypeCode?.trim();
    final savedHandoverTypeCode = (savedInput?['handover_type_code'] ?? savedInput?['handoverTypeCode'])
        ?.toString()
        .trim();
    final effectiveHandoverTypeCode = draftHandoverTypeCode?.isNotEmpty == true
        ? draftHandoverTypeCode
        : (savedHandoverTypeCode?.isNotEmpty == true ? savedHandoverTypeCode : null);
    final savedCompletionWeek = _intFromFlexible(
      savedInput?['completion_week'] ?? savedInput?['completionWeek'],
    );
    final effectiveCompletionWeek = draft.completionWeek ?? savedCompletionWeek;
    final handover = (calculatorContext.references['handover_types'] ?? const [])
        .where(
          (option) => option.code == effectiveHandoverTypeCode || option.id == effectiveHandoverTypeCode,
        )
        .cast<CalculatorOption?>()
        .firstOrNull;
    final modelCode = draft.modelCode?.trim();
    final hasModel = modelCode != null && modelCode.isNotEmpty;

    return _ScrollableResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasModel)
            const _HintCard(
              icon: Icons.view_in_ar_outlined,
              title: 'No roof type selected',
              text: 'Select a model to show the geometry preview.',
            ),
          if (hasModel)
            ModelGeometryPreview(
              modelCode: draft.modelCode,
              modelLabel: selectedModel?.label,
              mediaRepository: mediaRepository,
              widthMm: draft.widthMm,
              depthMm: draft.depthMm,
              heightMm: draft.heightMm,
              geometryParams: geometryPreviewParamsFromDraft(draft),
              modules: draft.setContents,
              moduleRoles: _moduleRolesFor(selectedModel),
              calculatedModules: roofCalculation.modules,
              calculationNumber: calculationNumber,
              buyerName: buyerContact.organizationName,
              buyerContactName: buyerContact.contactName,
              buyerEmail: buyerContact.email,
              buyerPhone: buyerContact.phone,
              weights: result?.weights ?? const {},
              deliveryName: handover?.label ?? effectiveHandoverTypeCode,
              completionWeek: effectiveCompletionWeek,
              colorCode: colorPreview?.displayCode,
              colorSwatchColor: colorPreview?.color,
              isSpecialColor: colorPreview != null && !colorPreview.isStandard,
              coveringName: coveringName,
              wallMounted: draft.wallMounted,
              postCount: previewPostCount,
              quoteNotes: draft.externalNotes,
              warnings: result == null
                  ? const []
                  : _resultWarningMessages(result!),
              highlightedModuleIndex: highlightedModuleIndex,
              highlightedGlassFieldIndex: highlightedGlassFieldIndex,
              roofAngleDeg: draft.roofAngleDeg,
              rearHeightMm: draft.roofRearHeightMm ?? draft.heightMm,
              frontHeightMm: draft.roofFrontHeightMm,
            ),
        ],
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
  bool _showPayloadPreview = false;
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

  String _prettyPayloadJson(PrintDialogData data) {
    final payload = data.payloadPreview.isEmpty ? <String, dynamic>{} : data.payloadPreview;
    return const JsonEncoder.withIndent('  ').convert(payload);
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
            final payloadJsonText = _prettyPayloadJson(data);

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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showPayloadPreview = !_showPayloadPreview),
                    icon: Icon(_showPayloadPreview ? Icons.visibility_off_outlined : Icons.data_object_outlined),
                    label: Text(_showPayloadPreview ? 'Hide render JSON' : 'Show render JSON'),
                  ),
                ),
                if (_showPayloadPreview) ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: payloadJsonText,
                    readOnly: true,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Renderer payloadJson',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
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

List<String> _resultWarningMessages(CalculatorResult result) {
  final missingOptionPriceCount = result.optionDiagnostics
      .where((row) => row['price_found'] == false)
      .length;
  final nonOptionWarnings = result.warnings.where((warning) {
    final code = '${warning['code'] ?? ''}';
    return !code.startsWith('option_');
  }).toList(growable: false);
  final missingWeightItems =
      (result.weights['missing_weight_items'] as List? ?? const [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
  return [
    if (missingOptionPriceCount > 0)
      '$missingOptionPriceCount selected option(s) have no configured price. See Options tab.',
    for (final warning in nonOptionWarnings)
      '${warning['message'] ?? warning['code']}',
    if (missingWeightItems.isNotEmpty)
      'Weight is partial. Missing catalog weight data: ${missingWeightItems.join(', ')}',
  ];
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({
    required this.result,
    required this.calculationNumber,
    required this.isCalculationSaved,
    required this.needsRecalculation,
  });

  final CalculatorResult result;
  final String calculationNumber;
  final bool isCalculationSaved;
  final bool needsRecalculation;

  List<String> _discounts() {
    final labels = <String>[];
    final seen = <String>{};
    final breakdown = result.price['discount_breakdown'];
    if (breakdown is List) {
      for (final raw in breakdown.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final pct = _num(row['discount_pct']).toDouble();
        if (pct <= 0) continue;
        final source = '${row['label'] ?? row['code'] ?? 'Discount'}'.trim();
        final label = '$source ${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%';
        if (seen.add(label)) labels.add(label);
      }
    }

    final diagnostics = [
      ...result.setDeltaDiagnostics,
      ...result.derivedAccessoryDiagnostics,
      ...result.manualComponentDiagnostics,
      ...result.optionDiagnostics,
    ];
    for (final row in diagnostics) {
      final pct = _num(row['item_discount_pct']).toDouble();
      if (pct <= 0) continue;
      final source = '${row['option_price_list_code'] ?? row['price_list_code'] ?? 'Position'}'.trim();
      final label = '$source ${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%';
      if (seen.add(label)) labels.add(label);
    }

    if (labels.isEmpty) {
      final global = _num(result.price['discount_pct']).toDouble();
      if (global > 0) {
        final label = 'Organization ${global.toStringAsFixed(global == global.roundToDouble() ? 0 : 1)}%';
        if (seen.add(label)) labels.add(label);
      }
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final net = _num(result.price['net']);
    final gross = _num(result.price['gross']);
    final margin = result.internalPrice['margin'];
    final discounts = _discounts();
    final nonGlassComplete = _weightComplete(result.weights, 'set_complete')
        && _weightComplete(result.weights, 'accessories_complete')
        && _weightComplete(result.weights, 'options_complete');
    final nonGlassWeight = _weightValue(result.weights, 'set_kg')
        + _weightValue(result.weights, 'accessories_kg')
        + _weightValue(result.weights, 'options_kg');
    final warningMessages = _resultWarningMessages(result)
        .map((message) => '⚠ $message')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Net / gross price: ', style: Theme.of(context).textTheme.labelLarge),
                    TextSpan(
                      text: '${_moneyFormat.format(net)} / ${_moneyFormat.format(gross)}',
                      style: needsRecalculation
                          ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              )
                          : Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: isCalculationSaved
                  ? 'Saved and unchanged'
                  : 'Not saved or contains unsaved changes',
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  isCalculationSaved ? Icons.check_circle_outline : Icons.edit_outlined,
                  size: 18,
                  color: isCalculationSaved
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.tertiary,
                ),
                label: Text(calculationNumber, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                needsRecalculation
                    ? Icons.error_outline
                    : result.status == 'valid'
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                color: needsRecalculation ? Theme.of(context).colorScheme.error : null,
              ),
              label: Text(needsRecalculation ? 'recalculate' : result.status),
              backgroundColor: needsRecalculation
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          discounts.isEmpty
              ? 'Discounts: —'
              : [
                  for (var index = 0; index < discounts.length; index++)
                    '${index == 0 ? 'Discount 1' : 'then ${index + 1}'}: ${discounts[index]}',
                ].join(' · '),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (margin != null) ...[
          const SizedBox(height: 8),
          _MetricChip(label: 'Margin', value: _moneyFormat.format(_num(margin))),
        ],
        if (result.weights.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Gewicht: ${nonGlassWeight > 0 ? '${nonGlassWeight.toStringAsFixed(1)} kg${nonGlassComplete ? '' : '*'}' : '—'} / '
            'Glas: ${_weightText(result.weights, 'glass_kg', 'glass_complete')} / '
            'Gesamt: ${_weightText(result.weights, 'total_kg', 'total_complete')}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
        if (warningMessages.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ScrollableWarningText(messages: warningMessages),
        ],
      ],
    );
  }
}


class _ScrollableWarningText extends StatefulWidget {
  const _ScrollableWarningText({required this.messages});

  final List<String> messages;

  @override
  State<_ScrollableWarningText> createState() => _ScrollableWarningTextState();
}

class _ScrollableWarningTextState extends State<_ScrollableWarningText> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 92),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.only(right: 12),
          child: SelectionArea(
            child: Text(
              widget.messages.join('\n'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinesTab extends StatelessWidget {
  const _LinesTab({required this.result});

  final CalculatorResult result;

  @override
  Widget build(BuildContext context) {
    if (result.visibleLines.isEmpty) return const Center(child: Text('No lines.'));

    final sectionTitles = <String, String>{
      'base_set': 'Base set price',
      'set_delta': 'Set delta / Abzug',
      'derived_accessories': 'Derived accessories',
      'manual_components': 'Manual components',
      'glass': 'Eindeckung',
      'additional_articles': 'Zusätzliche Artikel',
      'special_color': 'Sonderfarbe',
      'options': 'Options / additional handling',
    };
    final hasSections = result.visibleLines.any((line) => '${line['section'] ?? ''}'.trim().isNotEmpty);
    if (hasSections) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final line in result.visibleLines) {
        final section = '${line['section'] ?? 'options'}'.trim();
        grouped.putIfAbsent(section.isEmpty ? 'options' : section, () => []).add(line);
      }
      final orderedSections = <String>[
        ...sectionTitles.keys.where(grouped.containsKey),
        ...grouped.keys.where((section) => !sectionTitles.containsKey(section)),
      ];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final section in orderedSections) ...[
            _sectionHeader(
              context,
              sectionTitles[section] ?? section,
              '${grouped[section]!.length} line(s)',
            ),
            ..._lineTiles(grouped[section]!),
          ],
        ],
      );
    }

    final baseLines = result.visibleLines.take(1).toList(growable: false);
    var remaining = result.visibleLines.skip(baseLines.length).toList(growable: false);
    int pricedCount(List<Map<String, dynamic>> diagnostics) =>
        diagnostics.where((entry) => entry['price_found'] == true).length;
    List<Map<String, dynamic>> takeSection(int count) {
      final section = remaining.take(count).toList(growable: false);
      remaining = remaining.skip(section.length).toList(growable: false);
      return section;
    }

    final deltaLines = takeSection(pricedCount(result.setDeltaDiagnostics));
    final derivedLines = takeSection(pricedCount(result.derivedAccessoryDiagnostics));
    final manualLines = takeSection(pricedCount(result.manualComponentDiagnostics));
    final optionLines = remaining;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (baseLines.isNotEmpty) ...[
          _sectionHeader(context, 'Base set price'),
          ..._lineTiles(baseLines),
        ],
        if (deltaLines.isNotEmpty) ...[
          _sectionHeader(context, 'Set delta / Abzug', '${deltaLines.length} priced line(s)'),
          ..._lineTiles(deltaLines),
        ],
        if (derivedLines.isNotEmpty) ...[
          _sectionHeader(context, 'Derived accessories', '${derivedLines.length} priced line(s)'),
          ..._lineTiles(derivedLines),
        ],
        if (manualLines.isNotEmpty) ...[
          _sectionHeader(context, 'Manual components', '${manualLines.length} priced line(s)'),
          ..._lineTiles(manualLines),
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
    final netUnitPrice = line.containsKey('netUnitPrice') ? _num(line['netUnitPrice']) : unitPrice;
    final grossAmount = _num(line['amount']);
    final discountPct = _num(line['discountPct']);
    final discountAmount = _num(line['discountAmount']);
    final netAmount = line.containsKey('netAmount') ? _num(line['netAmount']) : grossAmount;
    final note = '${line['note'] ?? ''}'.trim();
    final unit = _formatUnitLabel('${line['unit'] ?? ''}');
    final subtitleParts = <String>[
      'Qty ${line['quantity'] ?? 1} $unit',
      if (unitPrice > 0) '${_moneyFormat.format(unitPrice)} / $unit',
      if (discountPct > 0) 'Rabatt ${discountPct.toStringAsFixed(discountPct % 1 == 0 ? 0 : 2)} %',
      if (discountPct > 0 && netUnitPrice > 0) 'nach Rabatt ${_moneyFormat.format(netUnitPrice)} / $unit',
      if (discountAmount > 0) '−${_moneyFormat.format(discountAmount)}',
      if (note.isNotEmpty) note,
    ];
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text('${line['label'] ?? 'Line'}', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitleParts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(_moneyFormat.format(netAmount)),
    );
  }
}

class _BomTab extends StatelessWidget {
  const _BomTab({required this.result});

  final CalculatorResult result;

  @override
  Widget build(BuildContext context) {
    final glassRows = result.glassLines;
    final hasBom = [
      result.baseBom,
      result.calculatedBom,
      result.effectiveSetBom,
      result.manualBom,
      result.derivedAccessories,
      result.setDeltaBom,
      result.optionBom,
    ].any((rows) => rows.isNotEmpty);
    if (!hasBom && glassRows.isEmpty) {
      return const Center(child: Text('No calculated BOM or glass lines yet.'));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (glassRows.isNotEmpty) ...[
          Text('Glass lines', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final row in glassRows)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text('${row['module'] ?? 'module'} · ${row['catalog_name'] ?? row['glass_type_code'] ?? 'glass'}'),
              subtitle: Text(
                '${_glassDimensions(row)} · '
                '${row['area_m2'] ?? 0} m² · Article ${row['article_no'] ?? '—'} · '
                'Unit price ${row['unit_price'] == null ? '—' : _moneyFormat.format(_num(row['unit_price']))}',
              ),
            ),
          const Divider(height: 24),
        ],
        _BomSection(
          title: 'Effective calculated set',
          subtitle: 'Physical construction after segment overrides. Not added to price as ordinary options.',
          rows: result.effectiveSetBom,
        ),
        _BomSection(
          title: 'Standard set',
          subtitle: 'Comparison basis from the matched rule-matrix row.',
          rows: result.baseBom,
        ),
        _BomSection(
          title: 'Set delta / Abzug',
          subtitle: 'Only the difference between effective and standard set is price-relevant.',
          rows: result.setDeltaBom,
        ),
        _BomSection(
          title: 'Derived accessories',
          subtitle: 'Automatically calculated from the effective profile BOM.',
          rows: result.derivedAccessories,
        ),
        _BomSection(
          title: 'Manual components',
          subtitle: 'User-added positions stored separately from calculated segments.',
          rows: result.manualBom,
        ),
        _BomSection(
          title: 'Ordinary options',
          subtitle: 'Additional catalog options outside the base construction.',
          rows: result.optionBom,
        ),
      ],
    );
  }

  String _glassDimensions(Map<String, dynamic> row) {
    final saved = '${row['dimensions'] ?? ''}'.trim();
    if (saved.isNotEmpty) return saved;
    return '${row['quantity'] ?? 0}x${_formatLengthNumber(_num(row['width_mm']))}x${_formatLengthNumber(_num(row['length_mm']))} mm';
  }
}

class _BomSection extends StatelessWidget {
  const _BomSection({required this.title, required this.subtitle, required this.rows});

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          for (final row in rows) _CalculatedBomTile(row: row),
        ],
      ),
    );
  }
}

class _CalculatedBomTile extends StatelessWidget {
  const _CalculatedBomTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final segments = (row['segments'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
      initiallyExpanded: segments.isNotEmpty,
      title: Text('${row['name'] ?? row['article_no'] ?? 'BOM line'}'),
      subtitle: Text(
        'Article: ${row['article_no'] ?? '—'} · Qty: ${row['quantity'] ?? 1} ${row['unit_code'] ?? ''}',
      ),
      children: [
        for (final segment in segments)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${segment['module'] ?? 'module'}: ${segment['quantity'] ?? 0} × '
                '${_formatLengthNumber(_num(segment['length_mm']))} mm'
                '${_num(segment['split_count']) > 1 ? ' (split ${segment['split_count']} from ${_formatLengthNumber(_num(segment['original_length_mm']))} mm)' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
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
    this.leadingBuilder,
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
  final Widget Function(T option)? leadingBuilder;
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
                    leading: widget.leadingBuilder?.call(option),
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
    this.readOnly = false,
    this.suffixText = 'mm',
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final String suffixText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          errorText: errorText,
        ),
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

class _ColorPreviewData {
  const _ColorPreviewData({
    required this.displayCode,
    required this.color,
    required this.isStandard,
  });

  final String displayCode;
  final Color? color;
  final bool isStandard;
}

_ColorPreviewData? _colorPreviewDataFor(CalculatorContext contextData, String? rawCode) {
  final code = _normalizeRalCode(rawCode);
  if (code == null) return null;

  final colorOptions = contextData.references['colors'] ?? const <CalculatorOption>[];
  final ralColorOptions = contextData.references['ral_colors'] ?? const <CalculatorOption>[];

  final isStandard = colorOptions.any((option) => _normalizeRalCode(option.code) == code);
  CalculatorOption? match;
  for (final option in [...colorOptions, ...ralColorOptions]) {
    if (_normalizeRalCode(option.code) == code) {
      match = option;
      break;
    }
  }

  final color = _colorFromHex(
    _stringFromRaw(match?.raw['color_hex'] ?? match?.raw['colorHex'] ?? match?.raw['metadata_json']?['color_hex']),
  );

  return _ColorPreviewData(
    displayCode: RegExp(r'^\d{4}$').hasMatch(code) ? 'RAL $code' : code,
    color: color,
    isStandard: isStandard,
  );
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

  CalculatorOption? selectedForCode(String? modelCode) {
    if (modelCode == null || modelCode.trim().isEmpty) return null;
    for (final option in options) {
      if (option.code == modelCode) return option;
    }
    return null;
  }

  bool isSelected(String? modelCode) {
    if (!required) return true;
    return selectedForCode(modelCode) != null;
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

String _priceSignature(CalculatorDraft draft) {
  final input = Map<String, dynamic>.from(draft.toCalculationJson())
    ..remove('quote_no_external')
    ..remove('external_notes')
    ..remove('branding')
    ..remove('language_code');
  return jsonEncode(_stablePriceValue(input));
}

dynamic _stablePriceValue(dynamic value) {
  if (value is Map) {
    final entries = value.entries
        .map((entry) => MapEntry(entry.key.toString(), entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {
      for (final entry in entries)
        if (entry.value != null) entry.key: _stablePriceValue(entry.value),
    };
  }
  if (value is List) return value.map(_stablePriceValue).toList();
  if (value is num && value.toDouble().isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return value;
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

/*
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
*/

/*
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

 */

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


double _weightValue(Map<String, dynamic> weights, String key) {
  final value = weights[key];
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

bool _weightComplete(Map<String, dynamic> weights, String key) {
  final value = weights[key];
  return value is bool ? value : true;
}

String _weightText(Map<String, dynamic> weights, String valueKey, String completeKey) {
  final value = _weightValue(weights, valueKey);
  final complete = _weightComplete(weights, completeKey);
  if (value <= 0 && !complete) return '—';
  return '${value.toStringAsFixed(1)} kg${complete ? '' : '*'}';
}

double _glassWeightKg(double areaM2, String? coveringCode) {
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:_?mm)?', caseSensitive: false)
      .firstMatch(coveringCode ?? '');
  final thickness = match == null ? 0 : double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
  return areaM2 * thickness * 2.5;
}

int _isoWeekNumber(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final thursday = normalized.add(Duration(days: 4 - normalized.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final weekOne = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
  return 1 + thursday.difference(weekOne).inDays ~/ 7;
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

String _formatDecimalNumber(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  final fixed = value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return fixed.replaceAll('.', ',');
}

String _formatLengthNumber(num value) => _formatDecimalNumber(value);

String? _formatLengthMm(num? value) {
  if (value == null || value <= 1) return null;
  return '${_formatLengthNumber(value)} mm';
}

num _num(dynamic value) {
  if (value is num) return value;
  if (value == null) return 0;
  return num.tryParse('$value') ?? 0;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

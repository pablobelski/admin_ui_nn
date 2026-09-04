import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/calculator_models.dart';
import '../data/calculator_repository.dart';

final calculatorRepositoryProvider = Provider<CalculatorRepository>((ref) {
  return CalculatorRepository(ref.watch(apiClientProvider));
});

/// One requested change for all calculated Set Contents rows that belong to the
/// same article number. The module editor collects these and applies them in a
/// single notifier call so that geometry, covering and the dependent
/// components are recalculated exactly once.
class CalculatorSetContentArticleOverride {
  const CalculatorSetContentArticleOverride({
    required this.articleNo,
    required this.quantity,
    required this.installedLengthMm,
    required this.enabled,
  }) : resetToCalculated = false;

  const CalculatorSetContentArticleOverride.reset(this.articleNo)
      : quantity = 1,
        installedLengthMm = 1,
        enabled = true,
        resetToCalculated = true;

  final String articleNo;
  final int quantity;
  final int installedLengthMm;
  final bool enabled;
  final bool resetToCalculated;
}

String _setContentItemIdentity(CalculatorSetContentItem item) =>
    item.segmentId ??
    '${item.catalogItemId}:${item.catalogVariantId ?? ''}:${item.articleNo ?? ''}';

final calculatorContextProvider = FutureProvider<CalculatorContext>((ref) async {
  final loadedQuote = ref.watch(loadedQuoteProvider);
  final context = await ref.watch(calculatorRepositoryProvider).fetchContext();
  if (loadedQuote == null) return context;
  return context.withRestoredCatalog(
    catalogItems: loadedQuote.catalogItems,
    catalogVariants: loadedQuote.catalogVariants,
    warnings: loadedQuote.catalogWarnings,
  );
});

class CalculatorSetContentsRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state = state + 1;
  }
}

final calculatorSetContentsRefreshTickProvider =
    NotifierProvider.autoDispose<CalculatorSetContentsRefreshTickNotifier, int>(
  CalculatorSetContentsRefreshTickNotifier.new,
);

final calculatorSetContentsProvider = FutureProvider.autoDispose<CalculatorSetContentsPreview>((ref) async {
  ref.watch(calculatorDraftProvider.select(_setContentsRequestSignature));
  ref.watch(calculatorSetContentsRefreshTickProvider);
  final draft = ref.read(calculatorDraftProvider);

  if (draft.templateId == null || draft.templateId!.isEmpty) {
    return const CalculatorSetContentsPreview(tabs: [], source: {}, trace: [], warnings: [], raw: {});
  }

  return ref.watch(calculatorRepositoryProvider).fetchSetContents(draft);
});

String _setContentsRequestSignature(CalculatorDraft draft) {
  return jsonEncode({
    'organization_id': draft.organizationId,
    'related_customer_id': draft.relatedCustomerId,
    'product_family_id': draft.productFamilyId,
    'template_id': draft.templateId,
    'price_mode': draft.priceMode,
    'model_code': draft.modelCode,
    'width_mm': draft.widthMm,
    'depth_mm': draft.depthMm,
    'height_mm': draft.heightMm,
    'color_code': draft.colorCode,
    'roof_angle_deg': draft.roofAngleDeg,
    'roof_rear_height_mm': draft.roofRearHeightMm,
    'roof_front_height_mm': draft.roofFrontHeightMm,
    'force_odd_beams': draft.forceOddBeams,
    'wall_mounted': draft.wallMounted,
    'add_wall_seal_pressure_plate': draft.addWallSealPressurePlate,
    'wall_gutter_blende_long_length': draft.wallGutterBlendeLongLength,
    'add_static_beam_assembly': draft.addStaticBeamAssembly,
    'static_beam_position_code': draft.staticBeamPositionCode,
    'static_beam_length_calculation_method':
        draft.staticBeamLengthCalculationMethod,
    'missing_set_piece_abzug_article_nos': [
      ...draft.missingSetPieceAbzugArticleNos,
    ]..sort(),
    'modules': [
      for (final tab in draft.setContents)
        {
          'id': tab.id,
          'role': tab.moduleRole,
          'geometry_key': tab.geometryKey,
          'width_mm': tab.moduleWidthMm,
          'depth_mm': tab.moduleDepthMm,
          'covering_code': tab.moduleCoveringCode,
          'max_glass_field_width_mm': tab.moduleMaxGlassFieldWidthMm,
          'manufacturing_splits': tab.moduleManufacturingSplits,
          'items': [
            for (final item in tab.items.where((entry) => entry.shouldPersist))
              {
                'segment_id': item.segmentId,
                'article_no': item.articleNo ?? item.profileNo ?? item.baseCode,
                'quantity': item.quantity,
                'length_mm': item.lengthMm,
                'enabled': item.enabled,
                'override_state': item.overrideState,
              },
          ],
        },
    ],
  });
}

class LoadedQuoteNotifier extends Notifier<LoadedQuote?> {
  @override
  LoadedQuote? build() => null;

  void set(LoadedQuote quote) {
    state = quote;
  }

  void clear() {
    state = null;
  }
}

final loadedQuoteProvider = NotifierProvider<LoadedQuoteNotifier, LoadedQuote?>(
  LoadedQuoteNotifier.new,
);

class CalculatorDraftNotifier extends Notifier<CalculatorDraft> {
  @override
  CalculatorDraft build() => const CalculatorDraft();

  void loadQuote(LoadedQuote quote) {
    state = _withSingleModuleDimensions(
      CalculatorDraft.fromCalculationJson(
        quote.input,
        productFamilyId: quote.productFamilyId,
        resultJson: quote.resultJson,
      ),
    );
  }

  void reset() {
    state = const CalculatorDraft();
  }

  void setOrganization(String? value) => state = state.copyWith(
        organizationId: value,
        clearOrganization: value == null || value.isEmpty,
        clearRelatedCustomer: true,
      );

  void setProductFamily(String? value) {
    final normalized = value?.trim();
    final nextValue = normalized == null || normalized.isEmpty ? null : normalized;
    if (nextValue == state.productFamilyId) return;
    state = state.copyWith(
      productFamilyId: nextValue,
      templateId: null,
      clearProductFamily: nextValue == null,
      clearTemplate: true,
      clearModel: true,
      clearMaxGlassFieldWidth: true,
      clearCovering: true,
      markiseSelections: const [],
      setContents: const [],
      missingSetPieceAbzugArticleNos: const [],
    );
  }

  void setTemplate(String? value) {
    final normalized = value?.trim();
    final nextValue = normalized == null || normalized.isEmpty ? null : normalized;
    if (nextValue == state.templateId) return;
    state = state.copyWith(
      templateId: nextValue,
      clearTemplate: nextValue == null,
      clearModel: true,
      clearMaxGlassFieldWidth: true,
      clearCovering: true,
      markiseSelections: const [],
      setContents: const [],
      missingSetPieceAbzugArticleNos: const [],
    );
  }

  void setPriceMode(String? value) {
    if (value == null || value.isEmpty) return;
    state = state.copyWith(priceMode: value);
  }

  void setModel(String? value, {bool preserveSetContents = false}) {
    final normalized = value?.trim();
    final nextValue = normalized == null || normalized.isEmpty ? null : normalized;
    if (nextValue == state.modelCode) return;
    state = _withSingleModuleDimensions(
      state.copyWith(
        modelCode: nextValue,
        clearModel: nextValue == null,
        clearMaxGlassFieldWidth: true,
        clearCovering: true,
        markiseSelections: const [],
        setContents: preserveSetContents ? state.setContents : const [],
        missingSetPieceAbzugArticleNos:
            preserveSetContents ? state.missingSetPieceAbzugArticleNos : const [],
      ),
    );
  }

  void setWidth(String value) {
    final parsed = int.tryParse(value.trim());
    state = _withSingleModuleDimensions(
      state.copyWith(
        widthMm: parsed,
        clearWidth: value.trim().isEmpty,
        setContents: _syncFirstModuleDimension(
          state.setContents,
          key: 'width_mm',
          total: parsed,
        ),
      ),
    );
  }

  void setDepth(String value) {
    final parsed = int.tryParse(value.trim());
    state = _withSingleModuleDimensions(
      state.copyWith(
        depthMm: parsed,
        clearDepth: value.trim().isEmpty,
        setContents: _syncFirstModuleDepth(
          state.setContents,
          previousTotal: state.depthMm,
          nextTotal: parsed,
        ),
      ),
    );
  }

  void setHeight(String value) {
    final parsed = int.tryParse(value);
    state = state.copyWith(
      heightMm: parsed,
      clearHeight: value.trim().isEmpty,
      roofRearHeightMm: parsed,
      clearRoofRearHeight: value.trim().isEmpty,
    );
  }

  void setRoofAngle(String value) => state = state.copyWith(
        roofAngleDeg: int.tryParse(value),
        clearRoofAngle: value.trim().isEmpty,
      );

  void setRoofAngleValue(int? value) => state = state.copyWith(
        roofAngleDeg: value,
        clearRoofAngle: value == null,
      );

  void setRoofFrontHeight(String value) => state = state.copyWith(
        roofFrontHeightMm: int.tryParse(value),
        clearRoofFrontHeight: value.trim().isEmpty,
      );

  void setRoofFrontHeightValue(int? value) => state = state.copyWith(
        roofFrontHeightMm: value,
        clearRoofFrontHeight: value == null,
      );

  void setForceOddBeams(bool value) => state = state.copyWith(forceOddBeams: value);

  void setWallMounted(bool value) => state = state.copyWith(
        wallMounted: value,
        staticBeamPositionCode: !value && state.staticBeamPositionCode == 'rear_wall'
            ? 'front_overhang'
            : state.staticBeamPositionCode,
      );

  void setAddWallSealPressurePlate(bool value) =>
      state = state.copyWith(addWallSealPressurePlate: value);

  void setWallGutterBlendeLongLength(bool value) =>
      state = state.copyWith(wallGutterBlendeLongLength: value);

  void setCoveringEnabled(bool value) {
    if (value) {
      state = state.copyWith(coveringEnabled: true);
      return;
    }
    state = state.copyWith(
      coveringEnabled: false,
      clearCovering: true,
      clearMaxGlassFieldWidth: true,
      setContents: [
        for (final tab in state.setContents)
          tab
              .withGeometryText('covering_code', null)
              .withGeometryText('glass_type_code', null)
              .withGeometryValue('max_glass_field_width_mm', null)
              .withCoveringAllocations(const []),
      ],
    );
  }

  void setMarkiseEnabled(bool value) => state = state.copyWith(
        markiseEnabled: value,
        markiseExcludeFromPrice:
            value ? state.markiseExcludeFromPrice : false,
        markiseSelections: value ? state.markiseSelections : const [],
      );

  void setMarkiseExcludeFromPrice(bool value) => state = state.copyWith(
        markiseExcludeFromPrice: value,
      );

  void setMarkiseType({
    required int moduleIndex,
    required String moduleRole,
    required String? typeCode,
  }) {
    final normalized = typeCode?.trim() ?? '';
    final next = [
      for (final entry in state.markiseSelections)
        if (entry.moduleIndex != moduleIndex) entry,
      if (normalized.isNotEmpty)
        CalculatorMarkiseSelection(
          moduleIndex: moduleIndex,
          moduleRole: moduleRole,
          typeCode: normalized,
        ),
    ]..sort((a, b) => (a.moduleIndex ?? 0).compareTo(b.moduleIndex ?? 0));
    state = state.copyWith(markiseSelections: next);
  }

  void setAddStaticBeamAssembly(bool value) =>
      state = state.copyWith(addStaticBeamAssembly: value);

  void setStaticBeamPositionCode(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return;
    if (!state.wallMounted && normalized == 'rear_wall') return;
    state = state.copyWith(staticBeamPositionCode: normalized);
  }

  void setStaticBeamLengthCalculationMethod(String? value) {
    final normalized = value?.trim();
    if (!const {
      'legacy_rounded',
      'shortest_sku',
      'installed_length',
    }.contains(normalized)) {
      return;
    }
    state = state.copyWith(
      staticBeamLengthCalculationMethod: normalized,
    );
  }

  void setMaxGlassFieldWidthValue(int? value) => state = state.copyWith(
        maxGlassFieldWidthMm: value,
        clearMaxGlassFieldWidth: value == null,
      );

  void setCovering(String? value) {
    final normalized = value?.trim();
    final nextValue = normalized == null || normalized.isEmpty ? null : normalized;
    if (nextValue == state.coveringCode) return;

    state = state.copyWith(
      coveringCode: nextValue,
      clearCovering: nextValue == null,
      setContents: [
        for (final tab in state.setContents) tab.copyWith(items: const []),
      ],
    );
  }

  void setSetContentModuleCovering(int tabIndex, String? value) {
    _ensureSetContentModuleCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final normalized = value?.trim();
    final tabs = [...state.setContents];
    var updatedTab = tabs[tabIndex]
        .withGeometryText(
          'covering_code',
          normalized == null || normalized.isEmpty ? null : normalized,
        )
        .withGeometryText(
          'glass_type_code',
          normalized == null || normalized.isEmpty ? null : normalized,
        );
    if (normalized == null || normalized.isEmpty) {
      updatedTab = updatedTab.withCoveringAllocations(const []);
    }
    tabs[tabIndex] = updatedTab.withoutCoveringFields().copyWith(items: const []);
    state = state.copyWith(
      setContents: tabs,
      clearCovering: true,
      clearMaxGlassFieldWidth: true,
    );
  }

  void addSetContentModuleCoveringAllocation(
    int tabIndex, {
    required int quantity,
    required int totalGlassCount,
  }) {
    _ensureSetContentModuleCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    final primaryCode = tab.moduleCoveringCode?.trim() ?? '';
    if (primaryCode.isEmpty || totalGlassCount <= 1) return;
    final allocations = [...tab.moduleCoveringAllocations];
    final available = totalGlassCount -
        1 -
        allocations.fold<int>(
          0,
          (sum, allocation) => sum + allocation.quantity,
        );
    if (available <= 0) return;
    final normalizedQuantity = quantity.clamp(1, available).toInt();
    final usedIds = allocations
        .map((allocation) => allocation.allocationId)
        .toSet();
    var sequence = 1;
    while (usedIds.contains('split-$sequence')) {
      sequence += 1;
    }
    allocations.add(
      CalculatorCoveringAllocation(
        allocationId: 'split-$sequence',
        coveringCode: primaryCode,
        quantity: normalizedQuantity,
      ),
    );
    _setModuleCoveringAllocations(tabIndex, allocations);
  }

  void setSetContentModuleCoveringAllocationType(
    int tabIndex,
    String allocationId,
    String? value,
  ) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final normalized = value?.trim();
    final fallbackCode =
        state.setContents[tabIndex].moduleCoveringCode?.trim();
    final nextCode = normalized == null || normalized.isEmpty
        ? fallbackCode
        : normalized;
    final allocations = [
      for (final allocation
          in state.setContents[tabIndex].moduleCoveringAllocations)
        if (allocation.allocationId == allocationId)
          allocation.copyWith(
            coveringCode: nextCode,
            clearCoveringCode: nextCode == null || nextCode.isEmpty,
          )
        else
          allocation,
    ];
    _setModuleCoveringAllocations(tabIndex, allocations);
  }

  void setSetContentModuleCoveringAllocationQuantity(
    int tabIndex,
    String allocationId, {
    required int quantity,
    required int totalGlassCount,
  }) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final current = state.setContents[tabIndex].moduleCoveringAllocations;
    final otherQuantity = current
        .where((allocation) => allocation.allocationId != allocationId)
        .fold<int>(0, (sum, allocation) => sum + allocation.quantity);
    final available = totalGlassCount - 1 - otherQuantity;
    if (available <= 0) return;
    final normalizedQuantity = quantity.clamp(1, available).toInt();
    final allocations = [
      for (final allocation in current)
        if (allocation.allocationId == allocationId)
          allocation.copyWith(quantity: normalizedQuantity)
        else
          allocation,
    ];
    _setModuleCoveringAllocations(tabIndex, allocations);
  }

  void setSetContentModulePrimaryCoveringQuantity(
    int tabIndex, {
    required int quantity,
    required int totalGlassCount,
  }) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    final primaryCode = tab.moduleCoveringCode?.trim() ?? '';
    if (primaryCode.isEmpty || totalGlassCount <= 0) return;

    final normalizedPrimary = quantity.clamp(1, totalGlassCount).toInt();
    var remainingSecondary = totalGlassCount - normalizedPrimary;
    final allocations = <CalculatorCoveringAllocation>[];

    for (final allocation in tab.moduleCoveringAllocations) {
      if (remainingSecondary <= 0) break;
      final allocationQuantity = math.min(
        allocation.quantity,
        remainingSecondary,
      ).toInt();
      allocations.add(allocation.copyWith(quantity: allocationQuantity));
      remainingSecondary -= allocationQuantity;
    }

    if (remainingSecondary > 0) {
      if (allocations.isNotEmpty) {
        final lastIndex = allocations.length - 1;
        allocations[lastIndex] = allocations[lastIndex].copyWith(
          quantity: allocations[lastIndex].quantity + remainingSecondary,
        );
      } else {
        final usedIds = tab.moduleCoveringAllocations
            .map((allocation) => allocation.allocationId)
            .toSet();
        var sequence = 1;
        while (usedIds.contains('split-$sequence')) {
          sequence += 1;
        }
        allocations.add(
          CalculatorCoveringAllocation(
            allocationId: 'split-$sequence',
            coveringCode: primaryCode,
            quantity: remainingSecondary,
          ),
        );
      }
    }

    _setModuleCoveringAllocations(tabIndex, allocations);
  }

  void removeSetContentModuleCoveringAllocation(
    int tabIndex,
    String allocationId,
  ) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final allocations = state.setContents[tabIndex].moduleCoveringAllocations
        .where((allocation) => allocation.allocationId != allocationId)
        .toList(growable: false);
    _setModuleCoveringAllocations(tabIndex, allocations);
  }

  void normalizeSetContentModuleCoveringAllocations(
    int tabIndex,
    int totalGlassCount,
  ) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    var remaining = totalGlassCount <= 1 ? 0 : totalGlassCount - 1;
    final normalized = <CalculatorCoveringAllocation>[];
    for (final allocation
        in state.setContents[tabIndex].moduleCoveringAllocations) {
      if (remaining <= 0) break;
      final quantity = allocation.quantity.clamp(1, remaining).toInt();
      normalized.add(allocation.copyWith(quantity: quantity));
      remaining -= quantity;
    }
    final current = state.setContents[tabIndex].moduleCoveringAllocations;
    if (_coveringAllocationsEqual(current, normalized)) return;
    _setModuleCoveringAllocations(tabIndex, normalized);
  }

  void setSetContentModuleCoveringFields(
    int tabIndex,
    List<CalculatorCoveringField> fields, {
    required int sheetsPerField,
  }) {
    _ensureSetContentModuleCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final normalizedFields = fields
        .where((field) => field.fieldIndex > 0)
        .toList(growable: false)
      ..sort((left, right) => left.fieldIndex.compareTo(right.fieldIndex));
    if (normalizedFields.isEmpty) return;

    String? firstPrimary;
    for (final field in normalizedFields) {
      final code = field.coveringCode?.trim() ?? '';
      if (code.isNotEmpty) {
        firstPrimary = code;
        break;
      }
    }
    final legacyAllocations = <CalculatorCoveringAllocation>[];
    var sequence = 1;
    for (var fieldOffset = 0; fieldOffset < normalizedFields.length; fieldOffset++) {
      final field = normalizedFields[fieldOffset];
      final secondaryQuantity = field.allocations.fold<int>(
        0,
        (sum, allocation) => sum + allocation.quantity,
      );
      final primaryQuantity = math.max(0, sheetsPerField - secondaryQuantity).toInt();
      final fieldPrimary = field.coveringCode?.trim();
      if (fieldOffset > 0 && primaryQuantity > 0 && (fieldPrimary ?? '').isNotEmpty) {
        legacyAllocations.add(
          CalculatorCoveringAllocation(
            allocationId: 'field-${field.fieldIndex}-primary-$sequence',
            coveringCode: fieldPrimary,
            quantity: primaryQuantity,
          ),
        );
        sequence += 1;
      }
      for (final allocation in field.allocations) {
        if (allocation.quantity <= 0) continue;
        legacyAllocations.add(
          CalculatorCoveringAllocation(
            allocationId: allocation.allocationId.trim().isEmpty
                ? 'field-${field.fieldIndex}-split-$sequence'
                : allocation.allocationId,
            coveringCode: allocation.coveringCode,
            quantity: allocation.quantity,
          ),
        );
        sequence += 1;
      }
    }

    final tabs = [...state.setContents];
    var updated = tabs[tabIndex].withCoveringFields(normalizedFields);
    updated = updated
        .withGeometryText('covering_code', firstPrimary)
        .withGeometryText('glass_type_code', firstPrimary)
        .withCoveringAllocations(legacyAllocations)
        .withCoveringFields(normalizedFields)
        .copyWith(items: const []);
    tabs[tabIndex] = updated;
    state = state.copyWith(
      setContents: tabs,
      clearCovering: true,
      clearMaxGlassFieldWidth: true,
    );
  }

  void _setModuleCoveringAllocations(
    int tabIndex,
    List<CalculatorCoveringAllocation> allocations,
  ) {
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex]
        .withCoveringAllocations(allocations)
        .withoutCoveringFields()
        .copyWith(items: const []);
    state = state.copyWith(
      setContents: tabs,
      clearCovering: true,
      clearMaxGlassFieldWidth: true,
    );
  }

  void setSetContentModuleMaxGlassFieldWidth(int tabIndex, int? value) {
    _ensureSetContentModuleCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex]
        .withGeometryValue('max_glass_field_width_mm', value)
        .copyWith(items: const []);
    state = state.copyWith(
      setContents: tabs,
      clearMaxGlassFieldWidth: true,
    );
  }

  void setColor(String? value) => state = state.copyWith(
        colorCode: value,
        clearColor: value == null || value.isEmpty,
      );

  void setProductionColorCode(String? value) => state = state.copyWith(
        productionColorCode: value,
        clearProductionColorCode: value == null || value.trim().isEmpty,
      );

  void setHandover(String? value) => state = state.copyWith(
        handoverTypeCode: value,
        clearHandover: value == null || value.isEmpty,
      );

  void setCompletionWeek(int? value) => state = state.copyWith(
        completionWeek: value,
        clearCompletionWeek: value == null,
      );

  void setDeliveryLatest(String? value) => state = state.copyWith(
        deliveryLatestCode: value,
        clearDeliveryLatest: value == null || value.isEmpty,
      );

  void setAdditionalDiscountEnabled(bool value) =>
      state = state.copyWith(additionalDiscountEnabled: value);

  void setAdditionalDiscountPct(String value) {
    final parsed = num.tryParse(value.trim().replaceAll(',', '.'));
    state = state.copyWith(
      additionalDiscountPct: (parsed ?? 0).clamp(0, 100),
    );
  }

  void setAdditionalDiscountReasonCode(String? value) {
    final normalized = value?.trim();
    state = state.copyWith(
      additionalDiscountReasonCode: normalized,
      clearAdditionalDiscountReasonCode:
          normalized == null || normalized.isEmpty,
    );
  }

  void setQuoteNoExternal(String value) => state = state.copyWith(
        quoteNoExternal: value.trim(),
        clearQuoteNoExternal: value.trim().isEmpty,
      );

  void setExternalNotes(String value) => state = state.copyWith(
        externalNotes: value,
        clearExternalNotes: value.trim().isEmpty,
      );

  void setRelatedCustomer(String? value) => state = state.copyWith(
        relatedCustomerId: value,
        clearRelatedCustomer: value == null || value.isEmpty,
      );

  void setBranding(Map<String, dynamic> value) => state = state.copyWith(
        branding: value,
        clearBranding: value.isEmpty,
      );

  void setEngravingEnabled(bool value) {
    if (state.branding.isEmpty) return;
    state = state.copyWith(
      branding: {
        ...state.branding,
        'engraving_enabled': value,
      },
    );
  }

  void addOptionCode(String optionCode) {
    final trimmed = optionCode.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      options: [
        ...state.options,
        CalculatorSelectedOption(optionCode: trimmed),
      ],
    );
  }

  void addCatalogOption({
    required String catalogItemId,
    String? catalogVariantId,
    num quantity = 1,
    String? salesUnitCode,
    int? schraegCount,
    List<CalculatorSelectedAdditionalHandling> additionalHandlings = const [],
  }) {
    if (catalogItemId.trim().isEmpty) return;
    state = state.copyWith(
      options: [
        ...state.options,
        CalculatorSelectedOption(
          catalogItemId: catalogItemId,
          catalogVariantId: catalogVariantId == null || catalogVariantId.trim().isEmpty ? null : catalogVariantId,
          quantity: quantity <= 0 ? 1 : quantity,
          salesUnitCode: salesUnitCode == null || salesUnitCode.trim().isEmpty ? null : salesUnitCode.trim(),
          schraegCount: schraegCount == null || schraegCount <= 0 ? null : schraegCount.clamp(1, 2).toInt(),
          additionalHandlings: additionalHandlings,
        ),
      ],
    );
  }



  void seedSetContentsIfEmpty(
    List<CalculatorSetContentTab> tabs, {
    bool preserveStructure = false,
  }) {
    if (tabs.isEmpty) return;
    if (state.setContents.isEmpty) {
      state = _withSingleModuleDimensions(state.copyWith(setContents: tabs));
      return;
    }
    if (state.setContents.any((tab) => tab.items.isNotEmpty)) return;
    if (preserveStructure) {
      state = _withSingleModuleDimensions(
        state.copyWith(
          setContents: [
            for (var i = 0; i < state.setContents.length; i++)
              state.setContents[i].copyWith(
                items: (tabs.firstWhere(
                  (tab) => tab.moduleRole == state.setContents[i].moduleRole,
                  orElse: () => tabs[i < tabs.length ? i : 0],
                )).items,
              ),
          ],
        ),
      );
      return;
    }
    state = _withSingleModuleDimensions(
      state.copyWith(setContents: _materializeSetContentDefaults(tabs, state.setContents)),
    );
  }

  /// [knownDerivedAccessorySegmentIds] are the accessory segments the server
  /// reported back. Passing them lets stale overrides be dropped; omit them
  /// when the caller has no authoritative accessory list.
  void setSetContents(
    List<CalculatorSetContentTab> tabs, {
    Set<String>? knownDerivedAccessorySegmentIds,
  }) {
    state = _withSingleModuleDimensions(
      state.copyWith(
        setContents: _withRestoredExcludedOrder(
          _withPreservedDerivedOverrides(
            tabs,
            knownDerivedAccessorySegmentIds: knownDerivedAccessorySegmentIds,
          ),
        ),
      ),
    );
  }

  /// An excluded segment drops out of the server BOM and is re-appended after
  /// all remaining calculated rows, which makes the row jump to the bottom of
  /// the list. Every other row keeps the server order, so newly calculated
  /// segments still appear in their natural place.
  List<CalculatorSetContentTab> _withRestoredExcludedOrder(
    List<CalculatorSetContentTab> tabs,
  ) {
    if (state.setContents.isEmpty) return tabs;
    final currentByRole = {
      for (final tab in state.setContents) tab.moduleRole: tab,
    };
    return [
      for (var index = 0; index < tabs.length; index++)
        () {
          final tab = tabs[index];
          final current = currentByRole[tab.moduleRole] ??
              (index < state.setContents.length
                  ? state.setContents[index]
                  : null);
          final items = _itemsWithRestoredExcludedOrder(tab.items, current);
          return identical(items, tab.items) ? tab : tab.copyWith(items: items);
        }(),
    ];
  }

  List<CalculatorSetContentItem> _itemsWithRestoredExcludedOrder(
    List<CalculatorSetContentItem> items,
    CalculatorSetContentTab? current,
  ) {
    if (current == null || current.items.isEmpty) return items;
    final previousIndexes = <String, int>{};
    for (var index = 0; index < current.items.length; index++) {
      previousIndexes.putIfAbsent(
        _setContentItemIdentity(current.items[index]),
        () => index,
      );
    }
    final held = <int, CalculatorSetContentItem>{};
    final rest = <CalculatorSetContentItem>[];
    for (final item in items) {
      final isExcluded =
          item.isCalculated && (!item.enabled || item.overrideState == 'excluded');
      final previousIndex =
          previousIndexes[_setContentItemIdentity(item)];
      if (isExcluded && previousIndex != null && !held.containsKey(previousIndex)) {
        held[previousIndex] = item;
      } else {
        rest.add(item);
      }
    }
    if (held.isEmpty) return items;
    final restored = [...rest];
    for (final position in held.keys.toList()..sort()) {
      restored.insert(
        position > restored.length ? restored.length : position,
        held[position] as CalculatorSetContentItem,
      );
    }
    return restored;
  }

  /// Derived-accessory overrides exist only on the client: the server consumes
  /// them and reports the resulting accessory list, but never echoes them back
  /// in `set_contents`. Replacing the draft with the server snapshot would
  /// therefore silently drop every accessory exclusion and quantity correction
  /// on each calculation.
  List<CalculatorSetContentTab> _withPreservedDerivedOverrides(
    List<CalculatorSetContentTab> tabs, {
    Set<String>? knownDerivedAccessorySegmentIds,
  }) {
    if (tabs.isEmpty) return tabs;
    final known = <String>{
      for (final tab in tabs)
        for (final item in tab.items)
          if (item.segmentId != null) item.segmentId!,
    };
    final carried = <CalculatorSetContentItem>[];
    for (final tab in state.setContents) {
      for (final item in tab.items) {
        if (!item.isDerivedOverride) continue;
        final segmentId = item.segmentId;
        if (segmentId == null || !known.add(segmentId)) continue;
        // An override that keeps its accessory active must be dropped once the
        // server stops reporting that accessory: the component is no longer
        // derived from the current geometry, so the override would otherwise
        // keep an unpriceable phantom row in the list forever. An excluded
        // override is the very reason its accessory is missing, so it stays.
        final isStale = knownDerivedAccessorySegmentIds != null &&
            item.enabled &&
            item.quantity > 0 &&
            !knownDerivedAccessorySegmentIds.contains(segmentId);
        if (isStale) continue;
        carried.add(item);
      }
    }
    if (carried.isEmpty) return tabs;
    final next = [...tabs];
    next[0] = next[0].copyWith(items: [...next[0].items, ...carried]);
    return next;
  }

  void syncSetContentsFromPreview(List<CalculatorSetContentTab> previewTabs) {
    if (previewTabs.isEmpty || state.setContents.isEmpty) return;
    final currentByRole = {
      for (final tab in state.setContents) tab.moduleRole: tab,
    };
    final next = <CalculatorSetContentTab>[];
    for (var index = 0; index < previewTabs.length; index++) {
      final preview = previewTabs[index];
      final current = currentByRole[preview.moduleRole] ??
          (index < state.setContents.length ? state.setContents[index] : null);
      final currentCalculated = <String, CalculatorSetContentItem>{
        for (final item in current?.items ?? const <CalculatorSetContentItem>[])
          if (item.isCalculated) _setContentItemIdentity(item): item,
      };
      final items = [
        for (final item in preview.items)
          _withPreservedOverrideMarker(
            item,
            currentCalculated[_setContentItemIdentity(item)],
          ),
      ];
      final identities = items.map(_setContentItemIdentity).toSet();
      for (final item in current?.items ?? const <CalculatorSetContentItem>[]) {
        if (item.isCalculated) continue;
        if (identities.add(_setContentItemIdentity(item))) items.add(item);
      }
      next.add(
        preview.copyWith(
          id: current?.id ?? preview.id,
          label: current?.label ?? preview.label,
          items: _itemsWithRestoredExcludedOrder(items, current),
        ),
      );
    }

    String signature(List<CalculatorSetContentTab> tabs) => jsonEncode([
          for (final tab in tabs)
            {
              'id': tab.id,
              'geometry': tab.geometryKey,
              'items': [
                for (final item in tab.items)
                  {
                    'segment': item.segmentId,
                    'article': item.articleNo ?? item.profileNo ?? item.baseCode,
                    'quantity': item.quantity,
                    'length': item.lengthMm,
                    'enabled': item.enabled,
                    'state': item.overrideState,
                    'calculated_quantity': item.calculatedQuantity,
                    'calculated_length': item.calculatedLengthMm,
                  },
              ],
            },
        ]);
    if (signature(next) == signature(state.setContents)) return;
    state = _withSingleModuleDimensions(state.copyWith(setContents: next));
  }

  /// A calculated row that the user only marked as overridden still carries the
  /// automatic quantity and length, so the server reports it back as
  /// `automatic`. Without restoring the marker the recalculated preview would
  /// silently drop the manual edit mode of the row.
  CalculatorSetContentItem _withPreservedOverrideMarker(
    CalculatorSetContentItem previewItem,
    CalculatorSetContentItem? currentItem,
  ) {
    if (currentItem == null) return previewItem;
    if (currentItem.overrideState != 'overridden') return previewItem;
    if (previewItem.overrideState != 'automatic') return previewItem;
    if (previewItem.sourceComponent['dependency_override_applied'] == true) {
      return previewItem;
    }
    return _withOverrideState(previewItem, 'overridden');
  }

  void setMissingSetPieceAbzugForArticles(
    Iterable<String> articleNos,
    bool included,
  ) {
    final next = state.missingSetPieceAbzugArticleNos.toSet();
    final normalized = articleNos
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (included) {
      next.addAll(normalized);
    } else {
      next.removeAll(normalized);
    }
    final sorted = next.toList()..sort();
    state = state.copyWith(missingSetPieceAbzugArticleNos: sorted);
  }

  void setMissingSetPieceAbzugForArticle(String articleNo, bool included) {
    setMissingSetPieceAbzugForArticles([articleNo], included);
  }

  void setSetContentsFromDefaults(List<CalculatorSetContentTab> defaults) {
    if (defaults.isEmpty) {
      state = state.copyWith(setContents: const []);
      return;
    }
    state = _withSingleModuleDimensions(
      state.copyWith(setContents: _materializeSetContentDefaults(defaults, state.setContents)),
    );
  }

  void setSetContentModuleRoles(List<String> roles) {
    final normalizedRoles = roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .take(20)
        .toList(growable: false);
    final effectiveRoles = normalizedRoles.isEmpty ? const ['main'] : normalizedRoles;
    final current = state.setContents;
    CalculatorSetContentTab? sourceWithItems;
    for (final tab in current) {
      if (tab.items.isNotEmpty) {
        sourceWithItems = tab;
        break;
      }
    }

    final next = <CalculatorSetContentTab>[];
    for (var i = 0; i < effectiveRoles.length; i++) {
      final role = effectiveRoles[i];
      final label = _moduleLabel(role, i + 1);
      if (i < current.length) {
        next.add(
          current[i].copyWith(
            id: 'part-${i + 1}',
            label: label,
            geometryKey: {
              ...current[i].geometryKey,
              'role': role,
              if (i == 0 && current[i].moduleWidthMm == null && state.widthMm != null)
                'width_mm': state.widthMm,
              if (i == 0 && current[i].moduleDepthMm == null && state.depthMm != null)
                'depth_mm': state.depthMm,
            },
          ),
        );
      } else if (sourceWithItems != null) {
        next.add(
          sourceWithItems.duplicateAs(i + 1).copyWith(
                label: label,
                geometryKey: {'role': role},
              ),
        );
      } else {
        next.add(
          CalculatorSetContentTab(
            id: 'part-${i + 1}',
            label: label,
            geometryKey: {
              'role': role,
              if (i == 0 && state.widthMm != null) 'width_mm': state.widthMm,
              if (i == 0 && state.depthMm != null) 'depth_mm': state.depthMm,
            },
            items: const [],
          ),
        );
      }
    }
    state = _withSingleModuleDimensions(state.copyWith(setContents: next));
  }

  void setSetContentModuleCount(int count) {
    final normalizedCount = count.clamp(1, 20).toInt();
    final roles = <String>[
      for (var i = 0; i < normalizedCount; i++) i < state.setContents.length ? state.setContents[i].moduleRole : '',
    ];
    for (var i = 0; i < roles.length; i++) {
      if (roles[i].trim().isEmpty) roles[i] = _fallbackModuleRole(i);
    }
    setSetContentModuleRoles(roles);
  }

  void incrementSetContentModuleCount() {
    final currentCount = state.setContents.isEmpty ? 1 : state.setContents.length;
    final roles = [
      for (var i = 0; i < currentCount; i++)
        i < state.setContents.length && state.setContents[i].moduleRole.isNotEmpty
            ? state.setContents[i].moduleRole
            : _fallbackModuleRole(i),
      'module_${currentCount + 1}',
    ];
    setSetContentModuleRoles(roles);
  }

  void updateSetContentModuleManufacturingSplit(
    int tabIndex,
    String kind,
    String mode,
    List<int> cutPositionsMm,
  ) {
    _ensureSetContentModuleCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex].withManufacturingSplit(
      kind,
      mode: mode,
      cutPositionsMm: cutPositionsMm,
    );
    state = state.copyWith(setContents: tabs);
  }

  void updateSetContentModuleGeometry(int tabIndex, String key, String value) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;
    _ensureSetContentModuleCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final parsed = int.tryParse(value.trim());
    if (normalizedKey == 'width_mm') {
      _updateBalancedSetContentModuleDimension(tabIndex, normalizedKey, parsed);
      return;
    }
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex].withGeometryValue(normalizedKey, parsed);
    state = state.copyWith(setContents: tabs);
  }

  void setSetContentModuleWallGutterBlendeRules(int tabIndex, bool enabled) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex].withGeometryBool(
      'wall_gutter_blende_rules_enabled',
      enabled,
    );
    state = state.copyWith(setContents: tabs);
  }

  void _updateBalancedSetContentModuleDimension(int tabIndex, String key, int? value) {
    final tabs = [...state.setContents];
    final total = state.widthMm;
    if (value == null || total == null || total <= 0) {
      tabs[tabIndex] = tabs[tabIndex].withGeometryValue(key, value);
      state = state.copyWith(setContents: tabs);
      return;
    }

    if (tabs.length == 1) {
      tabs[tabIndex] = tabs[tabIndex].withGeometryValue(key, total);
      state = state.copyWith(setContents: tabs);
      return;
    }

    final neighborIndex = tabIndex < tabs.length - 1 ? tabIndex + 1 : tabIndex - 1;
    int dimensionFor(CalculatorSetContentTab tab) => tab.moduleWidthMm ?? 0;
    var fixedValue = 0;
    for (var i = 0; i < tabs.length; i++) {
      if (i == tabIndex || i == neighborIndex) continue;
      fixedValue += dimensionFor(tabs[i]);
    }

    final availableForPair = total - fixedValue;
    final currentValue = value.clamp(0, availableForPair < 0 ? 0 : availableForPair).toInt();
    final neighborValue = availableForPair > 0 ? availableForPair - currentValue : 0;
    tabs[tabIndex] = tabs[tabIndex].withGeometryValue(key, currentValue);
    tabs[neighborIndex] = tabs[neighborIndex].withGeometryValue(key, neighborValue);
    state = state.copyWith(setContents: tabs);
  }

  List<CalculatorSetContentTab> _syncFirstModuleDimension(
    List<CalculatorSetContentTab> source, {
    required String key,
    required int? total,
  }) {
    if (source.isEmpty) return source;
    final tabs = [...source];
    if (total == null) {
      tabs[0] = tabs[0].withGeometryValue(key, null);
      return tabs;
    }

    int dimensionFor(CalculatorSetContentTab tab) =>
        key == 'depth_mm' ? (tab.moduleDepthMm ?? 0) : (tab.moduleWidthMm ?? 0);
    final otherTotal = tabs.skip(1).fold<int>(0, (sum, tab) => sum + dimensionFor(tab));
    final firstValue = tabs.length == 1 || otherTotal == 0
        ? total
        : (total - otherTotal).clamp(0, total).toInt();
    tabs[0] = tabs[0].withGeometryValue(key, firstValue);
    return tabs;
  }

  List<CalculatorSetContentTab> _syncFirstModuleDepth(
    List<CalculatorSetContentTab> source, {
    required int? previousTotal,
    required int? nextTotal,
  }) {
    if (source.isEmpty) return source;
    final firstDepth = source.first.moduleDepthMm;
    if (firstDepth != null && firstDepth != previousTotal) return source;

    final tabs = [...source];
    tabs[0] = tabs[0].withGeometryValue('depth_mm', nextTotal);
    return tabs;
  }

  CalculatorDraft _withSingleModuleDimensions(CalculatorDraft draft) {
    if (draft.modelCode?.trim().toUpperCase() != 'SR' || draft.setContents.isEmpty) {
      return draft;
    }
    final firstModule = draft.setContents.first;
    if (firstModule.moduleWidthMm == draft.widthMm &&
        firstModule.moduleDepthMm == draft.depthMm) {
      return draft;
    }
    final tabs = [...draft.setContents];
    tabs[0] = firstModule
        .withGeometryValue('width_mm', draft.widthMm)
        .withGeometryValue('depth_mm', draft.depthMm);
    return draft.copyWith(setContents: tabs);
  }

  void setSetContentItemsEnabled(List<({int tabIndex, int itemIndex})> refs, bool enabled) {
    if (refs.isEmpty) return;
    final tabs = [...state.setContents];
    var changed = false;
    for (final ref in refs) {
      if (ref.tabIndex < 0 || ref.tabIndex >= tabs.length) continue;
      final tab = tabs[ref.tabIndex];
      if (ref.itemIndex < 0 || ref.itemIndex >= tab.items.length) continue;
      final items = [...tab.items];
      if (items[ref.itemIndex].enabled == enabled) continue;
      items[ref.itemIndex] = items[ref.itemIndex].copyWith(enabled: enabled);
      tabs[ref.tabIndex] = tab.copyWith(items: items);
      changed = true;
    }
    if (changed) state = state.copyWith(setContents: tabs);
  }

  void _ensureSetContentModuleCount(int minCount) {
    if (state.setContents.length >= minCount) return;
    setSetContentModuleCount(minCount);
  }

  List<CalculatorSetContentTab> _materializeSetContentDefaults(
    List<CalculatorSetContentTab> defaults,
    List<CalculatorSetContentTab> current,
  ) {
    final defaultTab = defaults.first;
    final blockCount = current.isEmpty ? defaults.length : current.length;
    final result = <CalculatorSetContentTab>[];
    for (var i = 0; i < blockCount; i++) {
      final currentTab = i < current.length ? current[i] : null;
      final defaultForIndex = i < defaults.length ? defaults[i] : defaultTab.duplicateAs(i + 1);
      result.add(
        defaultForIndex.copyWith(
          id: 'part-${i + 1}',
          label: _moduleLabel(currentTab?.moduleRole ?? defaultForIndex.moduleRole, i + 1),
          geometryKey: {
            ...defaultForIndex.geometryKey,
            if (currentTab != null) ...currentTab.geometryKey,
          },
          items: defaultForIndex.items.map((entry) => entry.copyWith()).toList(),
        ),
      );
    }
    return result;
  }

  void addSetContentTabFromDefault(List<CalculatorSetContentTab> defaults) {
    final source = state.setContents.isNotEmpty
        ? state.setContents.first
        : defaults.isNotEmpty
            ? defaults.first
            : null;
    if (source == null) return;
    final nextIndex = state.setContents.length + 1;
    state = state.copyWith(
      setContents: [
        ...state.setContents,
        source.duplicateAs(nextIndex),
      ],
    );
  }

  void removeSetContentTab(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final next = [...state.setContents]..removeAt(tabIndex);
    state = state.copyWith(
      setContents: [
        for (var i = 0; i < next.length; i++) next[i].copyWith(id: 'part-${i + 1}', label: _moduleLabel(next[i].moduleRole, i + 1)),
      ],
    );
  }


  String _fallbackModuleRole(int zeroBasedIndex) {
    const roles = ['main', 'small', 'left', 'right', 'middle'];
    return zeroBasedIndex >= 0 && zeroBasedIndex < roles.length ? roles[zeroBasedIndex] : 'module_${zeroBasedIndex + 1}';
  }

  String _moduleLabel(String? role, int index) {
    final value = role?.trim() ?? '';
    if (value.isEmpty) return 'Module $index';
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  bool _coveringAllocationsEqual(
    List<CalculatorCoveringAllocation> left,
    List<CalculatorCoveringAllocation> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.allocationId != b.allocationId ||
          a.coveringCode != b.coveringCode ||
          a.quantity != b.quantity) {
        return false;
      }
    }
    return true;
  }

  CalculatorSetContentItem _withOverrideState(CalculatorSetContentItem item, String stateCode) {
    final source = <String, dynamic>{
      ...((item.raw['source_component'] is Map)
          ? Map<String, dynamic>.from(item.raw['source_component'] as Map)
          : const <String, dynamic>{}),
      'override_state': stateCode,
      'override_applied': false,
    };
    if (stateCode == 'automatic') {
      source.remove('dependency_override_applied');
      source.remove('dependency_quantity');
      source.remove('dependency_length_mm');
      source.remove('dependency_installed_length_mm');
    }
    return item.copyWith(raw: {...item.raw, 'source_component': source});
  }

  void resetSetContentItemOverride(int tabIndex, int itemIndex) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    final item = items[itemIndex];
    if (!item.isCalculated) return;
    items[itemIndex] = _withOverrideState(
      item.copyWith(
        quantity: item.calculatedQuantity ?? item.quantity,
        lengthMm: item.calculatedLengthMm,
        clearLength: item.calculatedLengthMm == null,
        enabled: true,
      ),
      'automatic',
    );
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab.copyWith(items: items);
    state = state.copyWith(setContents: tabs);
  }

  bool _setContentItemHasArticle(
    CalculatorSetContentItem item,
    String articleNo,
  ) {
    final wanted = articleNo.trim();
    if (wanted.isEmpty) return false;
    for (final value in [item.articleNo, item.profileNo, item.baseCode]) {
      final normalized = value?.trim() ?? '';
      if (normalized == wanted ||
          normalized.split(RegExp(r'\s+')).first == wanted) {
        return true;
      }
    }
    return false;
  }

  num _setContentSourceNumber(
    CalculatorSetContentItem item,
    String snakeKey,
    String camelKey,
    num fallback,
  ) {
    final raw = item.sourceComponent[snakeKey] ?? item.sourceComponent[camelKey];
    return raw is num ? raw : num.tryParse('$raw') ?? fallback;
  }

  /// Applies every requested article change of the module editor in one state
  /// update, so the dependent recalculation (geometry, covering, BOM) runs once.
  void applySetContentArticleOverrides(
    int tabIndex,
    List<CalculatorSetContentArticleOverride> changes,
  ) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    if (changes.isEmpty) return;
    final current = state.setContents[tabIndex];
    var tab = current;
    for (final change in changes) {
      tab = change.resetToCalculated
          ? _resetArticleOverride(tab, change.articleNo)
          : _applyArticleOverride(
              tab,
              change.articleNo,
              quantity: change.quantity,
              installedLengthMm: change.installedLengthMm,
              enabled: change.enabled,
            );
    }
    if (identical(tab, current)) return;
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab;
    state = state.copyWith(setContents: tabs);
  }

  CalculatorSetContentTab _applyArticleOverride(
    CalculatorSetContentTab tab,
    String articleNo, {
    required int quantity,
    required int installedLengthMm,
    required bool enabled,
  }) {
    final matchingIndexes = <int>[
      for (var index = 0; index < tab.items.length; index++)
        if (tab.items[index].isCalculated &&
            _setContentItemHasArticle(tab.items[index], articleNo))
          index,
    ];
    if (matchingIndexes.isEmpty) return tab;

    final items = [...tab.items];
    final safeQuantity = math.max(1, quantity).toInt();
    final safeInstalledLength = math.max(1, installedLengthMm).toInt();
    final currentCutTotal = matchingIndexes.fold<double>(0, (sum, index) {
      final item = items[index];
      final cutGroupCount = _setContentSourceNumber(
        item,
        'cut_group_count',
        'cutGroupCount',
        1,
      );
      if (cutGroupCount <= 1) return sum;
      return sum + (item.lengthMm ?? 0).toDouble();
    });
    final useCurrentCutWeights = currentCutTotal >= 100;
    final calculatedCutTotal = matchingIndexes.fold<double>(0, (sum, index) {
      final item = items[index];
      final cutGroupCount = _setContentSourceNumber(
        item,
        'cut_group_count',
        'cutGroupCount',
        1,
      );
      if (cutGroupCount <= 1) return sum;
      final weight = useCurrentCutWeights
          ? item.lengthMm
          : item.calculatedLengthMm;
      return sum + (weight ?? 0).toDouble();
    });
    var assignedLength = 0;

    for (var position = 0; position < matchingIndexes.length; position++) {
      final index = matchingIndexes[position];
      final item = items[index];
      if (!enabled) {
        items[index] = _withOverrideState(
          item.copyWith(enabled: false),
          'excluded',
        );
        continue;
      }
      final splitCount = math.max(
        1,
        _setContentSourceNumber(item, 'split_count', 'splitCount', 1).round(),
      ).toInt();
      final cutGroupCount = math.max(
        1,
        _setContentSourceNumber(
          item,
          'cut_group_count',
          'cutGroupCount',
          1,
        ).round(),
      ).toInt();
      final itemQuantity = cutGroupCount > 1
          ? safeQuantity
          : safeQuantity * splitCount;
      final cutWeight = ((useCurrentCutWeights
              ? item.lengthMm
              : item.calculatedLengthMm) ?? 0)
          .toDouble();
      int itemLength;
      if (cutGroupCount > 1 && calculatedCutTotal > 0) {
        final isLast = position == matchingIndexes.length - 1;
        itemLength = isLast
            ? math.max(1, safeInstalledLength - assignedLength).toInt()
            : math.max(
                1,
                (safeInstalledLength * cutWeight / calculatedCutTotal).round(),
              ).toInt();
        assignedLength += itemLength;
      } else {
        itemLength = math
            .max(1, (safeInstalledLength / splitCount).round())
            .toInt();
      }
      items[index] = _withOverrideState(
        item.copyWith(
          quantity: itemQuantity,
          lengthMm: itemLength,
          enabled: true,
        ),
        'overridden',
      );
    }
    return tab.copyWith(items: items);
  }

  CalculatorSetContentTab _resetArticleOverride(
    CalculatorSetContentTab tab,
    String articleNo,
  ) {
    final items = [...tab.items];
    var changed = false;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (!item.isCalculated || !_setContentItemHasArticle(item, articleNo)) {
        continue;
      }
      items[index] = _withOverrideState(
        item.copyWith(
          quantity: item.calculatedQuantity ?? item.quantity,
          lengthMm: item.calculatedLengthMm,
          clearLength: item.calculatedLengthMm == null,
          enabled: true,
        ),
        'automatic',
      );
      changed = true;
    }
    if (!changed) return tab;
    return tab.copyWith(items: items);
  }

  void removeManualSetContentItem(int tabIndex, int itemIndex) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    if (!tab.items[itemIndex].isManual) return;
    final items = [...tab.items]..removeAt(itemIndex);
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab.copyWith(items: items);
    state = state.copyWith(setContents: tabs);
  }

  void addManualSetContentItem(
    int tabIndex,
    CalculatorCatalogItemOption catalogItem, {
    CalculatorCatalogVariantOption? variant,
    num quantity = 1,
    String? salesUnitCode,
    int? lengthMm,
    String? manufacturingFieldKind,
    int? manufacturingFieldIndex,
    int? manufacturingFieldCount,
  }) {
    if (state.setContents.isEmpty) return;
    final normalizedTab = tabIndex < 0 || tabIndex >= state.setContents.length ? 0 : tabIndex;
    final tab = state.setContents[normalizedTab];
    final unit = salesUnitCode ??
        variant?.defaultSalesUnitCode ??
        catalogItem.defaultSalesUnitCode ??
        catalogItem.measureTypeCode ??
        'piece';
    final effectiveLength = lengthMm ?? variant?.lengthMm ?? catalogItem.defaultLengthMm;
    final articleNo = variant?.articleNo ?? variant?.profileNo ?? catalogItem.profileNo ?? catalogItem.baseCode;
    final item = CalculatorSetContentItem(
      catalogItemId: catalogItem.id,
      catalogVariantId: variant?.id,
      quantity: quantity <= 0 ? 1 : quantity,
      salesUnitCode: unit,
      lengthMm: effectiveLength,
      name: catalogItem.name,
      itemTypeCode: catalogItem.itemTypeCode,
      baseCode: catalogItem.baseCode,
      profileNo: variant?.profileNo ?? catalogItem.profileNo,
      articleNo: articleNo,
      variantSku: variant?.variantSku,
      unitCode: unit,
      editableLength: catalogItem.itemTypeCode.toLowerCase().contains('profile'),
      raw: {
        'source_component': {
          'source_type': 'manual',
          'segment_id': 'manual:${tab.id}:${catalogItem.id}:${DateTime.now().microsecondsSinceEpoch}',
          'name': catalogItem.name,
          'item_type_code': catalogItem.itemTypeCode,
          'base_code': catalogItem.baseCode,
          if (variant?.variantSku != null) 'variant_sku': variant!.variantSku,
          if ((variant?.profileNo ?? catalogItem.profileNo) != null)
            'profile_no': variant?.profileNo ?? catalogItem.profileNo,
          'article_no': articleNo,
          'unit_code': unit,
          if ((manufacturingFieldKind ?? '').isNotEmpty)
            'manufacturing_field_kind': manufacturingFieldKind,
          if (manufacturingFieldIndex != null && manufacturingFieldIndex > 0)
            'manufacturing_field_index': manufacturingFieldIndex,
          if (manufacturingFieldCount != null && manufacturingFieldCount > 0)
            'manufacturing_field_count': manufacturingFieldCount,
        },
      },
    );
    final tabs = [...state.setContents];
    tabs[normalizedTab] = tab.copyWith(items: [...tab.items, item]);
    state = state.copyWith(setContents: tabs);
  }

  void upsertDerivedAccessoryOverride(
    Map<String, dynamic> accessory,
    num quantity,
    bool enabled, {
    int? orderIndex,
  }) {
    final source = accessory['source'] is Map
        ? Map<String, dynamic>.from(accessory['source'] as Map)
        : <String, dynamic>{};
    final segments = accessory['segments'] is List ? accessory['segments'] as List : const [];
    final firstSegment = segments.isNotEmpty && segments.first is Map
        ? Map<String, dynamic>.from(segments.first as Map)
        : <String, dynamic>{};
    final segmentId = '${firstSegment['segment_id'] ?? source['segment_id'] ?? ''}'.trim();
    final catalogItemId = '${accessory['catalog_item_id'] ?? source['catalog_item_id'] ?? ''}'.trim();
    if (segmentId.isEmpty || catalogItemId.isEmpty || state.setContents.isEmpty) return;

    final tabs = [...state.setContents];
    for (var tabIndex = 0; tabIndex < tabs.length; tabIndex++) {
      final tab = tabs[tabIndex];
      final itemIndex = tab.items.indexWhere((item) => item.segmentId == segmentId && item.isDerivedOverride);
      if (itemIndex < 0) continue;
      final items = [...tab.items];
      final existing = items[itemIndex];
      items[itemIndex] = existing.copyWith(
        quantity: quantity,
        enabled: enabled,
        raw: orderIndex == null
            ? existing.raw
            : {
                ...existing.raw,
                'source_component': {
                  ...existing.sourceComponent,
                  'derived_order_index': orderIndex,
                },
              },
      );
      tabs[tabIndex] = tab.copyWith(items: items);
      state = state.copyWith(setContents: tabs);
      return;
    }

    final tab = tabs.first;
    final unit = '${accessory['unit_code'] ?? 'piece'}';
    final item = CalculatorSetContentItem(
      catalogItemId: catalogItemId,
      catalogVariantId: accessory['catalog_variant_id']?.toString(),
      quantity: quantity,
      salesUnitCode: unit,
      name: accessory['name']?.toString(),
      itemTypeCode: 'accessory',
      baseCode: accessory['article_no']?.toString(),
      profileNo: accessory['profile_no']?.toString(),
      articleNo: accessory['article_no']?.toString(),
      unitCode: unit,
      enabled: enabled,
      raw: {
        'source_component': {
          ...source,
          'source_type': 'derived_accessory_override',
          'segment_id': segmentId,
          'name': accessory['name'],
          'article_no': accessory['article_no'],
          'profile_no': accessory['profile_no'],
          'unit_code': unit,
          if (orderIndex != null) 'derived_order_index': orderIndex,
        },
      },
    );
    tabs[0] = tab.copyWith(items: [...tab.items, item]);
    state = state.copyWith(setContents: tabs);
  }

  void updateSetContentItemQuantity(int tabIndex, int itemIndex, num quantity) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    items[itemIndex] = _withOverrideState(
      items[itemIndex].copyWith(quantity: quantity <= 0 ? 1 : quantity),
      items[itemIndex].isCalculated ? 'overridden' : items[itemIndex].overrideState,
    );
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab.copyWith(items: items);
    state = state.copyWith(setContents: tabs);
  }

  void updateSetContentAggregateLineQuantity(List<({int tabIndex, int itemIndex})> refs, num quantity) {
    if (refs.isEmpty) return;
    final normalizedQuantity = quantity <= 0 ? 1 : quantity;
    final current = state.setContents;
    var currentTotal = 0.0;
    for (final ref in refs) {
      if (ref.tabIndex < 0 || ref.tabIndex >= current.length) continue;
      final tab = current[ref.tabIndex];
      if (ref.itemIndex < 0 || ref.itemIndex >= tab.items.length) continue;
      currentTotal += tab.items[ref.itemIndex].quantity.toDouble();
    }
    if (currentTotal <= 0) currentTotal = refs.length.toDouble();

    final tabs = [...current];
    var changed = false;
    for (final ref in refs) {
      if (ref.tabIndex < 0 || ref.tabIndex >= tabs.length) continue;
      final tab = tabs[ref.tabIndex];
      if (ref.itemIndex < 0 || ref.itemIndex >= tab.items.length) continue;
      final items = [...tab.items];
      final currentItem = items[ref.itemIndex];
      final ratio = currentTotal <= 0 ? 1 / refs.length : currentItem.quantity.toDouble() / currentTotal;
      final itemQuantity = normalizedQuantity * ratio;
      items[ref.itemIndex] = currentItem.copyWith(quantity: itemQuantity <= 0 ? 1 : itemQuantity);
      tabs[ref.tabIndex] = tab.copyWith(items: items);
      changed = true;
    }
    if (changed) state = state.copyWith(setContents: tabs);
  }


  /// Writes the buffered quantity and length of one row in a single state
  /// update, so a manual edit costs exactly one recalculation instead of one
  /// per keystroke and per field.
  void updateSetContentItemValues(
    int tabIndex,
    int itemIndex, {
    num? quantity,
    num? lengthMm,
    bool updateLength = false,
  }) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    if (quantity == null && !updateLength) return;
    final items = [...tab.items];
    var item = items[itemIndex];
    if (quantity != null) {
      item = item.copyWith(quantity: quantity <= 0 ? 1 : quantity);
    }
    if (updateLength) {
      item = item.copyWith(lengthMm: lengthMm, clearLength: lengthMm == null);
    }
    items[itemIndex] = _withOverrideState(
      item,
      item.isCalculated ? 'overridden' : item.overrideState,
    );
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab.copyWith(items: items);
    state = state.copyWith(setContents: tabs);
  }


  void toggleSetContentItemEnabled(int tabIndex, int itemIndex) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    final currentItem = items[itemIndex];
    final nextEnabled = !currentItem.enabled;
    items[itemIndex] = currentItem.isCalculated
        ? _withOverrideState(currentItem.copyWith(enabled: nextEnabled), nextEnabled ? 'overridden' : 'excluded')
        : currentItem.copyWith(enabled: nextEnabled);
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab.copyWith(items: items);
    state = state.copyWith(setContents: tabs);
  }

  void updateOptionAdditionalHandlings(
    int index,
    List<CalculatorSelectedAdditionalHandling> additionalHandlings,
  ) {
    if (index < 0 || index >= state.options.length) return;
    final next = [...state.options];
    next[index] = next[index].copyWith(additionalHandlings: additionalHandlings);
    state = state.copyWith(options: next);
  }

  void updateOptionQuantity(int index, num quantity) {
    if (index < 0 || index >= state.options.length) return;
    final next = [...state.options];
    next[index] = next[index].copyWith(quantity: quantity <= 0 ? 1 : quantity);
    state = state.copyWith(options: next);
  }

  void removeOptionAt(int index) {
    final next = [...state.options]..removeAt(index);
    state = state.copyWith(options: next);
  }
}

final calculatorDraftProvider = NotifierProvider<CalculatorDraftNotifier, CalculatorDraft>(
  CalculatorDraftNotifier.new,
);

final calculatorQuoteNumberPreviewProvider = FutureProvider.autoDispose<String?>((ref) async {
  final request = ref.watch(
    calculatorDraftProvider.select(
      (draft) => (
        organizationId: draft.organizationId?.trim() ?? '',
        commissionName: draft.quoteNoExternal?.trim() ?? '',
      ),
    ),
  );
  if (request.commissionName.isEmpty) return null;
  final repository = ref.watch(calculatorRepositoryProvider);

  var cancelled = false;
  final completer = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 350), () => completer.complete());
  ref.onDispose(() {
    cancelled = true;
    timer.cancel();
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future;
  if (cancelled) return null;

  return repository.previewQuoteNumber(
    organizationId: request.organizationId.isEmpty ? null : request.organizationId,
    commissionName: request.commissionName,
  );
});

class CalculatorResultNotifier extends Notifier<AsyncValue<CalculatorResult?>> {
  @override
  AsyncValue<CalculatorResult?> build() => const AsyncValue.data(null);

  void clear() => state = const AsyncValue.data(null);

  void setLoading() => state = const AsyncValue.loading();

  void setData(CalculatorResult result) => state = AsyncValue.data(result);

  void setError(Object error, StackTrace stackTrace) => state = AsyncValue.error(error, stackTrace);
}

final calculatorResultProvider = NotifierProvider<CalculatorResultNotifier, AsyncValue<CalculatorResult?>>(
  CalculatorResultNotifier.new,
);

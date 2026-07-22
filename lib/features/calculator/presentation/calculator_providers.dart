import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/calculator_models.dart';
import '../data/calculator_repository.dart';

final calculatorRepositoryProvider = Provider<CalculatorRepository>((ref) {
  return CalculatorRepository(ref.watch(apiClientProvider));
});

final calculatorContextProvider = FutureProvider<CalculatorContext>((ref) async {
  return ref.watch(calculatorRepositoryProvider).fetchContext();
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
    'covering_code': draft.coveringCode,
    'color_code': draft.colorCode,
    'roof_angle_deg': draft.roofAngleDeg,
    'roof_rear_height_mm': draft.roofRearHeightMm,
    'roof_front_height_mm': draft.roofFrontHeightMm,
    'force_odd_beams': draft.forceOddBeams,
    'wall_mounted': draft.wallMounted,
    'max_glass_field_width_mm': draft.maxGlassFieldWidthMm,
    'missing_set_piece_abzug_article_nos': [
      ...draft.missingSetPieceAbzugArticleNos,
    ]..sort(),
    'modules': [
      for (final tab in draft.setContents)
        {
          'id': tab.id,
          'role': tab.moduleRole,
          'width_mm': tab.moduleWidthMm,
          'depth_mm': tab.moduleDepthMm,
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

  void setWallMounted(bool value) => state = state.copyWith(wallMounted: value);

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

  void setColor(String? value) => state = state.copyWith(
        colorCode: value,
        clearColor: value == null || value.isEmpty,
      );

  void setHandover(String? value) => state = state.copyWith(
        handoverTypeCode: value,
        clearHandover: value == null || value.isEmpty,
      );

  void setCompletionWeek(int? value) => state = state.copyWith(
        completionWeek: value,
        clearCompletionWeek: value == null,
      );

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

  void setSetContents(List<CalculatorSetContentTab> tabs) {
    state = _withSingleModuleDimensions(state.copyWith(setContents: tabs));
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

  CalculatorSetContentItem _withOverrideState(CalculatorSetContentItem item, String stateCode) {
    final source = <String, dynamic>{
      ...((item.raw['source_component'] is Map)
          ? Map<String, dynamic>.from(item.raw['source_component'] as Map)
          : const <String, dynamic>{}),
      'override_state': stateCode,
      'override_applied': false,
    };
    return item.copyWith(raw: {...item.raw, 'source_component': source});
  }

  void setSetContentItemOverride(int tabIndex, int itemIndex, bool enabled) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    final item = items[itemIndex];
    if (!item.isCalculated) return;
    items[itemIndex] = _withOverrideState(item, enabled ? 'overridden' : 'automatic');
    final tabs = [...state.setContents];
    tabs[tabIndex] = tab.copyWith(items: items);
    state = state.copyWith(setContents: tabs);
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

  void addManualSetContentItem(
    int tabIndex,
    CalculatorCatalogItemOption catalogItem, {
    CalculatorCatalogVariantOption? variant,
    num quantity = 1,
    String? salesUnitCode,
    int? lengthMm,
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
        },
      },
    );
    final tabs = [...state.setContents];
    tabs[normalizedTab] = tab.copyWith(items: [...tab.items, item]);
    state = state.copyWith(setContents: tabs);
  }

  void upsertDerivedAccessoryOverride(Map<String, dynamic> accessory, num quantity, bool enabled) {
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
      items[itemIndex] = items[itemIndex].copyWith(quantity: quantity, enabled: enabled);
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

  void updateSetContentItemLength(int tabIndex, int itemIndex, num? lengthMm) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    items[itemIndex] = _withOverrideState(
      items[itemIndex].copyWith(
        lengthMm: lengthMm,
        clearLength: lengthMm == null,
      ),
      items[itemIndex].isCalculated ? 'overridden' : items[itemIndex].overrideState,
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

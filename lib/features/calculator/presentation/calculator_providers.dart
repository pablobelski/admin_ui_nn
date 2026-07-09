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
  final key = ref.watch(
    calculatorDraftProvider.select(
      (draft) => (
        templateId: draft.templateId,
        priceMode: draft.priceMode,
        modelCode: draft.modelCode,
        widthMm: draft.widthMm,
        depthMm: draft.depthMm,
        heightMm: draft.heightMm,
        coveringCode: draft.coveringCode,
        colorCode: draft.colorCode,
      ),
    ),
  );
  ref.watch(calculatorSetContentsRefreshTickProvider);

  if (key.templateId == null || key.templateId!.isEmpty) {
    return const CalculatorSetContentsPreview(tabs: [], source: {}, trace: [], warnings: [], raw: {});
  }

  final requestDraft = CalculatorDraft(
    templateId: key.templateId,
    priceMode: key.priceMode,
    modelCode: key.modelCode,
    widthMm: key.widthMm,
    depthMm: key.depthMm,
    heightMm: key.heightMm,
    coveringCode: key.coveringCode,
    colorCode: key.colorCode,
  );
  return ref.watch(calculatorRepositoryProvider).fetchSetContents(requestDraft);
});

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
    state = CalculatorDraft.fromCalculationJson(quote.input, productFamilyId: quote.productFamilyId);
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
    );
  }

  void setPriceMode(String? value) {
    if (value == null || value.isEmpty) return;
    state = state.copyWith(priceMode: value);
  }

  void setModel(String? value) {
    final normalized = value?.trim();
    final nextValue = normalized == null || normalized.isEmpty ? null : normalized;
    if (nextValue == state.modelCode) return;
    state = state.copyWith(
      modelCode: nextValue,
      clearModel: nextValue == null,
      setContents: const [],
    );
  }

  void setWidth(String value) => state = state.copyWith(
        widthMm: int.tryParse(value),
        clearWidth: value.trim().isEmpty,
      );

  void setDepth(String value) => state = state.copyWith(
        depthMm: int.tryParse(value),
        clearDepth: value.trim().isEmpty,
      );

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



  void seedSetContentsIfEmpty(List<CalculatorSetContentTab> tabs) {
    if (tabs.isEmpty) return;
    if (state.setContents.isEmpty) {
      state = state.copyWith(setContents: tabs);
      return;
    }
    if (state.setContents.any((tab) => tab.items.isNotEmpty)) return;
    state = state.copyWith(setContents: _materializeSetContentDefaults(tabs, state.setContents));
  }

  void setSetContents(List<CalculatorSetContentTab> tabs) {
    state = state.copyWith(setContents: tabs);
  }

  void setSetContentsFromDefaults(List<CalculatorSetContentTab> defaults) {
    if (defaults.isEmpty) {
      state = state.copyWith(setContents: const []);
      return;
    }
    state = state.copyWith(setContents: _materializeSetContentDefaults(defaults, state.setContents));
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
            geometryKey: {'role': role},
            items: const [],
          ),
        );
      }
    }
    state = state.copyWith(setContents: next);
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
      _updateBalancedSetContentModuleWidth(tabIndex, parsed);
      return;
    }
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex].withGeometryValue(normalizedKey, parsed);
    state = state.copyWith(setContents: tabs);
  }

  void _updateBalancedSetContentModuleWidth(int tabIndex, int? value) {
    final tabs = [...state.setContents];
    final totalWidth = state.widthMm;
    if (value == null || totalWidth == null || totalWidth <= 0) {
      tabs[tabIndex] = tabs[tabIndex].withGeometryValue('width_mm', value);
      state = state.copyWith(setContents: tabs);
      return;
    }

    if (tabs.length == 1) {
      tabs[tabIndex] = tabs[tabIndex].withGeometryValue('width_mm', totalWidth);
      state = state.copyWith(setContents: tabs);
      return;
    }

    final neighborIndex = tabIndex < tabs.length - 1 ? tabIndex + 1 : tabIndex - 1;
    var fixedWidth = 0;
    for (var i = 0; i < tabs.length; i++) {
      if (i == tabIndex || i == neighborIndex) continue;
      fixedWidth += tabs[i].moduleWidthMm ?? 0;
    }

    final availableForPair = totalWidth - fixedWidth;
    final currentWidth = value.clamp(0, availableForPair < 0 ? 0 : availableForPair).toInt();
    final neighborWidth = availableForPair > 0 ? availableForPair - currentWidth : 0;
    tabs[tabIndex] = tabs[tabIndex].withGeometryValue('width_mm', currentWidth);
    tabs[neighborIndex] = tabs[neighborIndex].withGeometryValue('width_mm', neighborWidth);
    state = state.copyWith(setContents: tabs);
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

  void updateSetContentItemQuantity(int tabIndex, int itemIndex, num quantity) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    items[itemIndex] = items[itemIndex].copyWith(quantity: quantity <= 0 ? 1 : quantity);
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

  void updateSetContentItemLength(int tabIndex, int itemIndex, int? lengthMm) {
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final tab = state.setContents[tabIndex];
    if (itemIndex < 0 || itemIndex >= tab.items.length) return;
    final items = [...tab.items];
    items[itemIndex] = items[itemIndex].copyWith(
      lengthMm: lengthMm,
      clearLength: lengthMm == null,
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
    items[itemIndex] = items[itemIndex].copyWith(enabled: !items[itemIndex].enabled);
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

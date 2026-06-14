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
      );

  void setProductFamily(String? value) => state = state.copyWith(
        productFamilyId: value,
        templateId: null,
        clearProductFamily: value == null || value.isEmpty,
        clearTemplate: true,
        clearModel: true,
        setContents: const [],
      );

  void setTemplate(String? value) => state = state.copyWith(
        templateId: value,
        clearTemplate: value == null || value.isEmpty,
        clearModel: true,
        setContents: const [],
      );

  void setPriceMode(String? value) {
    if (value == null || value.isEmpty) return;
    state = state.copyWith(priceMode: value);
  }

  void setModel(String? value) => state = state.copyWith(
        modelCode: value,
        clearModel: value == null || value.isEmpty,
        setContents: const [],
      );

  void setWidth(String value) => state = state.copyWith(
        widthMm: int.tryParse(value),
        clearWidth: value.trim().isEmpty,
      );

  void setDepth(String value) => state = state.copyWith(
        depthMm: int.tryParse(value),
        clearDepth: value.trim().isEmpty,
      );

  void setHeight(String value) => state = state.copyWith(
        heightMm: int.tryParse(value),
        clearHeight: value.trim().isEmpty,
      );

  void setCovering(String? value) => state = state.copyWith(
        coveringCode: value,
        clearCovering: value == null || value.isEmpty,
        setContents: const [],
      );

  void setColor(String? value) => state = state.copyWith(
        colorCode: value,
        clearColor: value == null || value.isEmpty,
      );

  void setHandover(String? value) => state = state.copyWith(
        handoverTypeCode: value,
        clearHandover: value == null || value.isEmpty,
      );

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

  void setSetContentBlockCount(int count) {
    final normalizedCount = count.clamp(1, 20).toInt();
    final current = state.setContents;
    CalculatorSetContentTab? sourceWithItems;
    for (final tab in current) {
      if (tab.items.isNotEmpty) {
        sourceWithItems = tab;
        break;
      }
    }
    final next = <CalculatorSetContentTab>[];
    for (var i = 0; i < normalizedCount; i++) {
      if (i < current.length) {
        next.add(current[i].copyWith(id: 'part-${i + 1}', label: 'Block ${i + 1}'));
      } else if (sourceWithItems != null) {
        next.add(sourceWithItems.duplicateAs(i + 1).copyWith(geometryKey: const {}));
      } else {
        next.add(CalculatorSetContentTab(id: 'part-${i + 1}', label: 'Block ${i + 1}', items: const []));
      }
    }
    state = state.copyWith(setContents: next);
  }

  void incrementSetContentBlockCount() {
    final currentCount = state.setContents.isEmpty ? 1 : state.setContents.length;
    setSetContentBlockCount(currentCount + 1);
  }

  void updateSetContentBlockGeometry(int tabIndex, String key, String value) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;
    _ensureSetContentBlockCount(tabIndex + 1);
    if (tabIndex < 0 || tabIndex >= state.setContents.length) return;
    final parsed = int.tryParse(value.trim());
    final tabs = [...state.setContents];
    tabs[tabIndex] = tabs[tabIndex].withGeometryValue(normalizedKey, parsed);
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

  void _ensureSetContentBlockCount(int minCount) {
    if (state.setContents.length >= minCount) return;
    setSetContentBlockCount(minCount);
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
          label: 'Block ${i + 1}',
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
        for (var i = 0; i < next.length; i++) next[i].copyWith(id: 'part-${i + 1}', label: 'Block ${i + 1}'),
      ],
    );
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

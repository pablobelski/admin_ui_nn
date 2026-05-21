import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../data/price_matrix_repository.dart';

class PriceMatrixBrowserState {
  const PriceMatrixBrowserState({
    this.matrixQuery = '',
    this.cellQuery = '',
    this.priceListId = '',
    this.selectedMatrixId,
    this.selectedCellId,
    this.offset = 0,
    this.limit = 30,
  });

  final String matrixQuery;
  final String cellQuery;
  final String priceListId;
  final String? selectedMatrixId;
  final String? selectedCellId;
  final int offset;
  final int limit;

  PriceMatrixBrowserState copyWith({
    String? matrixQuery,
    String? cellQuery,
    String? priceListId,
    String? selectedMatrixId,
    String? selectedCellId,
    int? offset,
    int? limit,
    bool clearMatrix = false,
    bool clearCell = false,
  }) {
    return PriceMatrixBrowserState(
      matrixQuery: matrixQuery ?? this.matrixQuery,
      cellQuery: cellQuery ?? this.cellQuery,
      priceListId: priceListId ?? this.priceListId,
      selectedMatrixId: clearMatrix ? null : (selectedMatrixId ?? this.selectedMatrixId),
      selectedCellId: clearCell ? null : (selectedCellId ?? this.selectedCellId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class PriceMatrixBrowserNotifier extends Notifier<PriceMatrixBrowserState> {
  @override
  PriceMatrixBrowserState build() {
    final filters = currentAdminResourceFilters(findResourceByKey('price_matrices'));
    return PriceMatrixBrowserState(priceListId: filters['price_list_id'] ?? '');
  }

  void setMatrixQuery(String value) {
    state = state.copyWith(matrixQuery: value, offset: 0, clearMatrix: true, clearCell: true);
  }

  void setCellQuery(String value) {
    state = state.copyWith(cellQuery: value, clearCell: true);
  }

  void setPriceListFilter(String? value) {
    final nextValue = value?.trim() ?? '';
    state = state.copyWith(
      priceListId: nextValue,
      offset: 0,
      clearMatrix: true,
      clearCell: true,
    );
    pushAdminResourceUrl(
      'price_matrices',
      filters: nextValue.isEmpty ? const <String, String>{} : {'price_list_id': nextValue},
    );
  }

  void selectMatrix(String? id) {
    state = state.copyWith(selectedMatrixId: id, clearCell: true);
  }

  void selectCell(String? id) {
    state = state.copyWith(selectedCellId: id);
  }

  void nextPage() {
    state = state.copyWith(offset: state.offset + state.limit, clearMatrix: true, clearCell: true);
  }

  void previousPage() {
    final nextOffset = state.offset - state.limit;
    state = state.copyWith(
      offset: nextOffset < 0 ? 0 : nextOffset,
      clearMatrix: true,
      clearCell: true,
    );
  }
}

final priceMatrixRepositoryProvider = Provider<PriceMatrixRepository>((ref) {
  return PriceMatrixRepository(ref.watch(apiClientProvider));
});

final priceMatrixBrowserProvider =
    NotifierProvider.autoDispose<PriceMatrixBrowserNotifier, PriceMatrixBrowserState>(
  PriceMatrixBrowserNotifier.new,
);

final priceMatrixListProvider = FutureProvider.autoDispose<PriceMatrixListResponse>((ref) async {
  final browser = ref.watch(priceMatrixBrowserProvider);
  final repository = ref.watch(priceMatrixRepositoryProvider);
  return repository.fetchMatrices(
    query: browser.matrixQuery,
    priceListId: browser.priceListId,
    limit: browser.limit,
    offset: browser.offset,
  );
});

final selectedPriceMatrixProvider = FutureProvider.autoDispose<PriceMatrix?>((ref) async {
  final browser = ref.watch(priceMatrixBrowserProvider);
  final selectedMatrixId = browser.selectedMatrixId;
  if (selectedMatrixId == null || selectedMatrixId.isEmpty) {
    return null;
  }

  final repository = ref.watch(priceMatrixRepositoryProvider);
  return repository.fetchMatrix(selectedMatrixId);
});

final priceMatrixCellsProvider = FutureProvider.autoDispose<PriceMatrixCellListResponse?>((ref) async {
  final browser = ref.watch(priceMatrixBrowserProvider);
  final selectedMatrixId = browser.selectedMatrixId;
  if (selectedMatrixId == null || selectedMatrixId.isEmpty) {
    return null;
  }

  final repository = ref.watch(priceMatrixRepositoryProvider);
  return repository.fetchCells(
    priceMatrixId: selectedMatrixId,
    query: browser.cellQuery,
  );
});

class PriceMatrixDependentLayerFocusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final priceMatrixDependentLayerFocusProvider =
    NotifierProvider.autoDispose<PriceMatrixDependentLayerFocusNotifier, bool>(
  PriceMatrixDependentLayerFocusNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/price_matrix_repository.dart';

class PriceMatrixBrowserState {
  const PriceMatrixBrowserState({
    this.matrixQuery = '',
    this.cellQuery = '',
    this.selectedMatrixId,
    this.selectedCellId,
    this.offset = 0,
    this.limit = 30,
  });

  final String matrixQuery;
  final String cellQuery;
  final String? selectedMatrixId;
  final String? selectedCellId;
  final int offset;
  final int limit;

  PriceMatrixBrowserState copyWith({
    String? matrixQuery,
    String? cellQuery,
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
      selectedMatrixId: clearMatrix ? null : (selectedMatrixId ?? this.selectedMatrixId),
      selectedCellId: clearCell ? null : (selectedCellId ?? this.selectedCellId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class PriceMatrixBrowserNotifier extends AutoDisposeNotifier<PriceMatrixBrowserState> {
  @override
  PriceMatrixBrowserState build() => const PriceMatrixBrowserState();

  void setMatrixQuery(String value) {
    state = state.copyWith(matrixQuery: value, offset: 0, clearMatrix: true, clearCell: true);
  }

  void setCellQuery(String value) {
    state = state.copyWith(cellQuery: value, clearCell: true);
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
    AutoDisposeNotifierProvider<PriceMatrixBrowserNotifier, PriceMatrixBrowserState>(
  PriceMatrixBrowserNotifier.new,
);

final priceMatrixListProvider = FutureProvider.autoDispose<PriceMatrixListResponse>((ref) async {
  final browser = ref.watch(priceMatrixBrowserProvider);
  final repository = ref.watch(priceMatrixRepositoryProvider);
  return repository.fetchMatrices(
    query: browser.matrixQuery,
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/rule_set_repository.dart';

class RuleWorkspaceState {
  const RuleWorkspaceState({
    this.ruleSetQuery = '',
    this.matrixQuery = '',
    this.rowQuery = '',
    this.selectedRuleSetId,
    this.selectedRuleMatrixId,
    this.selectedRowId,
    this.offset = 0,
    this.limit = 30,
  });

  final String ruleSetQuery;
  final String matrixQuery;
  final String rowQuery;
  final String? selectedRuleSetId;
  final String? selectedRuleMatrixId;
  final String? selectedRowId;
  final int offset;
  final int limit;

  RuleWorkspaceState copyWith({
    String? ruleSetQuery,
    String? matrixQuery,
    String? rowQuery,
    String? selectedRuleSetId,
    String? selectedRuleMatrixId,
    String? selectedRowId,
    int? offset,
    int? limit,
    bool clearRuleSet = false,
    bool clearMatrix = false,
    bool clearRow = false,
  }) {
    return RuleWorkspaceState(
      ruleSetQuery: ruleSetQuery ?? this.ruleSetQuery,
      matrixQuery: matrixQuery ?? this.matrixQuery,
      rowQuery: rowQuery ?? this.rowQuery,
      selectedRuleSetId: clearRuleSet ? null : (selectedRuleSetId ?? this.selectedRuleSetId),
      selectedRuleMatrixId:
          clearMatrix ? null : (selectedRuleMatrixId ?? this.selectedRuleMatrixId),
      selectedRowId: clearRow ? null : (selectedRowId ?? this.selectedRowId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class RuleWorkspaceNotifier extends Notifier<RuleWorkspaceState> {
  @override
  RuleWorkspaceState build() => const RuleWorkspaceState();

  void setRuleSetQuery(String value) {
    state = state.copyWith(
      ruleSetQuery: value,
      offset: 0,
      clearRuleSet: true,
      clearMatrix: true,
      clearRow: true,
    );
  }

  void setMatrixQuery(String value) {
    state = state.copyWith(matrixQuery: value, clearMatrix: true, clearRow: true);
  }

  void setRowQuery(String value) {
    state = state.copyWith(rowQuery: value, clearRow: true);
  }

  void selectRuleSet(String? id) {
    state = state.copyWith(selectedRuleSetId: id, clearMatrix: true, clearRow: true);
  }

  void selectRuleMatrix(String? id) {
    state = state.copyWith(selectedRuleMatrixId: id, clearRow: true);
  }

  void selectRow(String? id) {
    state = state.copyWith(selectedRowId: id);
  }

  void nextPage() {
    state = state.copyWith(
      offset: state.offset + state.limit,
      clearRuleSet: true,
      clearMatrix: true,
      clearRow: true,
    );
  }

  void previousPage() {
    final nextOffset = state.offset - state.limit;
    state = state.copyWith(
      offset: nextOffset < 0 ? 0 : nextOffset,
      clearRuleSet: true,
      clearMatrix: true,
      clearRow: true,
    );
  }
}

final ruleSetRepositoryProvider = Provider<RuleSetRepository>((ref) {
  return RuleSetRepository(ref.watch(apiClientProvider));
});

final ruleWorkspaceProvider =
    NotifierProvider.autoDispose<RuleWorkspaceNotifier, RuleWorkspaceState>(
  RuleWorkspaceNotifier.new,
);

final ruleSetListProvider = FutureProvider.autoDispose<RuleSetListResponse>((ref) async {
  final browser = ref.watch(ruleWorkspaceProvider);
  final repository = ref.watch(ruleSetRepositoryProvider);
  return repository.fetchRuleSets(
    query: browser.ruleSetQuery,
    limit: browser.limit,
    offset: browser.offset,
  );
});

final selectedRuleSetProvider = FutureProvider.autoDispose<RuleSet?>((ref) async {
  final browser = ref.watch(ruleWorkspaceProvider);
  final id = browser.selectedRuleSetId;
  if (id == null || id.isEmpty) return null;
  final repository = ref.watch(ruleSetRepositoryProvider);
  return repository.fetchRuleSet(id);
});

final ruleMatricesProvider = FutureProvider.autoDispose<RuleMatrixListResponse?>((ref) async {
  final browser = ref.watch(ruleWorkspaceProvider);
  final ruleSetId = browser.selectedRuleSetId;
  if (ruleSetId == null || ruleSetId.isEmpty) return null;
  final repository = ref.watch(ruleSetRepositoryProvider);
  return repository.fetchRuleMatrices(ruleSetId: ruleSetId, query: browser.matrixQuery);
});

final selectedRuleMatrixProvider = FutureProvider.autoDispose<RuleMatrix?>((ref) async {
  final browser = ref.watch(ruleWorkspaceProvider);
  final id = browser.selectedRuleMatrixId;
  if (id == null || id.isEmpty) return null;
  final repository = ref.watch(ruleSetRepositoryProvider);
  return repository.fetchRuleMatrix(id);
});

final ruleMatrixRowsProvider =
    FutureProvider.autoDispose<RuleMatrixRowListResponse?>((ref) async {
  final browser = ref.watch(ruleWorkspaceProvider);
  final matrixId = browser.selectedRuleMatrixId;
  if (matrixId == null || matrixId.isEmpty) return null;
  final repository = ref.watch(ruleSetRepositoryProvider);
  return repository.fetchRuleMatrixRows(ruleMatrixId: matrixId, query: browser.rowQuery);
});

class RuleDependentLayerFocusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final ruleDependentLayerFocusProvider =
    NotifierProvider.autoDispose<RuleDependentLayerFocusNotifier, bool>(
  RuleDependentLayerFocusNotifier.new,
);

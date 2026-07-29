import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../data/rule_set_repository.dart';

class RuleWorkspaceState {
  const RuleWorkspaceState({
    this.ruleSetQuery = '',
    this.ruleSetFilterId,
    this.configuratorTemplateFilterId,
    this.matrixQuery = '',
    this.rowQuery = '',
    this.selectedRuleSetId,
    this.selectedRuleMatrixId,
    this.selectedRowId,
    this.offset = 0,
    this.limit = 30,
  });

  final String ruleSetQuery;
  final String? ruleSetFilterId;
  final String? configuratorTemplateFilterId;
  final String matrixQuery;
  final String rowQuery;
  final String? selectedRuleSetId;
  final String? selectedRuleMatrixId;
  final String? selectedRowId;
  final int offset;
  final int limit;

  RuleWorkspaceState copyWith({
    String? ruleSetQuery,
    String? ruleSetFilterId,
    String? configuratorTemplateFilterId,
    String? matrixQuery,
    String? rowQuery,
    String? selectedRuleSetId,
    String? selectedRuleMatrixId,
    String? selectedRowId,
    int? offset,
    int? limit,
    bool clearRuleSet = false,
    bool clearRuleSetFilter = false,
    bool clearConfiguratorTemplateFilter = false,
    bool clearMatrix = false,
    bool clearRow = false,
  }) {
    return RuleWorkspaceState(
      ruleSetQuery: ruleSetQuery ?? this.ruleSetQuery,
      ruleSetFilterId:
          clearRuleSetFilter ? null : (ruleSetFilterId ?? this.ruleSetFilterId),
      configuratorTemplateFilterId: clearConfiguratorTemplateFilter
          ? null
          : (configuratorTemplateFilterId ?? this.configuratorTemplateFilterId),
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
  RuleWorkspaceState build() {
    final resourceKey = currentAdminResourceKey();
    if (resourceKey == 'rule_matrices') {
      final filters = currentAdminResourceFilters(findResourceByKey('rule_matrices'));
      final ruleSetId = filters['rule_set_id'];
      return RuleWorkspaceState(
        ruleSetFilterId: ruleSetId,
        selectedRuleSetId: ruleSetId,
        selectedRuleMatrixId: filters['id'],
      );
    }

    final filters = currentAdminResourceFilters(findResourceByKey('rule_sets'));
    final filterId = filters['id'];
    return RuleWorkspaceState(
      ruleSetFilterId: filterId,
      configuratorTemplateFilterId: filters['configurator_template_id'],
      selectedRuleSetId: filterId,
    );
  }

  void setRuleSetQuery(String value) {
    state = state.copyWith(
      ruleSetQuery: value,
      offset: 0,
      clearRuleSet: true,
      clearMatrix: true,
      clearRow: true,
    );
  }


  void setConfiguratorTemplateFilter(String? value) {
    final normalized = value?.trim() ?? '';
    state = state.copyWith(
      configuratorTemplateFilterId: normalized.isEmpty ? null : normalized,
      clearConfiguratorTemplateFilter: normalized.isEmpty,
      offset: 0,
      clearRuleSet: true,
      clearMatrix: true,
      clearRow: true,
    );
  }

  void clearFilters() {
    state = state.copyWith(
      ruleSetQuery: '',
      offset: 0,
      clearRuleSetFilter: true,
      clearConfiguratorTemplateFilter: true,
      clearRuleSet: true,
      clearMatrix: true,
      clearRow: true,
    );
    ref.read(selectedResourceProvider.notifier).select('rule_sets');
  }

  void setMatrixQuery(String value) {
    state = state.copyWith(matrixQuery: value, clearMatrix: true, clearRow: true);
  }

  void setRowQuery(String value) {
    state = state.copyWith(rowQuery: value, clearRow: true);
  }

  void resetWorkspaceFilters() {
    state = state.copyWith(
      matrixQuery: '',
      rowQuery: '',
      clearMatrix: true,
      clearRow: true,
    );
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
    id: browser.ruleSetFilterId,
    configuratorTemplateId: browser.configuratorTemplateFilterId,
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

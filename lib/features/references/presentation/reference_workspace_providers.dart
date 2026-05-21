import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../data/reference_repository.dart';

class ReferenceWorkspaceState {
  const ReferenceWorkspaceState({
    this.domainQuery = '',
    this.valueQuery = '',
    this.selectedDomainId,
    this.selectedValueId,
    this.offset = 0,
    this.limit = 30,
  });

  final String domainQuery;
  final String valueQuery;
  final String? selectedDomainId;
  final String? selectedValueId;
  final int offset;
  final int limit;

  ReferenceWorkspaceState copyWith({
    String? domainQuery,
    String? valueQuery,
    String? selectedDomainId,
    String? selectedValueId,
    int? offset,
    int? limit,
    bool clearDomain = false,
    bool clearValue = false,
  }) {
    return ReferenceWorkspaceState(
      domainQuery: domainQuery ?? this.domainQuery,
      valueQuery: valueQuery ?? this.valueQuery,
      selectedDomainId: clearDomain ? null : (selectedDomainId ?? this.selectedDomainId),
      selectedValueId: clearValue ? null : (selectedValueId ?? this.selectedValueId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class ReferenceWorkspaceNotifier extends Notifier<ReferenceWorkspaceState> {
  @override
  ReferenceWorkspaceState build() => const ReferenceWorkspaceState();

  void setDomainQuery(String value) {
    state = state.copyWith(
      domainQuery: value,
      offset: 0,
      clearDomain: true,
      clearValue: true,
    );
  }

  void setValueQuery(String value) {
    state = state.copyWith(valueQuery: value, clearValue: true);
  }

  void selectDomain(String? id) {
    state = state.copyWith(selectedDomainId: id, clearValue: true);
  }

  void selectValue(String? id) {
    state = state.copyWith(selectedValueId: id);
  }

  void nextPage() {
    state = state.copyWith(
      offset: state.offset + state.limit,
      clearDomain: true,
      clearValue: true,
    );
  }

  void previousPage() {
    final nextOffset = state.offset - state.limit;
    state = state.copyWith(
      offset: nextOffset < 0 ? 0 : nextOffset,
      clearDomain: true,
      clearValue: true,
    );
  }
}

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) {
  return ReferenceRepository(ref.watch(apiClientProvider));
});

final referenceWorkspaceProvider =
    NotifierProvider.autoDispose<ReferenceWorkspaceNotifier, ReferenceWorkspaceState>(
  ReferenceWorkspaceNotifier.new,
);

final referenceDomainListProvider = FutureProvider.autoDispose<ReferenceDomainListResponse>((ref) async {
  final state = ref.watch(referenceWorkspaceProvider);
  final repository = ref.watch(referenceRepositoryProvider);
  return repository.fetchDomains(
    query: state.domainQuery,
    limit: state.limit,
    offset: state.offset,
  );
});

final selectedReferenceDomainProvider = FutureProvider.autoDispose<ReferenceDomain?>((ref) async {
  final state = ref.watch(referenceWorkspaceProvider);
  final id = state.selectedDomainId;
  if (id == null || id.isEmpty) return null;
  final repository = ref.watch(referenceRepositoryProvider);
  return repository.fetchDomain(id);
});

final referenceValuesProvider = FutureProvider.autoDispose<ReferenceValueListResponse?>((ref) async {
  final state = ref.watch(referenceWorkspaceProvider);
  final domainId = state.selectedDomainId;
  if (domainId == null || domainId.isEmpty) return null;
  final repository = ref.watch(referenceRepositoryProvider);
  return repository.fetchValues(
    domainId: domainId,
    query: state.valueQuery,
  );
});

class ReferenceDependentLayerFocusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final referenceDependentLayerFocusProvider =
    NotifierProvider.autoDispose<ReferenceDependentLayerFocusNotifier, bool>(
  ReferenceDependentLayerFocusNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/admin_providers.dart';
import '../../../core/navigation/admin_registry.dart';
import '../../../core/navigation/browser_navigation.dart';
import '../data/reference_repository.dart';

class ReferenceWorkspaceState {
  const ReferenceWorkspaceState({
    this.domainQuery = '',
    this.valueQuery = '',
    this.scopeCode = '',
    this.objectName = '',
    this.parentId = '',
    this.selectedDomainId,
    this.selectedValueId,
    this.offset = 0,
    this.limit = 30,
  });

  final String domainQuery;
  final String valueQuery;
  final String scopeCode;
  final String objectName;
  final String parentId;
  final String? selectedDomainId;
  final String? selectedValueId;
  final int offset;
  final int limit;

  Map<String, String> get activeFilters => <String, String>{
        if (scopeCode.isNotEmpty) 'scope_code': scopeCode,
        if (objectName.isNotEmpty) 'object_name': objectName,
        if (parentId.isNotEmpty) 'parent_id': parentId,
      };

  ReferenceWorkspaceState copyWith({
    String? domainQuery,
    String? valueQuery,
    String? scopeCode,
    String? objectName,
    String? parentId,
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
      scopeCode: scopeCode ?? this.scopeCode,
      objectName: objectName ?? this.objectName,
      parentId: parentId ?? this.parentId,
      selectedDomainId: clearDomain ? null : (selectedDomainId ?? this.selectedDomainId),
      selectedValueId: clearValue ? null : (selectedValueId ?? this.selectedValueId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class ReferenceWorkspaceNotifier extends Notifier<ReferenceWorkspaceState> {
  @override
  ReferenceWorkspaceState build() {
    final filters = currentAdminResourceFilters(findResourceByKey('reference_domains'));
    return ReferenceWorkspaceState(
      scopeCode: _normalizeScopeCode(filters['scope_code'] ?? ''),
      objectName: (filters['object_name'] ?? '').trim(),
      parentId: (filters['parent_id'] ?? '').trim(),
    );
  }

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

  void setScopeFilter(String? value) {
    final nextScope = _normalizeScopeCode(value ?? '');
    final nextState = state.copyWith(
      scopeCode: nextScope,
      objectName: '',
      parentId: '',
      offset: 0,
      clearDomain: true,
      clearValue: true,
    );
    state = nextState;
    ref
        .read(resourceBrowserProvider('reference_domains').notifier)
        .openWithFilters(nextState.activeFilters, updateUrl: false);
    pushAdminResourceUrl('reference_domains', filters: nextState.activeFilters);
  }

  void clearOwnerFilters() {
    final nextState = state.copyWith(
      objectName: '',
      parentId: '',
      offset: 0,
      clearDomain: true,
      clearValue: true,
    );
    state = nextState;
    ref
        .read(resourceBrowserProvider('reference_domains').notifier)
        .openWithFilters(nextState.activeFilters, updateUrl: false);
    pushAdminResourceUrl('reference_domains', filters: nextState.activeFilters);
  }

  void resetDomainFilters() {
    state = state.copyWith(
      domainQuery: '',
      scopeCode: '',
      objectName: '',
      parentId: '',
      offset: 0,
      clearDomain: true,
      clearValue: true,
    );
    ref
        .read(resourceBrowserProvider('reference_domains').notifier)
        .openWithFilters(const <String, String>{}, updateUrl: false);
    pushAdminResourceUrl('reference_domains');
  }

  void resetValueFilters() {
    state = state.copyWith(valueQuery: '', clearValue: true);
  }

  void applyNavigationFilters(Map<String, String> filters) {
    final nextScope = _normalizeScopeCode(filters['scope_code'] ?? '');
    final nextObjectName = (filters['object_name'] ?? '').trim();
    final nextParentId = (filters['parent_id'] ?? '').trim();
    if (nextScope == state.scopeCode &&
        nextObjectName == state.objectName &&
        nextParentId == state.parentId) {
      return;
    }
    final nextState = state.copyWith(
      scopeCode: nextScope,
      objectName: nextObjectName,
      parentId: nextParentId,
      offset: 0,
      clearDomain: true,
      clearValue: true,
    );
    state = nextState;
    ref
        .read(resourceBrowserProvider('reference_domains').notifier)
        .openWithFilters(nextState.activeFilters, updateUrl: false);
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
    scopeCode: state.scopeCode,
    objectName: state.objectName,
    parentId: state.parentId,
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


class ReferenceOwnerRecordKey {
  const ReferenceOwnerRecordKey({
    required this.objectName,
    required this.parentId,
  });

  final String objectName;
  final String parentId;

  @override
  bool operator ==(Object other) {
    return other is ReferenceOwnerRecordKey &&
        other.objectName == objectName &&
        other.parentId == parentId;
  }

  @override
  int get hashCode => Object.hash(objectName, parentId);
}

final referenceOwnerRecordLabelProvider = FutureProvider.autoDispose
    .family<ReferenceOwnerRecord?, ReferenceOwnerRecordKey>((ref, key) async {
  final objectName = key.objectName.trim();
  final parentId = key.parentId.trim();
  if (objectName.isEmpty || parentId.isEmpty) return null;
  final repository = ref.watch(referenceRepositoryProvider);
  final rows = await repository.fetchOwnerRecords(
    objectName: objectName,
    id: parentId,
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first;
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

String _normalizeScopeCode(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'system' || normalized == 'table') return normalized;
  return '';
}

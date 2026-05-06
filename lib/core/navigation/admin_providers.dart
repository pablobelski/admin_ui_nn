import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../config/app_config.dart';
import '../http/admin_resource_repository.dart';
import '../http/api_client.dart';
import '../models/admin_resource.dart';
import '../models/admin_state.dart';
import 'admin_registry.dart';
import 'admin_route_paths.dart';
import 'browser_navigation.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiBaseUrl,
    tokenProvider: () => ref.read(authSessionProvider).accessToken,
  );
});

final resourceRepositoryProvider = Provider<AdminResourceRepository>((ref) {
  return AdminResourceRepository(ref.watch(apiClientProvider));
});

final adminLookupProvider = FutureProvider.family<List<Map<String, dynamic>>, AdminLookup>(
      (ref, lookup) {
    return ref.watch(resourceRepositoryProvider).fetchLookup(lookup, limit: 500);
  },
);

class SelectedResourceNotifier extends Notifier<String> {
  @override
  String build() => currentAdminResourceKey();

  void select(
      String key, {
        bool updateUrl = true,
        Map<String, String> filters = const {},
      }) {
    final nextKey = isKnownAdminResourceKey(key) ? key : dashboardResource.key;
    state = nextKey;
    if (updateUrl) {
      pushAdminResourceUrl(nextKey, filters: filters);
    }
  }

  void syncFromBrowserLocation() {
    select(currentAdminResourceKey(), updateUrl: false);
  }
}

final selectedResourceProvider = NotifierProvider.autoDispose<SelectedResourceNotifier, String>(
  SelectedResourceNotifier.new,
);

class ResourceBrowserNotifier extends Notifier<ResourceBrowserState> {
  ResourceBrowserNotifier(this.resourceKey);

  final String resourceKey;

  @override
  ResourceBrowserState build() {
    final resource = findResourceByKey(resourceKey);
    return ResourceBrowserState(filters: currentAdminResourceFilters(resource));
    return const ResourceBrowserState();
  }

  void setQuery(String value) {
    state = state.copyWith(query: value, offset: 0, clearSelected: true);
  }


  void setFilter(String key, String? value) {
    final nextFilters = Map<String, String>.from(state.filters);
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      nextFilters.remove(key);
    } else {
      nextFilters[key] = normalizedValue;
    }
    state = state.copyWith(filters: nextFilters, offset: 0, clearSelected: true);
    pushAdminResourceUrl(resourceKey, filters: nextFilters);
  }

  void clearFilters() {
    state = state.copyWith(filters: const {}, offset: 0, clearSelected: true);
    pushAdminResourceUrl(resourceKey);
  }

  void select(String? id) {
    state = state.copyWith(selectedId: id);
  }

  void nextPage() {
    state = state.copyWith(offset: state.offset + state.limit, clearSelected: true);
  }

  void previousPage() {
    final nextOffset = state.offset - state.limit;
    state = state.copyWith(
      offset: nextOffset < 0 ? 0 : nextOffset,
      clearSelected: true,
    );
  }
}

final resourceBrowserProvider = NotifierProvider.autoDispose.family<
    ResourceBrowserNotifier, ResourceBrowserState, String>(
  ResourceBrowserNotifier.new,
);

final resourceListProvider = FutureProvider.family<ResourceListResponse, AdminResourceDefinition>(
  (ref, resource) async {
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final repository = ref.watch(resourceRepositoryProvider);
    return repository.fetchList(
      resource,
      query: browserState.query,
      limit: browserState.limit,
      offset: browserState.offset,
      filters: browserState.filters,
    );
  },
);

final resourceDetailsProvider = FutureProvider.family<Map<String, dynamic>?, AdminResourceDefinition>(
  (ref, resource) async {
    final browserState = ref.watch(resourceBrowserProvider(resource.key));
    final selectedId = browserState.selectedId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    final repository = ref.watch(resourceRepositoryProvider);
    return repository.fetchOne(resource, selectedId);
  },
);

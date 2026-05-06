import 'admin_resource.dart';

class ResourceBrowserState {
  const ResourceBrowserState({
    this.query = '',
    this.selectedId,
    this.offset = 0,
    this.limit = 50,
    this.filters = const {},
  });

  final String query;
  final String? selectedId;
  final int offset;
  final int limit;
  final Map<String, String> filters;

  ResourceBrowserState copyWith({
    String? query,
    String? selectedId,
    int? offset,
    int? limit,
    Map<String, String>? filters,
    bool clearSelected = false,
  }) {
    return ResourceBrowserState(
      query: query ?? this.query,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      filters: filters ?? this.filters,
    );
  }
}

String browserStateKey(AdminResourceDefinition resource) => resource.key;

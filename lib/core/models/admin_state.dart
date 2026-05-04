import 'admin_resource.dart';

class ResourceBrowserState {
  const ResourceBrowserState({
    this.query = '',
    this.selectedId,
    this.offset = 0,
    this.limit = 50,
  });

  final String query;
  final String? selectedId;
  final int offset;
  final int limit;

  ResourceBrowserState copyWith({
    String? query,
    String? selectedId,
    int? offset,
    int? limit,
    bool clearSelected = false,
  }) {
    return ResourceBrowserState(
      query: query ?? this.query,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

String browserStateKey(AdminResourceDefinition resource) => resource.key;

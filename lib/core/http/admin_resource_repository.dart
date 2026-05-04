import '../models/admin_resource.dart';
import 'api_client.dart';

class AdminResourceRepository {
  const AdminResourceRepository(this._client);

  final ApiClient _client;

  Future<ResourceListResponse> fetchList(
    AdminResourceDefinition resource, {
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      resource.endpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    return ResourceListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Map<String, dynamic>> fetchOne(
    AdminResourceDefinition resource,
    String id,
  ) async {
    return _client.getJson('${resource.endpoint}/$id');
  }

  Future<Map<String, dynamic>> create(
    AdminResourceDefinition resource,
    Map<String, dynamic> body,
  ) {
    return _client.postJson(resource.endpoint, body: body);
  }

  Future<Map<String, dynamic>> update(
    AdminResourceDefinition resource,
    String id,
    Map<String, dynamic> body,
  ) {
    return _client.putJson('${resource.endpoint}/$id', body: body);
  }

  Future<void> delete(AdminResourceDefinition resource, String id) {
    return _client.delete('${resource.endpoint}/$id');
  }
}

class ResourceListResponse {
  const ResourceListResponse({
    required this.items,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int total;
}

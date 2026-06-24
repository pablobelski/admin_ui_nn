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
    Map<String, String> filters = const {},
  }) async {
    final response = await _client.getJson(
      resource.endpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        for (final entry in filters.entries)
            if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
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

  Future<List<Map<String, dynamic>>> fetchLookup(
      AdminLookup lookup, {
        String query = '',
        int limit = 100,
      }) async {
    final response = await _client.getJson(
      lookup.endpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '0',
      },
    );

    return (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }


  Future<List<AdminSelectOption>> fetchReferenceOptions(String domainCode) async {
    final response = await _client.getJson('/api/admin/reference-options/$domainCode');
    final items = response['items'] as List? ?? const [];

    return items.cast<Map>().map((entry) {
      final row = Map<String, dynamic>.from(entry);
      final code = row['code']?.toString() ?? '';
      final label = row['label']?.toString() ?? code;
      return AdminSelectOption(value: code, label: label.isEmpty ? code : label);
    }).where((option) => option.value.isNotEmpty).toList();
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


  Future<Map<String, dynamic>> uploadMediaFile({
    required String filename,
    required String contentType,
    required String dataBase64,
    required String purpose,
    Map<String, dynamic> metadata = const {},
  }) {
    return _client.postJson(
      '/api/admin/media-files/upload',
      body: {
        'filename': filename,
        'content_type': contentType,
        'data_base64': dataBase64,
        'purpose': purpose,
        'metadata': metadata,
      },
    );
  }


  Future<Map<String, dynamic>> fetchMediaFileUrl(String fileId) {
    return _client.getJson('/api/admin/media-files/$fileId/url');
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

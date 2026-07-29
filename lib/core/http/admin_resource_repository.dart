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
        Map<String, String> filters = const {},
      }) async {
    final response = await _client.getJson(
      lookup.endpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        for (final entry in filters.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
        'limit': '$limit',
        'offset': '0',
      },
    );

    return (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }




  Future<List<Map<String, dynamic>>> fetchReferenceDomainOwnerTables({
    String query = '',
    int limit = 500,
  }) async {
    final response = await _client.getJson(
      '/api/admin/reference-domain-owner-tables',
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'limit': '$limit',
      },
    );

    return (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchReferenceDomainOwnerRecords(
    String objectName, {
    String query = '',
    String id = '',
    int limit = 500,
  }) async {
    final normalizedObjectName = objectName.trim();
    if (normalizedObjectName.isEmpty) return const <Map<String, dynamic>>[];

    final response = await _client.getJson(
      '/api/admin/reference-domain-owner-records',
      query: {
        'object_name': normalizedObjectName,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (id.trim().isNotEmpty) 'id': id.trim(),
        'limit': '$limit',
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

  Future<Map<String, dynamic>> setUserPassword({
    required String userId,
    required String password,
    required bool mustChangePassword,
  }) {
    return _client.postJson(
      '/api/admin/users/$userId/password',
      body: {
        'password': password,
        'must_change_password': mustChangePassword,
      },
    );
  }

  Future<Map<String, dynamic>> setUserPasswordChangeRequired({
    required String userId,
    required bool mustChangePassword,
  }) {
    return _client.postJson(
      '/api/admin/users/$userId/password-change-required',
      body: {
        'must_change_password': mustChangePassword,
      },
    );
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

  Future<Map<String, dynamic>?> findMediaFileByOriginalFilename(String filename) async {
    final normalized = filename.trim();
    if (normalized.isEmpty) return null;

    final response = await _client.getJson(
      '/api/internal/media-files/by-filename',
      query: {'filename': normalized},
    );
    final item = response['item'];
    if (item is! Map) return null;
    return Map<String, dynamic>.from(item);
  }

  Future<Map<String, dynamic>> fetchMediaFileUrl(String fileId) async {
    final data = await _client.getJson('/api/admin/media-files/$fileId/url');
    for (final key in ['url', 'download_url']) {
      final value = data[key]?.toString() ?? '';
      if (value.startsWith('/')) {
        data[key] = _client.url(value);
      }
    }
    return data;
  }

  String mediaFileViewUrl(String fileId) {
    return _client.url('/api/admin/media-files/$fileId/view');
  }

  Map<String, String> mediaFileHeaders() {
    return _client.authHeaders();
  }

  Future<ApiBinaryResponse> viewMediaFile(String fileId) {
    return _client.getBytes('/api/admin/media-files/$fileId/view');
  }

  Future<ApiBinaryResponse> downloadMediaFile(String fileId) {
    return _client.getBytes('/api/admin/media-files/$fileId/download');
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

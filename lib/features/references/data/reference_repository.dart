import '../../../core/http/api_client.dart';

class ReferenceRepository {
  const ReferenceRepository(this._client);

  final ApiClient _client;

  static const _domainsEndpoint = '/api/admin/reference-domains';
  static const _valuesEndpoint = '/api/admin/reference-values';

  Future<ReferenceDomainListResponse> fetchDomains({
    String query = '',
    String scopeCode = '',
    String objectName = '',
    String parentId = '',
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _domainsEndpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        if (scopeCode.isNotEmpty) 'scope_code': scopeCode,
        if (objectName.isNotEmpty) 'object_name': objectName,
        if (parentId.isNotEmpty) 'parent_id': parentId,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => ReferenceDomain.fromJson(Map<String, dynamic>.from(entry)))
        .toList();

    return ReferenceDomainListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<ReferenceDomain> fetchDomain(String id) async {
    final response = await _client.getJson('$_domainsEndpoint/$id');
    return ReferenceDomain.fromJson(response);
  }

  Future<ReferenceValueListResponse> fetchValues({
    required String domainId,
    String query = '',
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _valuesEndpoint,
      query: {
        'domain_id': domainId,
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => ReferenceValue.fromJson(Map<String, dynamic>.from(entry)))
        .toList();

    return ReferenceValueListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<ReferenceValue> fetchValue(String id) async {
    final response = await _client.getJson('$_valuesEndpoint/$id');
    return ReferenceValue.fromJson(response);
  }



  Future<List<ReferenceOwnerRecord>> fetchOwnerRecords({
    required String objectName,
    String query = '',
    String id = '',
    int limit = 500,
  }) async {
    final normalizedObjectName = objectName.trim();
    if (normalizedObjectName.isEmpty) return const <ReferenceOwnerRecord>[];

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
        .map((entry) => ReferenceOwnerRecord.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<Map<String, dynamic>> createDomain(Map<String, dynamic> body) {
    return _client.postJson(_domainsEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateDomain(String id, Map<String, dynamic> body) {
    return _client.putJson('$_domainsEndpoint/$id', body: body);
  }

  Future<Map<String, dynamic>> createValue(Map<String, dynamic> body) {
    return _client.postJson(_valuesEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateValue(String id, Map<String, dynamic> body) {
    return _client.putJson('$_valuesEndpoint/$id', body: body);
  }

  Future<void> deleteValue(String id) {
    return _client.delete('$_valuesEndpoint/$id');
  }
}


class ReferenceOwnerRecord {
  const ReferenceOwnerRecord({
    required this.id,
    required this.label,
  });

  factory ReferenceOwnerRecord.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    final label = _stringOrNull(json['label']) ?? id;
    return ReferenceOwnerRecord(id: id, label: label.isEmpty ? id : label);
  }

  final String id;
  final String label;
}

class ReferenceDomainListResponse {
  const ReferenceDomainListResponse({
    required this.items,
    required this.total,
  });

  final List<ReferenceDomain> items;
  final int total;
}

class ReferenceValueListResponse {
  const ReferenceValueListResponse({
    required this.items,
    required this.total,
  });

  final List<ReferenceValue> items;
  final int total;
}

class ReferenceDomain {
  const ReferenceDomain({
    required this.id,
    required this.code,
    required this.name,
    required this.isSystem,
    required this.isActive,
    required this.raw,
    this.description,
    this.scopeCode,
    this.objectName,
    this.parentId,
    this.createdAt,
    this.updatedAt,
  });

  factory ReferenceDomain.fromJson(Map<String, dynamic> json) {
    return ReferenceDomain(
      id: _string(json['id']),
      code: _string(json['code']),
      name: _string(json['name']),
      description: _stringOrNull(json['description']),
      scopeCode: _stringOrNull(json['scope_code']),
      objectName: _stringOrNull(json['object_name']),
      parentId: _stringOrNull(json['parent_id']),
      isSystem: _boolValue(json['is_system']),
      isActive: _boolValue(json['is_active']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? scopeCode;
  final String? objectName;
  final String? parentId;
  final bool isSystem;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

class ReferenceValue {
  const ReferenceValue({
    required this.id,
    required this.domainId,
    required this.code,
    required this.label,
    required this.sortOrder,
    required this.isActive,
    required this.raw,
    this.altLabel,
    this.colorHex,
    this.numericValue,
    this.metadataJson,
    this.createdAt,
    this.updatedAt,
  });

  factory ReferenceValue.fromJson(Map<String, dynamic> json) {
    return ReferenceValue(
      id: _string(json['id']),
      domainId: _string(json['domain_id']),
      code: _string(json['code']),
      label: _string(json['label']),
      altLabel: _stringOrNull(json['alt_label']),
      sortOrder: _intOrZero(json['sort_order']),
      colorHex: _stringOrNull(json['color_hex']),
      numericValue: _numOrNull(json['numeric_value']),
      metadataJson: _mapOrNull(json['metadata_json']),
      isActive: _boolValue(json['is_active']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String domainId;
  final String code;
  final String label;
  final String? altLabel;
  final int sortOrder;
  final String? colorHex;
  final num? numericValue;
  final Map<String, dynamic>? metadataJson;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

String _string(Object? value) => value?.toString() ?? '';

String? _stringOrNull(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num? _numOrNull(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

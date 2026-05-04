
import '../../../core/http/api_client.dart';

class RuleSetRepository {
  const RuleSetRepository(this._client);

  final ApiClient _client;

  static const _ruleSetsEndpoint = '/api/admin/rule-sets';
  static const _ruleMatricesEndpoint = '/api/admin/rule-matrices';
  static const _ruleMatrixRowsEndpoint = '/api/admin/rule-matrix-rows';

  Future<RuleSetListResponse> fetchRuleSets({
    String query = '',
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _ruleSetsEndpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => RuleSet.fromJson(Map<String, dynamic>.from(entry)))
        .toList();

    return RuleSetListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<RuleSet> fetchRuleSet(String id) async {
    final response = await _client.getJson('$_ruleSetsEndpoint/$id');
    return RuleSet.fromJson(response);
  }

  Future<RuleMatrixListResponse> fetchRuleMatrices({
    required String ruleSetId,
    String query = '',
    int limit = 300,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _ruleMatricesEndpoint,
      query: {
        'rule_set_id': ruleSetId,
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => RuleMatrix.fromJson(Map<String, dynamic>.from(entry)))
        .toList()
      ..sort((a, b) {
        final sortDiff = (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);
        if (sortDiff != 0) return sortDiff;
        return a.matrixCode.compareTo(b.matrixCode);
      });

    return RuleMatrixListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<RuleMatrix> fetchRuleMatrix(String id) async {
    final response = await _client.getJson('$_ruleMatricesEndpoint/$id');
    return RuleMatrix.fromJson(response);
  }

  Future<RuleMatrixRowListResponse> fetchRuleMatrixRows({
    required String ruleMatrixId,
    String query = '',
    int limit = 1000,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _ruleMatrixRowsEndpoint,
      query: {
        'rule_matrix_id': ruleMatrixId,
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => RuleMatrixRow.fromJson(Map<String, dynamic>.from(entry)))
        .toList()
      ..sort((a, b) => a.rowNo.compareTo(b.rowNo));

    return RuleMatrixRowListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Map<String, dynamic>> createRuleSet(Map<String, dynamic> body) {
    return _client.postJson(_ruleSetsEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateRuleSet(String id, Map<String, dynamic> body) {
    return _client.putJson('$_ruleSetsEndpoint/$id', body: body);
  }

  Future<void> deleteRuleSet(String id) {
    return _client.delete('$_ruleSetsEndpoint/$id');
  }

  Future<Map<String, dynamic>> createRuleMatrix(Map<String, dynamic> body) {
    return _client.postJson(_ruleMatricesEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateRuleMatrix(String id, Map<String, dynamic> body) {
    return _client.putJson('$_ruleMatricesEndpoint/$id', body: body);
  }

  Future<void> deleteRuleMatrix(String id) {
    return _client.delete('$_ruleMatricesEndpoint/$id');
  }

  Future<Map<String, dynamic>> createRuleMatrixRow(Map<String, dynamic> body) {
    return _client.postJson(_ruleMatrixRowsEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateRuleMatrixRow(String id, Map<String, dynamic> body) {
    return _client.putJson('$_ruleMatrixRowsEndpoint/$id', body: body);
  }

  Future<void> deleteRuleMatrixRow(String id) {
    return _client.delete('$_ruleMatrixRowsEndpoint/$id');
  }
}

class RuleSetListResponse {
  const RuleSetListResponse({required this.items, required this.total});

  final List<RuleSet> items;
  final int total;
}

class RuleMatrixListResponse {
  const RuleMatrixListResponse({required this.items, required this.total});

  final List<RuleMatrix> items;
  final int total;
}

class RuleMatrixRowListResponse {
  const RuleMatrixRowListResponse({required this.items, required this.total});

  final List<RuleMatrixRow> items;
  final int total;
}

class RuleSet {
  const RuleSet({
    required this.id,
    required this.configuratorTemplateId,
    required this.version,
    required this.statusCode,
    required this.rulesJson,
    required this.raw,
    this.validFrom,
    this.validTo,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory RuleSet.fromJson(Map<String, dynamic> json) {
    return RuleSet(
      id: _string(json['id']),
      configuratorTemplateId: _string(json['configurator_template_id']),
      version: _intOrZero(json['version']),
      rulesJson: _mapOrNull(json['rules_json']) ?? const {},
      validFrom: _stringOrNull(json['valid_from']),
      validTo: _stringOrNull(json['valid_to']),
      statusCode: _string(json['status_code']),
      notes: _stringOrNull(json['notes']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String configuratorTemplateId;
  final int version;
  final Map<String, dynamic> rulesJson;
  final String? validFrom;
  final String? validTo;
  final String statusCode;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

class RuleMatrix {
  const RuleMatrix({
    required this.id,
    required this.ruleSetId,
    required this.matrixCode,
    required this.name,
    required this.isActive,
    required this.raw,
    this.sourceSheetName,
    this.sourceRange,
    this.axisXCode,
    this.axisYCode,
    this.headerJson,
    this.metadataJson,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory RuleMatrix.fromJson(Map<String, dynamic> json) {
    return RuleMatrix(
      id: _string(json['id']),
      ruleSetId: _string(json['rule_set_id']),
      matrixCode: _string(json['matrix_code']),
      name: _string(json['name']),
      sourceSheetName: _stringOrNull(json['source_sheet_name']),
      sourceRange: _stringOrNull(json['source_range']),
      axisXCode: _stringOrNull(json['axis_x_code']),
      axisYCode: _stringOrNull(json['axis_y_code']),
      headerJson: _mapOrNull(json['header_json']),
      metadataJson: _mapOrNull(json['metadata_json']),
      sortOrder: _intOrNull(json['sort_order']),
      isActive: _boolValue(json['is_active']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String ruleSetId;
  final String matrixCode;
  final String name;
  final String? sourceSheetName;
  final String? sourceRange;
  final String? axisXCode;
  final String? axisYCode;
  final Map<String, dynamic>? headerJson;
  final Map<String, dynamic>? metadataJson;
  final int? sortOrder;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

class RuleMatrixRow {
  const RuleMatrixRow({
    required this.id,
    required this.ruleMatrixId,
    required this.rowNo,
    required this.keyJson,
    required this.resultJson,
    required this.raw,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory RuleMatrixRow.fromJson(Map<String, dynamic> json) {
    return RuleMatrixRow(
      id: _string(json['id']),
      ruleMatrixId: _string(json['rule_matrix_id']),
      rowNo: _intOrZero(json['row_no']),
      keyJson: _mapOrNull(json['key_json']) ?? const {},
      resultJson: _mapOrNull(json['result_json']) ?? const {},
      notes: _stringOrNull(json['notes']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String ruleMatrixId;
  final int rowNo;
  final Map<String, dynamic> keyJson;
  final Map<String, dynamic> resultJson;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

String _string(Object? value) => value?.toString() ?? '';
String? _stringOrNull(Object? value) {
  final parsed = value?.toString();
  if (parsed == null || parsed.isEmpty) return null;
  return parsed;
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final parsed = value?.toString().toLowerCase();
  return parsed == 'true' || parsed == '1' || parsed == 't';
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return null;
}

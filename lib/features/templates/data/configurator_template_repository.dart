import '../../../core/http/api_client.dart';

class ConfiguratorTemplateRepository {
  const ConfiguratorTemplateRepository(this._client);

  final ApiClient _client;

  static const _templatesEndpoint = '/api/admin/configurator-templates';
  static const _modulesEndpoint = '/api/admin/template-modules';

  Future<ConfiguratorTemplateListResponse> fetchTemplates({
    String query = '',
    String productFamilyId = '',
    String roofModelId = '',
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _templatesEndpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        if (productFamilyId.isNotEmpty) 'product_family_id': productFamilyId,
        if (roofModelId.isNotEmpty) 'roof_model_id': roofModelId,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => ConfiguratorTemplate.fromJson(Map<String, dynamic>.from(entry)))
        .toList()
      ..sort((a, b) {
        final statusDiff = a.statusCode.compareTo(b.statusCode);
        if (statusDiff != 0) return statusDiff;
        final codeDiff = a.code.compareTo(b.code);
        if (codeDiff != 0) return codeDiff;
        return b.version.compareTo(a.version);
      });

    return ConfiguratorTemplateListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<ConfiguratorTemplate> fetchTemplate(String id) async {
    final response = await _client.getJson('$_templatesEndpoint/$id');
    return ConfiguratorTemplate.fromJson(response);
  }

  Future<TemplateModuleListResponse> fetchModules({
    required String configuratorTemplateId,
    String query = '',
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _modulesEndpoint,
      query: {
        'configurator_template_id': configuratorTemplateId,
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => TemplateModule.fromJson(Map<String, dynamic>.from(entry)))
        .toList()
      ..sort((a, b) {
        final sortDiff = a.sortOrder.compareTo(b.sortOrder);
        if (sortDiff != 0) return sortDiff;
        return a.moduleCode.compareTo(b.moduleCode);
      });

    return TemplateModuleListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<TemplateModule> fetchModule(String id) async {
    final response = await _client.getJson('$_modulesEndpoint/$id');
    return TemplateModule.fromJson(response);
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> body) {
    return _client.postJson(_templatesEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateTemplate(String id, Map<String, dynamic> body) {
    return _client.putJson('$_templatesEndpoint/$id', body: body);
  }

  Future<void> deleteTemplate(String id) {
    return _client.delete('$_templatesEndpoint/$id');
  }

  Future<Map<String, dynamic>> createModule(Map<String, dynamic> body) {
    return _client.postJson(_modulesEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateModule(String id, Map<String, dynamic> body) {
    return _client.putJson('$_modulesEndpoint/$id', body: body);
  }

  Future<void> deleteModule(String id) {
    return _client.delete('$_modulesEndpoint/$id');
  }
}

class ConfiguratorTemplateListResponse {
  const ConfiguratorTemplateListResponse({
    required this.items,
    required this.total,
  });

  final List<ConfiguratorTemplate> items;
  final int total;
}

class TemplateModuleListResponse {
  const TemplateModuleListResponse({
    required this.items,
    required this.total,
  });

  final List<TemplateModule> items;
  final int total;
}

class ConfiguratorTemplate {
  const ConfiguratorTemplate({
    required this.id,
    required this.code,
    required this.name,
    required this.productFamilyId,
    required this.version,
    required this.statusCode,
    required this.uiSchemaJson,
    required this.defaultValuesJson,
    required this.metadataJson,
    required this.raw,
    this.roofModelId,
    this.sourceSheetName,
    this.sourceRange,
    this.createdAt,
    this.updatedAt,
  });

  factory ConfiguratorTemplate.fromJson(Map<String, dynamic> json) {
    return ConfiguratorTemplate(
      id: _string(json['id']),
      code: _string(json['code']),
      name: _string(json['name']),
      productFamilyId: _string(json['product_family_id']),
      roofModelId: _stringOrNull(json['roof_model_id']),
      sourceSheetName: _stringOrNull(json['source_sheet_name']),
      sourceRange: _stringOrNull(json['source_range']),
      version: _intOrZero(json['version']),
      statusCode: _string(json['status_code']),
      uiSchemaJson: _mapOrNull(json['ui_schema_json']) ?? const {},
      defaultValuesJson: _mapOrNull(json['default_values_json']) ?? const {},
      metadataJson: _mapOrNull(json['metadata_json']) ?? const {},
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String code;
  final String name;
  final String productFamilyId;
  final String? roofModelId;
  final String? sourceSheetName;
  final String? sourceRange;
  final int version;
  final String statusCode;
  final Map<String, dynamic> uiSchemaJson;
  final Map<String, dynamic> defaultValuesJson;
  final Map<String, dynamic> metadataJson;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

class TemplateModule {
  const TemplateModule({
    required this.id,
    required this.configuratorTemplateId,
    required this.moduleCode,
    required this.name,
    required this.moduleTypeCode,
    required this.sortOrder,
    required this.isEditable,
    required this.isResettable,
    required this.isActive,
    required this.uiConfigJson,
    required this.defaultDataJson,
    required this.raw,
    this.sourceSheetName,
    this.sourceRange,
    this.targetRange,
    this.resetSourceRange,
    this.createdAt,
    this.updatedAt,
  });

  factory TemplateModule.fromJson(Map<String, dynamic> json) {
    return TemplateModule(
      id: _string(json['id']),
      configuratorTemplateId: _string(json['configurator_template_id']),
      moduleCode: _string(json['module_code']),
      name: _string(json['name']),
      moduleTypeCode: _string(json['module_type_code']),
      sourceSheetName: _stringOrNull(json['source_sheet_name']),
      sourceRange: _stringOrNull(json['source_range']),
      targetRange: _stringOrNull(json['target_range']),
      resetSourceRange: _stringOrNull(json['reset_source_range']),
      sortOrder: _intOrZero(json['sort_order']),
      isEditable: _boolValue(json['is_editable']),
      isResettable: _boolValue(json['is_resettable']),
      isActive: _boolValue(json['is_active']),
      uiConfigJson: _mapOrNull(json['ui_config_json']) ?? const {},
      defaultDataJson: _mapOrNull(json['default_data_json']) ?? const {},
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String configuratorTemplateId;
  final String moduleCode;
  final String name;
  final String moduleTypeCode;
  final String? sourceSheetName;
  final String? sourceRange;
  final String? targetRange;
  final String? resetSourceRange;
  final int sortOrder;
  final bool isEditable;
  final bool isResettable;
  final bool isActive;
  final Map<String, dynamic> uiConfigJson;
  final Map<String, dynamic> defaultDataJson;
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
  return int.tryParse('${value ?? ''}') ?? 0;
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return null;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 't';
}

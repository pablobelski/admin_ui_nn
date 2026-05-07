import '../../../core/http/api_client.dart';

class PriceMatrixRepository {
  const PriceMatrixRepository(this._client);

  final ApiClient _client;

  static const _matricesEndpoint = '/api/admin/price-matrices';
  static const _cellsEndpoint = '/api/admin/price-matrix-cells';

  Future<PriceMatrixListResponse> fetchMatrices({
    String query = '',
    String priceListId = '',
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _matricesEndpoint,
      query: {
        if (query.isNotEmpty) 'q': query,
        if (priceListId.isNotEmpty) 'price_list_id': priceListId,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => PriceMatrix.fromJson(Map<String, dynamic>.from(entry)))
        .toList();

    return PriceMatrixListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<PriceMatrix> fetchMatrix(String id) async {
    final response = await _client.getJson('$_matricesEndpoint/$id');
    return PriceMatrix.fromJson(response);
  }

  Future<PriceMatrixCellListResponse> fetchCells({
    required String priceMatrixId,
    String query = '',
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await _client.getJson(
      _cellsEndpoint,
      query: {
        'price_matrix_id': priceMatrixId,
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((entry) => PriceMatrixCell.fromJson(Map<String, dynamic>.from(entry)))
        .toList();

    items.sort((a, b) {
      final rowDiff = a.rowNo.compareTo(b.rowNo);
      if (rowDiff != 0) return rowDiff;
      return a.colNo.compareTo(b.colNo);
    });

    return PriceMatrixCellListResponse(
      items: items,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Map<String, dynamic>> createMatrix(Map<String, dynamic> body) {
    return _client.postJson(_matricesEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateMatrix(String id, Map<String, dynamic> body) {
    return _client.putJson('$_matricesEndpoint/$id', body: body);
  }

  Future<void> deleteMatrix(String id) {
    return _client.delete('$_matricesEndpoint/$id');
  }

  Future<Map<String, dynamic>> createCell(Map<String, dynamic> body) {
    return _client.postJson(_cellsEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateCell(String id, Map<String, dynamic> body) {
    return _client.putJson('$_cellsEndpoint/$id', body: body);
  }

  Future<void> deleteCell(String id) {
    return _client.delete('$_cellsEndpoint/$id');
  }
}

class PriceMatrixListResponse {
  const PriceMatrixListResponse({
    required this.items,
    required this.total,
  });

  final List<PriceMatrix> items;
  final int total;
}

class PriceMatrixCellListResponse {
  const PriceMatrixCellListResponse({
    required this.items,
    required this.total,
  });

  final List<PriceMatrixCell> items;
  final int total;
}

class PriceMatrix {
  const PriceMatrix({
    required this.id,
    required this.matrixCode,
    required this.name,
    required this.parserKind,
    required this.sourceSheetName,
    required this.isActive,
    required this.raw,
    this.priceListId,
    this.phaseLabel,
    this.productLabel,
    this.subtitleLabel,
    this.sectionLabel,
    this.sectionCode,
    this.sourceRowNo,
    this.sourceColNo,
    this.sortOrder,
    this.headerJson,
    this.metadataJson,
    this.createdAt,
    this.updatedAt,
  });

  factory PriceMatrix.fromJson(Map<String, dynamic> json) {
    return PriceMatrix(
      id: _string(json['id']),
      priceListId: _stringOrNull(json['price_list_id']),
      matrixCode: _string(json['matrix_code']),
      name: _string(json['name']),
      parserKind: _string(json['parser_kind']),
      phaseLabel: _stringOrNull(json['phase_label']),
      productLabel: _stringOrNull(json['product_label']),
      subtitleLabel: _stringOrNull(json['subtitle_label']),
      sectionLabel: _stringOrNull(json['section_label']),
      sectionCode: _stringOrNull(json['section_code']),
      sourceSheetName: _string(json['source_sheet_name']),
      sourceRowNo: _intOrNull(json['source_row_no']),
      sourceColNo: _intOrNull(json['source_col_no']),
      sortOrder: _intOrNull(json['sort_order']),
      isActive: _boolValue(json['is_active']),
      headerJson: _mapOrNull(json['header_json']),
      metadataJson: _mapOrNull(json['metadata_json']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String? priceListId;
  final String matrixCode;
  final String name;
  final String parserKind;
  final String? phaseLabel;
  final String? productLabel;
  final String? subtitleLabel;
  final String? sectionLabel;
  final String? sectionCode;
  final String sourceSheetName;
  final int? sourceRowNo;
  final int? sourceColNo;
  final int? sortOrder;
  final bool isActive;
  final Map<String, dynamic>? headerJson;
  final Map<String, dynamic>? metadataJson;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> raw;
}

class PriceMatrixCell {
  const PriceMatrixCell({
    required this.id,
    required this.priceMatrixId,
    required this.rowNo,
    required this.colNo,
    required this.cellRef,
    required this.unitPrice,
    required this.raw,
    this.widthMm,
    this.heightMm,
    this.depthMm,
    this.depthM,
    this.widthBucketCode,
    this.beamCount,
    this.postCount,
    this.dimensionsJson,
    this.metadataJson,
    this.createdAt,
    this.updatedAt,
  });

  factory PriceMatrixCell.fromJson(Map<String, dynamic> json) {
    return PriceMatrixCell(
      id: _string(json['id']),
      priceMatrixId: _string(json['price_matrix_id']),
      rowNo: _intOrZero(json['row_no']),
      colNo: _intOrZero(json['col_no']),
      cellRef: _string(json['cell_ref']),
      unitPrice: _doubleOrZero(json['unit_price']),
      widthMm: _intOrNull(json['width_mm']),
      heightMm: _intOrNull(json['height_mm']),
      depthMm: _intOrNull(json['depth_mm']),
      depthM: _doubleOrNull(json['depth_m']),
      widthBucketCode: _stringOrNull(json['width_bucket_code']),
      beamCount: _intOrNull(json['beam_count']),
      postCount: _intOrNull(json['post_count']),
      dimensionsJson: _mapOrNull(json['dimensions_json']),
      metadataJson: _mapOrNull(json['metadata_json']),
      createdAt: _stringOrNull(json['created_at']),
      updatedAt: _stringOrNull(json['updated_at']),
      raw: json,
    );
  }

  final String id;
  final String priceMatrixId;
  final int rowNo;
  final int colNo;
  final String cellRef;
  final double unitPrice;
  final int? widthMm;
  final int? heightMm;
  final int? depthMm;
  final double? depthM;
  final String? widthBucketCode;
  final int? beamCount;
  final int? postCount;
  final Map<String, dynamic>? dimensionsJson;
  final Map<String, dynamic>? metadataJson;
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

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

int _intOrZero(Object? value) => _intOrNull(value) ?? 0;

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double _doubleOrZero(Object? value) => _doubleOrNull(value) ?? 0;

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return null;
}

import '../../../core/http/api_client.dart';
import 'calculator_models.dart';

class CalculatorRepository {
  const CalculatorRepository(this._client);

  final ApiClient _client;

  Future<CalculatorContext> fetchContext() async {
    final response = await _client.getJson('/api/internal/calculator/context');
    return CalculatorContext.fromJson(response);
  }

  Future<CalculatorSetContentsPreview> fetchSetContents(CalculatorDraft draft) async {
    final response = await _client.postJson(
      '/api/internal/calculator/set-contents',
      body: draft.toCalculationJson(),
    );
    return CalculatorSetContentsPreview.fromJson(response);
  }

  Future<CalculatorResult> calculate(CalculatorDraft draft) async {
    final response = await _client.postJson(
      '/api/internal/calculator/calculate',
      body: draft.toCalculationJson(),
    );
    return CalculatorResult.fromJson(response);
  }

  Future<String?> previewQuoteNumber({
    String? organizationId,
    required String commissionName,
  }) async {
    final response = await _client.postJson(
      '/api/internal/calculator/quote-number-preview',
      body: {
        if (organizationId != null && organizationId.isNotEmpty) 'organization_id': organizationId,
        'quote_no_external': commissionName,
      },
    );
    return _repoNullableString(response['quote_no'] ?? response['quoteNo']);
  }

  Future<LoadedQuote> loadQuoteForWorkspace(String quoteId) async {
    final response = await _client.postJson(
      '/api/internal/calculator/load-quote',
      body: {
        'quote_id': quoteId,
      },
    );
    return LoadedQuote.fromJson(response);
  }

  Future<SavedQuote> saveQuote(
    CalculatorDraft draft, {
    SaveQuoteMode mode = SaveQuoteMode.asNew,
    String? baseQuoteId,
    String? geometryPreviewFileId,
    String? expandedGeometryPreviewFileId,
  }) async {
    final workspaceInput = draft.toWorkspaceJson();
    final printAssets = <String, dynamic>{};
    if (geometryPreviewFileId != null && geometryPreviewFileId.isNotEmpty) {
      printAssets['geometryPreview'] = {
        'fileId': geometryPreviewFileId,
        'contentType': 'image/png',
        'variant': 'geometry_only',
        'width': 450,
        'height': 305,
      };
    }
    if (expandedGeometryPreviewFileId != null &&
        expandedGeometryPreviewFileId.isNotEmpty) {
      printAssets['expandedGeometryPreview'] = {
        'fileId': expandedGeometryPreviewFileId,
        'contentType': 'image/png',
        'variant': 'geometry_expanded',
        'width': 2400,
        'height': 1520,
        'logicalWidth': 1200,
        'logicalHeight': 760,
      };
    }
    if (printAssets.isNotEmpty) {
      workspaceInput['printAssets'] = printAssets;
    }

    final response = await _client.postJson(
      '/api/internal/calculator/save-quote',
      body: {
        'input': draft.toCalculationJson(),
        'workspace_input': workspaceInput,
        'mode': mode.apiValue,
        if (baseQuoteId != null && baseQuoteId.isNotEmpty) 'base_quote_id': baseQuoteId,
      },
    );

    final quote = response['quote'];
    if (quote is Map) {
      return SavedQuote.fromJson(Map<String, dynamic>.from(quote));
    }

    return SavedQuote.fromJson(response);
  }

  Future<PrintDialogData> fetchPrintDialogData(String quoteId) async {
    final response = await _client.getJson(
      '/api/internal/calculator/print',
      query: {'quote_id': quoteId},
    );
    return PrintDialogData.fromJson(response);
  }

  Future<GeneratedDocument> printPdf({
    required String quoteId,
    String? documentTemplateId,
    List<String> documentTemplateIds = const [],
    String? documentBatchId,
    bool useDefaultBatch = false,
  }) async {
    final response = await _client.postJson(
      '/api/internal/calculator/print',
      body: {
        'quote_id': quoteId,
        if (documentBatchId != null && documentBatchId.isNotEmpty)
          'document_batch_id': documentBatchId
        else if (useDefaultBatch)
          'use_default_batch': true
        else if (documentTemplateIds.isNotEmpty)
          'document_template_ids': documentTemplateIds
        else if (documentTemplateId != null && documentTemplateId.isNotEmpty)
          'document_template_id': documentTemplateId,
      },
    );
    return GeneratedDocument.fromJson(response);
  }

  Future<QuoteStatusTransitions> fetchQuoteStatusTransitions(
    String quoteId,
  ) async {
    final response = await _client.getJson(
      '/api/internal/calculator/quote-status',
      query: {'quote_id': quoteId},
    );
    return QuoteStatusTransitions.fromJson(response);
  }

  Future<QuoteStatusChangeResult> changeQuoteStatus(
    String quoteId,
    String targetStatus,
  ) async {
    final response = await _client.postJson(
      '/api/internal/calculator/quote-status',
      body: {
        'quote_id': quoteId,
        'target_status': targetStatus,
      },
    );
    return QuoteStatusChangeResult.fromJson(response);
  }

  Future<QuoteSubmitPreview> fetchQuoteSubmitPreview(
    String quoteId, {
    required String operation,
  }) async {
    final response = await _client.getJson(
      '/api/internal/calculator/submit',
      query: {
        'quote_id': quoteId,
        'operation': operation,
      },
    );
    return QuoteSubmitPreview.fromJson(response);
  }

  Future<QuoteSubmitResult> submitQuoteEmail(
    String quoteId, {
    required String operation,
  }) async {
    final response = await _client.postJson(
      '/api/internal/calculator/submit',
      body: {
        'quote_id': quoteId,
        'operation': operation,
      },
    );
    return QuoteSubmitResult.fromJson(response);
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
}

class QuoteStatusTransitionOption {
  const QuoteStatusTransitionOption({
    required this.statusCode,
    required this.label,
  });

  factory QuoteStatusTransitionOption.fromJson(Map<String, dynamic> json) =>
      QuoteStatusTransitionOption(
        statusCode: _repoString(json['status_code'] ?? json['statusCode']),
        label: _repoString(json['label']),
      );

  final String statusCode;
  final String label;
}

class QuoteStatusTransitions {
  const QuoteStatusTransitions({
    required this.quoteId,
    required this.quoteNo,
    required this.statusCode,
    required this.transitions,
  });

  factory QuoteStatusTransitions.fromJson(Map<String, dynamic> json) =>
      QuoteStatusTransitions(
        quoteId: _repoString(json['quote_id'] ?? json['quoteId']),
        quoteNo: _repoString(json['quote_no'] ?? json['quoteNo']),
        statusCode: _repoString(json['status_code'] ?? json['statusCode']),
        transitions: _repoList(json['transitions'])
            .map(QuoteStatusTransitionOption.fromJson)
            .toList(growable: false),
      );

  final String quoteId;
  final String quoteNo;
  final String statusCode;
  final List<QuoteStatusTransitionOption> transitions;
}

class QuoteStatusChangeResult {
  const QuoteStatusChangeResult({
    required this.ok,
    required this.quoteId,
    required this.quoteNo,
    required this.previousStatusCode,
    required this.statusCode,
    required this.transitions,
  });

  factory QuoteStatusChangeResult.fromJson(Map<String, dynamic> json) =>
      QuoteStatusChangeResult(
        ok: _repoBool(json['ok']),
        quoteId: _repoString(json['quote_id'] ?? json['quoteId']),
        quoteNo: _repoString(json['quote_no'] ?? json['quoteNo']),
        previousStatusCode: _repoString(
          json['previous_status_code'] ?? json['previousStatusCode'],
        ),
        statusCode: _repoString(json['status_code'] ?? json['statusCode']),
        transitions: _repoList(json['transitions'])
            .map(QuoteStatusTransitionOption.fromJson)
            .toList(growable: false),
      );

  final bool ok;
  final String quoteId;
  final String quoteNo;
  final String previousStatusCode;
  final String statusCode;
  final List<QuoteStatusTransitionOption> transitions;
}

class QuoteSubmitIssue {
  const QuoteSubmitIssue({
    required this.code,
    required this.message,
    this.field,
  });

  factory QuoteSubmitIssue.fromJson(Map<String, dynamic> json) => QuoteSubmitIssue(
        code: _repoString(json['code']),
        message: _repoString(json['message']),
        field: _repoNullableString(json['field']),
      );

  final String code;
  final String message;
  final String? field;
}

class QuoteSubmitPreview {
  const QuoteSubmitPreview({
    required this.canSubmit,
    required this.operation,
    required this.quoteId,
    required this.quoteNo,
    required this.statusCode,
    required this.targetStatus,
    required this.customerOrganizationName,
    required this.customerDeliveryEnabled,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.senderName,
    required this.senderAddress,
    required this.subject,
    required this.errors,
    required this.warnings,
    this.customerContactName,
    this.customerEmail,
    this.documentBatchName,
    this.documentBatchCode,
    this.documentCount = 0,
  });

  factory QuoteSubmitPreview.fromJson(Map<String, dynamic> json) {
    final quote = _repoMap(json['quote']);
    final customer = _repoMap(json['customer']);
    final sender = _repoMap(json['sender']);
    final recipients = _repoMap(json['recipients']);
    final batch = _repoMap(json['document_batch'] ?? json['documentBatch']);
    final email = _repoMap(json['email']);
    List<String> emails(Object? value) => value is List
        ? value.map((entry) => _repoString(entry)).where((entry) => entry.isNotEmpty).toList(growable: false)
        : const [];
    return QuoteSubmitPreview(
      canSubmit: _repoBool(json['can_submit'] ?? json['canSubmit']),
      operation: _repoString(json['operation']),
      quoteId: _repoString(quote['id']),
      quoteNo: _repoString(quote['quote_no'] ?? quote['quoteNo']),
      statusCode: _repoString(quote['status_code'] ?? quote['statusCode']),
      targetStatus: _repoString(quote['target_status'] ?? quote['targetStatus']),
      customerOrganizationName: _repoString(customer['organization_name'] ?? customer['organizationName']),
      customerContactName: _repoNullableString(customer['contact_name'] ?? customer['contactName']),
      customerEmail: _repoNullableString(customer['email']),
      customerDeliveryEnabled: _repoBool(customer['delivery_enabled'] ?? customer['deliveryEnabled']),
      to: emails(recipients['to']),
      cc: emails(recipients['cc']),
      bcc: emails(recipients['bcc']),
      senderName: _repoString(sender['name']),
      senderAddress: _repoString(sender['address']),
      subject: _repoString(email['subject']),
      documentBatchName: _repoNullableString(batch['name']),
      documentBatchCode: _repoNullableString(batch['code']),
      documentCount: _repoIntOrNull(batch['document_count'] ?? batch['documentCount']) ?? 0,
      errors: _repoList(json['errors']).map(QuoteSubmitIssue.fromJson).toList(growable: false),
      warnings: _repoList(json['warnings']).map(QuoteSubmitIssue.fromJson).toList(growable: false),
    );
  }

  final bool canSubmit;
  final String operation;
  final String quoteId;
  final String quoteNo;
  final String statusCode;
  final String targetStatus;
  final String customerOrganizationName;
  final String? customerContactName;
  final String? customerEmail;
  final bool customerDeliveryEnabled;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String senderName;
  final String senderAddress;
  final String subject;
  final String? documentBatchName;
  final String? documentBatchCode;
  final int documentCount;
  final List<QuoteSubmitIssue> errors;
  final List<QuoteSubmitIssue> warnings;
}

class QuoteSubmitResult {
  const QuoteSubmitResult({
    required this.ok,
    required this.operation,
    required this.quoteId,
    required this.quoteNo,
    required this.statusCode,
    required this.customerDeliveryEnabled,
  });

  factory QuoteSubmitResult.fromJson(Map<String, dynamic> json) => QuoteSubmitResult(
        ok: _repoBool(json['ok']),
        operation: _repoString(json['operation']),
        quoteId: _repoString(json['quote_id'] ?? json['quoteId']),
        quoteNo: _repoString(json['quote_no'] ?? json['quoteNo']),
        statusCode: _repoString(json['status_code'] ?? json['statusCode']),
        customerDeliveryEnabled: _repoBool(json['customer_delivery_enabled'] ?? json['customerDeliveryEnabled']),
      );

  final bool ok;
  final String operation;
  final String quoteId;
  final String quoteNo;
  final String statusCode;
  final bool customerDeliveryEnabled;
}

class PrintDialogData {
  const PrintDialogData({
    required this.batches,
    required this.templates,
    required this.recentDocuments,
    required this.payloadPreview,
    this.defaultBatch,
  });

  factory PrintDialogData.fromJson(Map<String, dynamic> json) {
    final batches = _repoList(json['batches'])
        .map(DocumentBatchOption.fromJson)
        .toList(growable: false);
    final defaultBatchJson = _repoMap(json['default_batch'] ?? json['defaultBatch']);
    return PrintDialogData(
      batches: batches,
      defaultBatch: defaultBatchJson.isEmpty
          ? _firstOrNull(batches.where((entry) => entry.isDefault && entry.compatible && entry.items.isNotEmpty))
          : DocumentBatchOption.fromJson(defaultBatchJson),
      templates: _repoList(json['templates'])
          .map(PrintTemplateOption.fromJson)
          .where((entry) => entry.isPrintEnabled && (entry.sourceAssetFileId ?? '').isNotEmpty)
          .toList(growable: false),
      recentDocuments: _repoList(json['recent_documents'] ?? json['recentDocuments'])
          .map(GeneratedDocument.fromJson)
          .where((entry) => entry.fileId.isNotEmpty || (entry.url ?? '').isNotEmpty)
          .toList(growable: false),
      payloadPreview: _repoMap(json['payload_preview'] ?? json['payloadPreview']),
    );
  }

  final List<DocumentBatchOption> batches;
  final DocumentBatchOption? defaultBatch;
  final List<PrintTemplateOption> templates;
  final List<GeneratedDocument> recentDocuments;
  final Map<String, dynamic> payloadPreview;
}

class DocumentBatchOption {
  const DocumentBatchOption({
    required this.id,
    required this.code,
    required this.name,
    required this.outputFilename,
    required this.isDefault,
    required this.compatible,
    required this.items,
    this.compatibilityError,
  });

  factory DocumentBatchOption.fromJson(Map<String, dynamic> json) {
    return DocumentBatchOption(
      id: _repoString(json['id']),
      code: _repoString(json['code']),
      name: _repoString(json['name'] ?? json['code']),
      outputFilename: _repoString(json['batch_output_filename'] ?? json['batchOutputFilename']),
      isDefault: _repoBool(json['is_default'] ?? json['isDefault']),
      compatible: _repoBool(json['compatible'], fallback: true),
      compatibilityError: _repoNullableString(json['compatibility_error'] ?? json['compatibilityError']),
      items: _repoList(json['items']).map(DocumentBatchItemOption.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String code;
  final String name;
  final String outputFilename;
  final bool isDefault;
  final bool compatible;
  final String? compatibilityError;
  final List<DocumentBatchItemOption> items;

  List<String> get documentTemplateIds => items
      .map((entry) => entry.documentTemplate?.id ?? '')
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  String get displayName => isDefault ? '$name · Default' : name;
}

class DocumentBatchItemOption {
  const DocumentBatchItemOption({
    required this.id,
    required this.batchOrder,
    required this.itemTypeCode,
    this.mediaFileId,
    this.mediaFilename,
    this.mediaMimeType,
    this.documentTemplate,
  });

  factory DocumentBatchItemOption.fromJson(Map<String, dynamic> json) {
    final templateJson = _repoMap(
      json['document_template'] ?? json['documentTemplate'],
    );
    return DocumentBatchItemOption(
      id: _repoString(json['id']),
      batchOrder: _repoIntOrNull(json['batch_order'] ?? json['batchOrder']) ?? 100,
      itemTypeCode: _repoString(
        json['item_type_code'] ?? json['itemTypeCode'] ?? 'document_template',
      ),
      mediaFileId: _repoNullableString(
        json['media_file_id'] ?? json['mediaFileId'],
      ),
      mediaFilename: _repoNullableString(
        json['media_filename'] ?? json['mediaFilename'],
      ),
      mediaMimeType: _repoNullableString(
        json['media_mime_type'] ?? json['mediaMimeType'],
      ),
      documentTemplate:
          templateJson.isEmpty ? null : PrintTemplateOption.fromJson(templateJson),
    );
  }

  final String id;
  final int batchOrder;
  final String itemTypeCode;
  final String? mediaFileId;
  final String? mediaFilename;
  final String? mediaMimeType;
  final PrintTemplateOption? documentTemplate;
}

class PrintTemplateOption {
  const PrintTemplateOption({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    required this.settingsJson,
    this.documentTypeCode,
    this.sourceAssetFileId,
  });

  factory PrintTemplateOption.fromJson(Map<String, dynamic> json) {
    return PrintTemplateOption(
      id: _repoString(json['id']),
      code: _repoString(json['code']),
      name: _repoString(json['name'] ?? json['code']),
      version: _repoIntOrNull(json['version']) ?? 1,
      documentTypeCode: _repoNullableString(json['document_type_code'] ?? json['documentTypeCode']),
      sourceAssetFileId: _repoNullableString(json['source_asset_file_id'] ?? json['sourceAssetFileId']),
      settingsJson: _repoMap(json['settings_json'] ?? json['settingsJson']),
    );
  }

  final String id;
  final String code;
  final String name;
  final int version;
  final String? documentTypeCode;
  final String? sourceAssetFileId;
  final Map<String, dynamic> settingsJson;

  Map<String, dynamic> get printSettings => _repoMap(settingsJson['print']);

  bool get isPrintEnabled {
    final value = printSettings['enabled'];
    if (value is bool) return value;
    if (value is String) return ['true', '1', 'yes', 'y'].contains(value.trim().toLowerCase());
    return false;
  }

  String get payloadSchemaCode => _repoString(
        printSettings['payloadSchemaCode'] ?? printSettings['payload_schema_code'] ?? 'calculation.v1',
      );

  String get documentTypeLabel {
    final configured = _repoNullableString(printSettings['documentTypeLabel'] ?? printSettings['document_type_label']);
    return configured ?? documentTypeCode ?? 'document';
  }

  String get displayName {
    final schemaSuffix = payloadSchemaCode.isEmpty ? '' : ' · $payloadSchemaCode';
    return '$documentTypeLabel · $name v$version$schemaSuffix';
  }
}

class GeneratedDocument {
  const GeneratedDocument({
    required this.id,
    required this.fileId,
    required this.filename,
    this.documentTypeCode,
    this.documentTemplateId,
    this.createdAt,
    this.createdByUserId,
    this.createdByName,
    this.createdByEmail,
    this.url,
    this.expiresSeconds,
  });

  factory GeneratedDocument.fromJson(Map<String, dynamic> json) {
    final wrappedDocument = _repoMap(json['document']);
    final document = wrappedDocument.isEmpty ? json : wrappedDocument;
    final file = _repoMap(json['file']);
    return GeneratedDocument(
      id: _repoString(document['id'] ?? json['id']),
      fileId: _repoString(document['file_id'] ?? document['asset_file_id'] ?? file['id'] ?? json['file_id']),
      filename: _repoString(
        file['original_filename']
            ?? document['output_filename']
            ?? document['original_filename']
            ?? json['filename']
            ?? 'document.pdf',
      ),
      documentTypeCode: _repoNullableString(document['document_type_code'] ?? json['document_type_code']),
      documentTemplateId: _repoNullableString(document['document_template_id'] ?? document['template_id'] ?? json['document_template_id']),
      createdAt: _repoNullableString(document['created_at'] ?? json['created_at']),
      createdByUserId: _repoNullableString(document['created_by'] ?? json['created_by']),
      createdByName: _repoNullableString(document['created_by_name'] ?? json['created_by_name']),
      createdByEmail: _repoNullableString(document['created_by_email'] ?? json['created_by_email']),
      url: _repoNullableString(json['file_url'] ?? json['url']),
      expiresSeconds: _repoIntOrNull(json['expires_seconds']),
    );
  }

  final String id;
  final String fileId;
  final String filename;
  final String? documentTypeCode;
  final String? documentTemplateId;
  final String? createdAt;
  final String? createdByUserId;
  final String? createdByName;
  final String? createdByEmail;
  final String? url;
  final int? expiresSeconds;

  String? get printedByLabel => createdByName ?? createdByEmail;
}

List<Map<String, dynamic>> _repoList(Object? value) {
  if (value is List) {
    return value.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> _repoMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _repoString(Object? value) => value == null ? '' : '$value';

String? _repoNullableString(Object? value) {
  final text = _repoString(value).trim();
  return text.isEmpty ? null : text;
}

int? _repoIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _repoBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
    if (['false', '0', 'no', 'n'].contains(normalized)) return false;
  }
  return fallback;
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}

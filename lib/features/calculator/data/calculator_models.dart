import 'dart:convert';

class CalculatorContext {
  const CalculatorContext({
    required this.organizations,
    required this.productFamilies,
    required this.templates,
    required this.references,
    required this.priceModes,
    required this.defaultSteps,
  });

  factory CalculatorContext.fromJson(Map<String, dynamic> json) {
    return CalculatorContext(
      organizations: _list(json['organizations']).map(CalculatorOption.fromJson).toList(),
      productFamilies: _list(json['productFamilies']).map(CalculatorOption.fromJson).toList(),
      templates: _list(json['templates']).map(CalculatorTemplateOption.fromJson).toList(),
      references: _references(json['references']),
      priceModes: _list(json['priceModes']).map(CalculatorOption.fromJson).toList(),
      defaultSteps: (json['defaultSteps'] as List? ?? const [])
          .map((entry) => '$entry')
          .toList(),
    );
  }

  final List<CalculatorOption> organizations;
  final List<CalculatorOption> productFamilies;
  final List<CalculatorTemplateOption> templates;
  final Map<String, List<CalculatorOption>> references;
  final List<CalculatorOption> priceModes;
  final List<String> defaultSteps;
}

class CalculatorOption {
  const CalculatorOption({
    required this.id,
    required this.code,
    required this.label,
    this.raw = const {},
  });

  factory CalculatorOption.fromJson(Map<String, dynamic> json) {
    return CalculatorOption(
      id: _string(json['id'] ?? json['code']),
      code: _string(json['code'] ?? json['id']),
      label: _string(json['label'] ?? json['name'] ?? json['display_name'] ?? json['legal_name'] ?? json['code'] ?? json['id']),
      raw: json,
    );
  }

  final String id;
  final String code;
  final String label;
  final Map<String, dynamic> raw;
}

class CalculatorTemplateOption {
  const CalculatorTemplateOption({
    required this.id,
    required this.code,
    required this.name,
    required this.productFamilyId,
    required this.productFamilyCode,
    required this.productFamilyName,
    this.defaultValues = const {},
    this.uiSchema = const {},
  });

  factory CalculatorTemplateOption.fromJson(Map<String, dynamic> json) {
    return CalculatorTemplateOption(
      id: _string(json['id']),
      code: _string(json['code']),
      name: _string(json['name']),
      productFamilyId: _string(json['product_family_id']),
      productFamilyCode: _string(json['product_family_code']),
      productFamilyName: _string(json['product_family_name']),
      defaultValues: _map(json['default_values_json']),
      uiSchema: _map(json['ui_schema_json']),
    );
  }

  final String id;
  final String code;
  final String name;
  final String productFamilyId;
  final String productFamilyCode;
  final String productFamilyName;
  final Map<String, dynamic> defaultValues;
  final Map<String, dynamic> uiSchema;
}

class CalculatorDraft {
  const CalculatorDraft({
    this.organizationId,
    this.productFamilyId,
    this.templateId,
    this.priceMode = 'dealer_sales',
    this.modelCode,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.coveringCode,
    this.colorCode,
    this.handoverTypeCode,
    this.options = const [],
  });

  factory CalculatorDraft.fromCalculationJson(Map<String, dynamic> json, {String? productFamilyId}) {
    final dimensions = _map(json['dimensions']);
    final options = json['options'] is List
        ? (json['options'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSelectedOption.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <CalculatorSelectedOption>[];

    return CalculatorDraft(
      organizationId: _nullableString(json['organization_id']),
      productFamilyId: productFamilyId,
      templateId: _nullableString(json['template_id']),
      priceMode: _string(json['price_mode']).isEmpty ? 'dealer_sales' : _string(json['price_mode']),
      modelCode: _nullableString(json['model_code']),
      widthMm: _intOrNull(dimensions['width_mm']),
      depthMm: _intOrNull(dimensions['depth_mm']),
      heightMm: _intOrNull(dimensions['height_mm']),
      coveringCode: _nullableString(json['covering_code']),
      colorCode: _nullableString(json['color_code']),
      handoverTypeCode: _nullableString(json['handover_type_code']),
      options: options,
    );
  }

  final String? organizationId;
  final String? productFamilyId;
  final String? templateId;
  final String priceMode;
  final String? modelCode;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final String? coveringCode;
  final String? colorCode;
  final String? handoverTypeCode;
  final List<CalculatorSelectedOption> options;

  CalculatorDraft copyWith({
    String? organizationId,
    bool clearOrganization = false,
    String? productFamilyId,
    bool clearProductFamily = false,
    String? templateId,
    bool clearTemplate = false,
    String? priceMode,
    String? modelCode,
    bool clearModel = false,
    int? widthMm,
    bool clearWidth = false,
    int? depthMm,
    bool clearDepth = false,
    int? heightMm,
    bool clearHeight = false,
    String? coveringCode,
    bool clearCovering = false,
    String? colorCode,
    bool clearColor = false,
    String? handoverTypeCode,
    bool clearHandover = false,
    List<CalculatorSelectedOption>? options,
  }) {
    return CalculatorDraft(
      organizationId: clearOrganization ? null : organizationId ?? this.organizationId,
      productFamilyId: clearProductFamily ? null : productFamilyId ?? this.productFamilyId,
      templateId: clearTemplate ? null : templateId ?? this.templateId,
      priceMode: priceMode ?? this.priceMode,
      modelCode: clearModel ? null : modelCode ?? this.modelCode,
      widthMm: clearWidth ? null : widthMm ?? this.widthMm,
      depthMm: clearDepth ? null : depthMm ?? this.depthMm,
      heightMm: clearHeight ? null : heightMm ?? this.heightMm,
      coveringCode: clearCovering ? null : coveringCode ?? this.coveringCode,
      colorCode: clearColor ? null : colorCode ?? this.colorCode,
      handoverTypeCode: clearHandover ? null : handoverTypeCode ?? this.handoverTypeCode,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toCalculationJson() {
    return {
      if (organizationId != null && organizationId!.isNotEmpty) 'organization_id': organizationId,
      if (templateId != null && templateId!.isNotEmpty) 'template_id': templateId,
      'price_mode': priceMode,
      if (modelCode != null && modelCode!.isNotEmpty) 'model_code': modelCode,
      'dimensions': {
        if (widthMm != null) 'width_mm': widthMm,
        if (depthMm != null) 'depth_mm': depthMm,
        if (heightMm != null) 'height_mm': heightMm,
      },
      if (coveringCode != null && coveringCode!.isNotEmpty) 'covering_code': coveringCode,
      if (colorCode != null && colorCode!.isNotEmpty) 'color_code': colorCode,
      if (handoverTypeCode != null && handoverTypeCode!.isNotEmpty) 'handover_type_code': handoverTypeCode,
      'options': options.map((entry) => entry.toJson()).toList(),
      'language_code': 'de',
    };
  }

  bool differsFromLoadedQuote(LoadedQuote quote) {
    return _stableJson(toCalculationJson()) != _stableJson(quote.normalizedInput);
  }

  bool hasSameBuyerAndShipToAs(LoadedQuote quote) {
    final currentBuyer = organizationId ?? '';
    return (quote.buyerOrganizationId ?? '') == currentBuyer &&
        (quote.shipToOrganizationId ?? '') == currentBuyer;
  }

  bool canSaveAsOptionFor(LoadedQuote? quote) {
    if (quote == null) return false;
    return differsFromLoadedQuote(quote) && hasSameBuyerAndShipToAs(quote);
  }
}

class CalculatorSelectedOption {
  const CalculatorSelectedOption({
    this.optionCode,
    this.catalogItemId,
    this.catalogVariantId,
    this.quantity = 1,
  });

  factory CalculatorSelectedOption.fromJson(Map<String, dynamic> json) {
    return CalculatorSelectedOption(
      optionCode: _nullableString(json['option_code']),
      catalogItemId: _nullableString(json['catalog_item_id']),
      catalogVariantId: _nullableString(json['catalog_variant_id']),
      quantity: json['quantity'] is num ? json['quantity'] as num : num.tryParse('${json['quantity']}') ?? 1,
    );
  }

  final String? optionCode;
  final String? catalogItemId;
  final String? catalogVariantId;
  final num quantity;

  Map<String, dynamic> toJson() {
    return {
      if (optionCode != null && optionCode!.isNotEmpty) 'option_code': optionCode,
      if (catalogItemId != null && catalogItemId!.isNotEmpty) 'catalog_item_id': catalogItemId,
      if (catalogVariantId != null && catalogVariantId!.isNotEmpty) 'catalog_variant_id': catalogVariantId,
      'quantity': quantity,
    };
  }
}

class CalculatorResult {
  const CalculatorResult({
    required this.status,
    required this.currency,
    required this.price,
    required this.visibleLines,
    required this.summary,
    required this.warnings,
    required this.internalPrice,
    required this.sources,
    required this.bom,
    required this.trace,
    required this.raw,
  });

  factory CalculatorResult.fromJson(Map<String, dynamic> json) {
    return CalculatorResult(
      status: _string(json['status']),
      currency: _string(json['currency']),
      price: _map(json['price']),
      visibleLines: _list(json['visibleLines']),
      summary: _list(json['summary']),
      warnings: _list(json['warnings']),
      internalPrice: _map(json['internalPrice']),
      sources: _map(json['sources']),
      bom: _list(json['bom']),
      trace: _list(json['trace']),
      raw: json,
    );
  }

  final String status;
  final String currency;
  final Map<String, dynamic> price;
  final List<Map<String, dynamic>> visibleLines;
  final List<Map<String, dynamic>> summary;
  final List<Map<String, dynamic>> warnings;
  final Map<String, dynamic> internalPrice;
  final Map<String, dynamic> sources;
  final List<Map<String, dynamic>> bom;
  final List<Map<String, dynamic>> trace;
  final Map<String, dynamic> raw;
}

class SavedQuote {
  const SavedQuote({
    required this.id,
    required this.quoteNo,
    required this.statusCode,
    this.createdAt,
  });

  factory SavedQuote.fromJson(Map<String, dynamic> json) {
    return SavedQuote(
      id: _string(json['id']),
      quoteNo: _string(json['quote_no'] ?? json['quoteNo']),
      statusCode: _string(json['status_code'] ?? json['statusCode']),
      createdAt: json['created_at'] == null ? null : _string(json['created_at']),
    );
  }

  final String id;
  final String quoteNo;
  final String statusCode;
  final String? createdAt;
}

class LoadedQuote {
  const LoadedQuote({
    required this.id,
    required this.quoteNo,
    required this.statusCode,
    required this.input,
    this.productFamilyId,
    this.resultJson,
    this.sellerOrganizationId,
    this.buyerOrganizationId,
    this.shipToOrganizationId,
  });

  factory LoadedQuote.fromJson(Map<String, dynamic> json) {
    final quote = _map(json['quote']);
    return LoadedQuote(
      id: _string(quote['id'] ?? json['id']),
      quoteNo: _string(quote['quote_no'] ?? quote['quoteNo'] ?? json['quote_no'] ?? json['quoteNo']),
      statusCode: _string(quote['status_code'] ?? quote['statusCode'] ?? json['status_code'] ?? json['statusCode']),
      input: _map(json['input'] ?? quote['input_json']),
      productFamilyId: _nullableString(quote['product_family_id'] ?? json['product_family_id']),
      resultJson: (json['result'] ?? quote['result_json']) is Map
          ? Map<String, dynamic>.from(json['result'] ?? quote['result_json'])
          : null,
      sellerOrganizationId: _nullableString(quote['seller_organization_id'] ?? json['seller_organization_id']),
      buyerOrganizationId: _nullableString(quote['buyer_organization_id'] ?? json['buyer_organization_id']),
      shipToOrganizationId: _nullableString(quote['ship_to_organization_id'] ?? json['ship_to_organization_id']),
    );
  }

  final String id;
  final String quoteNo;
  final String statusCode;
  final Map<String, dynamic> input;
  final String? productFamilyId;
  final Map<String, dynamic>? resultJson;
  final String? sellerOrganizationId;
  final String? buyerOrganizationId;
  final String? shipToOrganizationId;

  Map<String, dynamic> get normalizedInput => CalculatorDraft.fromCalculationJson(
        input,
        productFamilyId: productFamilyId,
      ).toCalculationJson();
}

enum SaveQuoteMode {
  asNew,
  asOption;

  String get apiValue {
    switch (this) {
      case SaveQuoteMode.asNew:
        return 'new';
      case SaveQuoteMode.asOption:
        return 'option';
    }
  }

  String get label {
    switch (this) {
      case SaveQuoteMode.asNew:
        return 'As New';
      case SaveQuoteMode.asOption:
        return 'As Option';
    }
  }
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
  }
  return const [];
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Map<String, List<CalculatorOption>> _references(dynamic value) {
  final map = _map(value);
  return map.map((key, entries) {
    final options = entries is List
        ? entries.whereType<Map>().map((entry) => CalculatorOption.fromJson(Map<String, dynamic>.from(entry))).toList()
        : <CalculatorOption>[];
    return MapEntry(key, options);
  });
}

String _string(dynamic value) => value == null ? '' : '$value';

String? _nullableString(dynamic value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

String _stableJson(dynamic value) {
  return jsonEncode(_stableValue(value));
}

dynamic _stableValue(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((entry) => '$entry').toList()..sort();
    return {
      for (final key in keys)
        if (value[key] != null) key: _stableValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(_stableValue).toList();
  }
  return value;
}

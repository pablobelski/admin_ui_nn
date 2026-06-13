import 'dart:convert';

class CalculatorContext {
  const CalculatorContext({
    required this.organizations,
    required this.productFamilies,
    required this.templates,
    required this.references,
    required this.priceModes,
    required this.defaultSteps,
    required this.optionItemTypes,
    required this.optionCatalogItems,
    required this.optionCatalogVariants,
    required this.additionalHandlingByParentItemId,
    this.customPaintCatalogItem,
  });

  factory CalculatorContext.fromJson(Map<String, dynamic> json) {
    final customPaintCatalogItem = json['customPaintCatalogItem'] is Map
        ? CalculatorCatalogItemOption.fromJson(Map<String, dynamic>.from(json['customPaintCatalogItem'] as Map))
        : null;
    final optionCatalogItems = _list(json['optionCatalogItems'])
        .map(CalculatorCatalogItemOption.fromJson)
        .toList();
    if (customPaintCatalogItem != null
        && !optionCatalogItems.any((item) => item.id == customPaintCatalogItem.id)) {
      optionCatalogItems.add(customPaintCatalogItem);
    }

    return CalculatorContext(
      organizations: _list(json['organizations']).map(CalculatorOption.fromJson).toList(),
      productFamilies: _list(json['productFamilies']).map(CalculatorOption.fromJson).toList(),
      templates: _list(json['templates']).map(CalculatorTemplateOption.fromJson).toList(),
      references: _references(json['references']),
      priceModes: _list(json['priceModes']).map(CalculatorOption.fromJson).toList(),
      defaultSteps: (json['defaultSteps'] as List? ?? const [])
          .map((entry) => '$entry')
          .toList(),
      optionItemTypes: _list(json['optionItemTypes']).map(CalculatorOption.fromJson).toList(),
      optionCatalogItems: optionCatalogItems,
      optionCatalogVariants: _list(json['optionCatalogVariants']).map(CalculatorCatalogVariantOption.fromJson).toList(),
      additionalHandlingByParentItemId: _additionalHandlingMap(json['additionalHandlingByParentItemId']),
      customPaintCatalogItem: customPaintCatalogItem,
    );
  }

  final List<CalculatorOption> organizations;
  final List<CalculatorOption> productFamilies;
  final List<CalculatorTemplateOption> templates;
  final Map<String, List<CalculatorOption>> references;
  final List<CalculatorOption> priceModes;
  final List<String> defaultSteps;
  final List<CalculatorOption> optionItemTypes;
  final List<CalculatorCatalogItemOption> optionCatalogItems;
  final List<CalculatorCatalogVariantOption> optionCatalogVariants;
  final Map<String, List<CalculatorAdditionalHandlingOption>> additionalHandlingByParentItemId;
  final CalculatorCatalogItemOption? customPaintCatalogItem;
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

class CalculatorCatalogItemOption {
  const CalculatorCatalogItemOption({
    required this.id,
    required this.itemTypeCode,
    required this.baseCode,
    required this.name,
    this.profileNo,
    this.shortName,
    this.measureTypeCode,
    this.packageUnitCode,
    this.packageContentQty,
    this.packageContentUnitCode,
    this.defaultSalesUnitCode,
    this.allowedSalesUnitCodes = const [],
    this.saleRoundingCode,
    this.priceBasisUnitCode,
    this.defaultLengthMm,
    this.defaultColorCode,
    this.raw = const {},
  });

  factory CalculatorCatalogItemOption.fromJson(Map<String, dynamic> json) {
    return CalculatorCatalogItemOption(
      id: _string(json['id']),
      itemTypeCode: _string(json['item_type_code']),
      baseCode: _string(json['base_code']),
      name: _string(json['name']),
      profileNo: _nullableString(json['profile_no']),
      shortName: _nullableString(json['short_name']),
      measureTypeCode: _nullableString(json['measure_type_code']),
      packageUnitCode: _nullableString(json['package_unit_code']),
      packageContentQty: _numOrNull(json['package_content_qty']),
      packageContentUnitCode: _nullableString(json['package_content_unit_code']),
      defaultSalesUnitCode: _nullableString(json['default_sales_unit_code']),
      allowedSalesUnitCodes: _stringList(json['allowed_sales_unit_codes']),
      saleRoundingCode: _nullableString(json['sale_rounding_code']),
      priceBasisUnitCode: _nullableString(json['price_basis_unit_code']),
      defaultLengthMm: _lengthOrNull(json['default_length_mm']),
      defaultColorCode: _nullableString(json['default_color_code']),
      raw: json,
    );
  }

  final String id;
  final String itemTypeCode;
  final String baseCode;
  final String name;
  final String? profileNo;
  final String? shortName;
  final String? measureTypeCode;
  final String? packageUnitCode;
  final num? packageContentQty;
  final String? packageContentUnitCode;
  final String? defaultSalesUnitCode;
  final List<String> allowedSalesUnitCodes;
  final String? saleRoundingCode;
  final String? priceBasisUnitCode;
  final int? defaultLengthMm;
  final String? defaultColorCode;
  final Map<String, dynamic> raw;

  String get displayName {
    final code = baseCode.isEmpty ? null : baseCode;
    return [code, name].whereType<String>().where((entry) => entry.isNotEmpty).join(' · ');
  }
}

class CalculatorCatalogVariantOption {
  const CalculatorCatalogVariantOption({
    required this.id,
    required this.catalogItemId,
    required this.variantSku,
    this.articleNo,
    this.profileNo,
    this.colorCode,
    this.colorName,
    this.lengthMm,
    this.glassTypeCode,
    this.coatingTypeCode,
    this.systemCode,
    this.systemName,
    this.packageUnitCode,
    this.packageContentQty,
    this.packageContentUnitCode,
    this.defaultSalesUnitCode,
    this.allowedSalesUnitCodes = const [],
    this.saleRoundingCode,
    this.priceBasisUnitCode,
    this.imageFileId,
    this.raw = const {},
  });

  factory CalculatorCatalogVariantOption.fromJson(Map<String, dynamic> json) {
    return CalculatorCatalogVariantOption(
      id: _string(json['id']),
      catalogItemId: _string(json['catalog_item_id']),
      variantSku: _string(json['variant_sku']),
      articleNo: _nullableString(json['article_no']),
      profileNo: _nullableString(json['profile_no']),
      colorCode: _nullableString(json['color_code']),
      colorName: _nullableString(json['color_name']),
      lengthMm: _lengthOrNull(json['length_mm'] ?? json['default_length_mm']),
      glassTypeCode: _nullableString(json['glass_type_code']),
      coatingTypeCode: _nullableString(json['coating_type_code']),
      systemCode: _nullableString(json['system_code']),
      systemName: _nullableString(json['system_name']),
      packageUnitCode: _nullableString(json['package_unit_code']),
      packageContentQty: _numOrNull(json['package_content_qty']),
      packageContentUnitCode: _nullableString(json['package_content_unit_code']),
      defaultSalesUnitCode: _nullableString(json['default_sales_unit_code']),
      allowedSalesUnitCodes: _stringList(json['allowed_sales_unit_codes']),
      saleRoundingCode: _nullableString(json['sale_rounding_code']),
      priceBasisUnitCode: _nullableString(json['price_basis_unit_code']),
      imageFileId: _nullableString(json['image_file_id']),
      raw: json,
    );
  }

  final String id;
  final String catalogItemId;
  final String variantSku;
  final String? articleNo;
  final String? profileNo;
  final String? colorCode;
  final String? colorName;
  final int? lengthMm;
  final String? glassTypeCode;
  final String? coatingTypeCode;
  final String? systemCode;
  final String? systemName;
  final String? packageUnitCode;
  final num? packageContentQty;
  final String? packageContentUnitCode;
  final String? defaultSalesUnitCode;
  final List<String> allowedSalesUnitCodes;
  final String? saleRoundingCode;
  final String? priceBasisUnitCode;
  final String? imageFileId;
  final Map<String, dynamic> raw;

  String get displayName {
    final parts = [
      if (profileNo != null && profileNo!.isNotEmpty) profileNo,
      if (variantSku.isNotEmpty) variantSku,
      if (articleNo != null && articleNo!.isNotEmpty) articleNo,
      if (colorName != null && colorName!.isNotEmpty) colorName,
      if (lengthMm != null) '$lengthMm mm',
    ];
    return parts.join(' · ');
  }
}


class CalculatorAdditionalHandlingOption {
  const CalculatorAdditionalHandlingOption({
    required this.parentCatalogItemId,
    required this.catalogItemId,
    required this.name,
    this.itemTypeCode,
    this.baseCode,
    this.profileNo,
    this.unitCode,
    this.maxQuantity = 1,
    this.unitPrice,
    this.sortOrder = 100,
    this.raw = const {},
  });

  factory CalculatorAdditionalHandlingOption.fromJson(Map<String, dynamic> json) {
    return CalculatorAdditionalHandlingOption(
      parentCatalogItemId: _string(json['parent_catalog_item_id']),
      catalogItemId: _string(json['catalog_item_id']),
      itemTypeCode: _nullableString(json['item_type_code']),
      baseCode: _nullableString(json['base_code']),
      profileNo: _nullableString(json['profile_no']),
      name: _string(json['name']),
      unitCode: _nullableString(json['unit_code']),
      maxQuantity: _numOrDefault(json['max_quantity'], 1),
      unitPrice: _numOrNull(json['unit_price']),
      sortOrder: _intOrNull(json['sort_order']) ?? 100,
      raw: json,
    );
  }

  final String parentCatalogItemId;
  final String catalogItemId;
  final String? itemTypeCode;
  final String? baseCode;
  final String? profileNo;
  final String name;
  final String? unitCode;
  final num maxQuantity;
  final num? unitPrice;
  final int sortOrder;
  final Map<String, dynamic> raw;

  String get displayName {
    final parts = [
      if (baseCode != null && baseCode!.isNotEmpty) baseCode,
      if (profileNo != null && profileNo!.isNotEmpty) profileNo,
      if (name.isNotEmpty) name,
    ];
    return parts.whereType<String>().join(' · ');
  }
}

class CalculatorSelectedAdditionalHandling {
  const CalculatorSelectedAdditionalHandling({
    required this.catalogItemId,
    required this.quantity,
  });

  factory CalculatorSelectedAdditionalHandling.fromJson(Map<String, dynamic> json) {
    return CalculatorSelectedAdditionalHandling(
      catalogItemId: _string(json['catalog_item_id']),
      quantity: _numOrDefault(json['quantity'], 0),
    );
  }

  final String catalogItemId;
  final num quantity;

  Map<String, dynamic> toJson() {
    return {
      'catalog_item_id': catalogItemId,
      'quantity': quantity,
    };
  }
}


class CalculatorSetContentsPreview {
  const CalculatorSetContentsPreview({
    required this.tabs,
    required this.source,
    required this.trace,
    required this.warnings,
    required this.raw,
  });

  factory CalculatorSetContentsPreview.fromJson(Map<String, dynamic> json) {
    return CalculatorSetContentsPreview(
      tabs: _list(json['tabs']).map(CalculatorSetContentTab.fromJson).toList(),
      source: _map(json['source']),
      trace: _list(json['trace']),
      warnings: _list(json['warnings']),
      raw: json,
    );
  }

  final List<CalculatorSetContentTab> tabs;
  final Map<String, dynamic> source;
  final List<Map<String, dynamic>> trace;
  final List<Map<String, dynamic>> warnings;
  final Map<String, dynamic> raw;
}

class CalculatorSetContentTab {
  const CalculatorSetContentTab({
    required this.id,
    required this.label,
    required this.items,
    this.geometryKey = const {},
  });

  factory CalculatorSetContentTab.fromJson(Map<String, dynamic> json) {
    return CalculatorSetContentTab(
      id: _string(json['id']).isEmpty ? 'part-1' : _string(json['id']),
      label: _string(json['label']).isEmpty ? 'Block 1' : _string(json['label']),
      geometryKey: _map(json['geometry_key']),
      items: _list(json['items']).map(CalculatorSetContentItem.fromJson).toList(),
    );
  }

  final String id;
  final String label;
  final Map<String, dynamic> geometryKey;
  final List<CalculatorSetContentItem> items;

  CalculatorSetContentTab copyWith({
    String? id,
    String? label,
    Map<String, dynamic>? geometryKey,
    List<CalculatorSetContentItem>? items,
  }) {
    return CalculatorSetContentTab(
      id: id ?? this.id,
      label: label ?? this.label,
      geometryKey: geometryKey ?? this.geometryKey,
      items: items ?? this.items,
    );
  }

  CalculatorSetContentTab duplicateAs(int index) {
    return CalculatorSetContentTab(
      id: 'part-$index',
      label: 'Block $index',
      geometryKey: geometryKey,
      items: items.map((entry) => entry.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toCalculationJson() {
    return {
      'id': id,
      'label': label,
      if (geometryKey.isNotEmpty) 'geometry_key': geometryKey,
      'items': items.where((entry) => entry.enabled).map((entry) => entry.toCalculationJson()).toList(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      if (geometryKey.isNotEmpty) 'geometry_key': geometryKey,
      'items': items.map((entry) => entry.toJson()).toList(),
    };
  }
}

class CalculatorSetContentItem {
  const CalculatorSetContentItem({
    required this.catalogItemId,
    this.catalogVariantId,
    this.quantity = 1,
    this.salesUnitCode,
    this.lengthMm,
    this.name,
    this.itemTypeCode,
    this.baseCode,
    this.profileNo,
    this.articleNo,
    this.variantSku,
    this.unitCode,
    this.editableLength = false,
    this.enabled = true,
    this.raw = const {},
  });

  factory CalculatorSetContentItem.fromJson(Map<String, dynamic> json) {
    final itemTypeCode = _nullableString(json['item_type_code']);
    final editable = json['editable_length'] == true || (itemTypeCode ?? '').toLowerCase().contains('profile');
    return CalculatorSetContentItem(
      catalogItemId: _string(json['catalog_item_id']),
      catalogVariantId: _nullableString(json['catalog_variant_id']),
      quantity: _numOrDefault(json['quantity'], 1),
      salesUnitCode: _nullableString(json['sales_unit_code']),
      lengthMm: _intOrNull(json['length_mm']),
      name: _nullableString(json['name']),
      itemTypeCode: itemTypeCode,
      baseCode: _nullableString(json['base_code']),
      profileNo: _nullableString(json['profile_no']),
      articleNo: _nullableString(json['article_no']),
      variantSku: _nullableString(json['variant_sku']),
      unitCode: _nullableString(json['unit_code']),
      editableLength: editable,
      enabled: json['enabled'] != false,
      raw: json,
    );
  }

  final String catalogItemId;
  final String? catalogVariantId;
  final num quantity;
  final String? salesUnitCode;
  final int? lengthMm;
  final String? name;
  final String? itemTypeCode;
  final String? baseCode;
  final String? profileNo;
  final String? articleNo;
  final String? variantSku;
  final String? unitCode;
  final bool editableLength;
  final bool enabled;
  final Map<String, dynamic> raw;

  bool get isProfile => editableLength || (itemTypeCode ?? '').toLowerCase().contains('profile');

  CalculatorSetContentItem copyWith({
    String? catalogItemId,
    bool clearCatalogItem = false,
    String? catalogVariantId,
    bool clearCatalogVariant = false,
    num? quantity,
    String? salesUnitCode,
    bool clearSalesUnit = false,
    int? lengthMm,
    bool clearLength = false,
    String? name,
    String? itemTypeCode,
    String? baseCode,
    String? profileNo,
    String? articleNo,
    String? variantSku,
    String? unitCode,
    bool? editableLength,
    bool? enabled,
    Map<String, dynamic>? raw,
  }) {
    return CalculatorSetContentItem(
      catalogItemId: clearCatalogItem ? '' : catalogItemId ?? this.catalogItemId,
      catalogVariantId: clearCatalogVariant ? null : catalogVariantId ?? this.catalogVariantId,
      quantity: quantity ?? this.quantity,
      salesUnitCode: clearSalesUnit ? null : salesUnitCode ?? this.salesUnitCode,
      lengthMm: clearLength ? null : lengthMm ?? this.lengthMm,
      name: name ?? this.name,
      itemTypeCode: itemTypeCode ?? this.itemTypeCode,
      baseCode: baseCode ?? this.baseCode,
      profileNo: profileNo ?? this.profileNo,
      articleNo: articleNo ?? this.articleNo,
      variantSku: variantSku ?? this.variantSku,
      unitCode: unitCode ?? this.unitCode,
      editableLength: editableLength ?? this.editableLength,
      enabled: enabled ?? this.enabled,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toCalculationJson() {
    return {
      'catalog_item_id': catalogItemId,
      if (catalogVariantId != null && catalogVariantId!.isNotEmpty) 'catalog_variant_id': catalogVariantId,
      'quantity': quantity,
      if (salesUnitCode != null && salesUnitCode!.isNotEmpty) 'sales_unit_code': salesUnitCode,
      if (lengthMm != null && lengthMm! > 0) 'length_mm': lengthMm,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toCalculationJson(),
      if (!enabled) 'enabled': false,
    };
  }
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
    this.setContents = const [],
  });

  factory CalculatorDraft.fromCalculationJson(Map<String, dynamic> json, {String? productFamilyId}) {
    final dimensions = _map(json['dimensions']);
    final options = json['options'] is List
        ? (json['options'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSelectedOption.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <CalculatorSelectedOption>[];
    final setContents = json['set_contents'] is List
        ? (json['set_contents'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSetContentTab.fromJson(Map<String, dynamic>.from(entry)))
            .where((tab) => tab.items.isNotEmpty)
            .toList()
        : <CalculatorSetContentTab>[];

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
      setContents: setContents,
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
  final List<CalculatorSetContentTab> setContents;

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
    List<CalculatorSetContentTab>? setContents,
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
      setContents: setContents ?? this.setContents,
    );
  }

  Map<String, dynamic> toCalculationJson() {
    final activeSetContents = setContents
        .map((entry) => entry.toCalculationJson())
        .where((entry) => (entry['items'] as List).isNotEmpty)
        .toList();

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
      'set_contents': activeSetContents,
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
    this.salesUnitCode,
    this.lengthMm,
    this.schraegCount,
    this.additionalHandlings = const [],
  });

  factory CalculatorSelectedOption.fromJson(Map<String, dynamic> json) {
    return CalculatorSelectedOption(
      optionCode: _nullableString(json['option_code']),
      catalogItemId: _nullableString(json['catalog_item_id']),
      catalogVariantId: _nullableString(json['catalog_variant_id']),
      salesUnitCode: _nullableString(json['sales_unit_code']),
      lengthMm: _intOrNull(json['length_mm']),
      quantity: _numOrDefault(json['quantity'], 1),
      schraegCount: _intOrNull(json['schraeg_count']),
      additionalHandlings: _list(json['additional_handlings'])
          .map(CalculatorSelectedAdditionalHandling.fromJson)
          .where((entry) => entry.catalogItemId.isNotEmpty && entry.quantity > 0)
          .toList(),
    );
  }

  final String? optionCode;
  final String? catalogItemId;
  final String? catalogVariantId;
  final num quantity;
  final String? salesUnitCode;
  final int? lengthMm;
  final int? schraegCount;
  final List<CalculatorSelectedAdditionalHandling> additionalHandlings;


  CalculatorSelectedOption copyWith({
    String? optionCode,
    bool clearOptionCode = false,
    String? catalogItemId,
    bool clearCatalogItem = false,
    String? catalogVariantId,
    bool clearCatalogVariant = false,
    num? quantity,
    String? salesUnitCode,
    bool clearSalesUnit = false,
    int? lengthMm,
    bool clearLength = false,
    int? schraegCount,
    bool clearSchraeg = false,
    List<CalculatorSelectedAdditionalHandling>? additionalHandlings,
  }) {
    return CalculatorSelectedOption(
      optionCode: clearOptionCode ? null : optionCode ?? this.optionCode,
      catalogItemId: clearCatalogItem ? null : catalogItemId ?? this.catalogItemId,
      catalogVariantId: clearCatalogVariant ? null : catalogVariantId ?? this.catalogVariantId,
      quantity: quantity ?? this.quantity,
      salesUnitCode: clearSalesUnit ? null : salesUnitCode ?? this.salesUnitCode,
      lengthMm: clearLength ? null : lengthMm ?? this.lengthMm,
      schraegCount: clearSchraeg ? null : schraegCount ?? this.schraegCount,
      additionalHandlings: additionalHandlings ?? this.additionalHandlings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (optionCode != null && optionCode!.isNotEmpty) 'option_code': optionCode,
      if (catalogItemId != null && catalogItemId!.isNotEmpty) 'catalog_item_id': catalogItemId,
      if (catalogVariantId != null && catalogVariantId!.isNotEmpty) 'catalog_variant_id': catalogVariantId,
      'quantity': quantity,
      if (salesUnitCode != null && salesUnitCode!.isNotEmpty) 'sales_unit_code': salesUnitCode,
      if (lengthMm != null && lengthMm! > 0) 'length_mm': lengthMm,
      if (schraegCount != null && schraegCount! > 0) 'schraeg_count': schraegCount,
      if (additionalHandlings.isNotEmpty)
        'additional_handlings': additionalHandlings.map((entry) => entry.toJson()).toList(),
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
    required this.baseBom,
    required this.optionBom,
    required this.setContentBom,
    required this.optionDiagnostics,
    required this.setContentDiagnostics,
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
      baseBom: _list(json['baseBom'] ?? json['base_bom']),
      optionBom: _list(json['optionBom'] ?? json['option_bom']),
      setContentBom: _list(json['setContentBom'] ?? json['set_content_bom']),
      optionDiagnostics: _list(json['optionDiagnostics'] ?? json['option_diagnostics']),
      setContentDiagnostics: _list(json['setContentDiagnostics'] ?? json['set_content_diagnostics']),
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
  final List<Map<String, dynamic>> baseBom;
  final List<Map<String, dynamic>> optionBom;
  final List<Map<String, dynamic>> setContentBom;
  final List<Map<String, dynamic>> optionDiagnostics;
  final List<Map<String, dynamic>> setContentDiagnostics;
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

Map<String, List<CalculatorAdditionalHandlingOption>> _additionalHandlingMap(dynamic value) {
  final map = _map(value);
  return map.map((parentId, entries) {
    final options = entries is List
        ? entries
            .whereType<Map>()
            .map((entry) => CalculatorAdditionalHandlingOption.fromJson(Map<String, dynamic>.from(entry)))
            .where((entry) => entry.parentCatalogItemId.isNotEmpty && entry.catalogItemId.isNotEmpty)
            .toList()
        : <CalculatorAdditionalHandlingOption>[];
    options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return MapEntry(parentId, options);
  });
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => '$entry'.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split(RegExp(r'[,;|]'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

num _numOrDefault(dynamic value, num fallback) {
  if (value is num) return value;
  return num.tryParse('$value'.replaceAll(',', '.')) ?? fallback;
}

num? _numOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse('$value'.replaceAll(',', '.'));
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

int? _lengthOrNull(dynamic value) {
  final length = _intOrNull(value);
  if (length == null || length <= 1) return null;
  return length;
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

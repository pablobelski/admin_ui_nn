import 'dart:convert';

class CalculatorContext {
  const CalculatorContext({
    required this.organizations,
    required this.relatedCustomers,
    this.headBranding,
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
      relatedCustomers: _list(json['relatedCustomers'] ?? json['related_customers']).map(CalculatorOption.fromJson).toList(),
      headBranding: (json['headBranding'] ?? json['head_branding']) is Map
          ? CalculatorBranding.fromJson(Map<String, dynamic>.from((json['headBranding'] ?? json['head_branding']) as Map))
          : null,
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
  final List<CalculatorOption> relatedCustomers;
  final CalculatorBranding? headBranding;
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

  List<CalculatorOption> relatedCustomersFor(String? parentOrganizationId) {
    if (parentOrganizationId == null || parentOrganizationId.isEmpty) return const [];
    return relatedCustomers
        .where((entry) => '${entry.raw['parent_organization_id'] ?? ''}' == parentOrganizationId)
        .toList(growable: false);
  }
}


class CalculatorBranding {
  const CalculatorBranding({
    this.brandingId,
    this.organizationId,
    this.organizationShortName,
    this.brandName,
    this.logoFileId,
    this.logoFilename,
    this.engravingText,
  });

  factory CalculatorBranding.fromJson(Map<String, dynamic> json) {
    return CalculatorBranding(
      brandingId: _nullableString(json['branding_id'] ?? json['id']),
      organizationId: _nullableString(
        json['organization_id'] ?? json['branding_organization_id'] ?? json['child_organization_id'],
      ),
      organizationShortName: _nullableString(
        json['organization_short_name'] ?? json['short_name'] ?? json['display_name'] ?? json['legal_name'],
      ),
      brandName: _nullableString(json['branding_brand_name'] ?? json['brand_name']),
      logoFileId: _nullableString(json['branding_logo_file_id'] ?? json['logo_file_id']),
      logoFilename: _nullableString(json['branding_logo_filename'] ?? json['logo_filename'] ?? json['logo_original_filename']),
      engravingText: _nullableString(json['branding_engraving_text'] ?? json['engraving_text']),
    );
  }

  final String? brandingId;
  final String? organizationId;
  final String? organizationShortName;
  final String? brandName;
  final String? logoFileId;
  final String? logoFilename;
  final String? engravingText;

  bool get hasLogo => logoFileId != null && logoFileId!.isNotEmpty;

  String get shortLabel {
    final raw = organizationShortName ?? brandName ?? '';
    final value = raw.trim();
    return value.isEmpty ? 'Logo' : value;
  }

  Map<String, dynamic> toCalculationJson({
    required String sourceCode,
    bool engravingEnabled = false,
  }) {
    return {
      'source_code': sourceCode,
      if (brandingId != null && brandingId!.isNotEmpty) 'branding_id': brandingId,
      if (organizationId != null && organizationId!.isNotEmpty) 'organization_id': organizationId,
      if (organizationShortName != null && organizationShortName!.isNotEmpty) 'organization_short_name': organizationShortName,
      if (brandName != null && brandName!.isNotEmpty) 'brand_name': brandName,
      if (logoFileId != null && logoFileId!.isNotEmpty) 'logo_file_id': logoFileId,
      if (logoFilename != null && logoFilename!.isNotEmpty) 'logo_filename': logoFilename,
      if (engravingText != null && engravingText!.isNotEmpty) 'engraving_text': engravingText,
      'engraving_enabled': engravingEnabled,
    };
  }
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
    this.parametersModuleId,
    this.roofParameters = const {},
    this.roofParameterMissingKeys = const [],
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
      parametersModuleId: _nullableString(json['parameters_module_id']),
      roofParameters: _map(json['roof_parameters_json']),
      roofParameterMissingKeys: (json['roof_parameter_missing_keys'] as List? ?? const [])
          .map((entry) => '$entry')
          .where((entry) => entry.trim().isNotEmpty)
          .toList(growable: false),
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
  final String? parametersModuleId;
  final Map<String, dynamic> roofParameters;
  final List<String> roofParameterMissingKeys;

  bool get hasCompleteRoofParameters => parametersModuleId != null && roofParameterMissingKeys.isEmpty && roofParameters.isNotEmpty;

  int? get defaultMaxGlassFieldWidthMm => _intOrNull(
        roofParameters['defaultMaxGlassFieldWidthMm'] ?? roofParameters['default_max_glass_field_width_mm'],
      );
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
    this.mediaFileId,
    this.mediaLargeFileId,
    this.mediaKind,
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
      mediaFileId: _nullableString(json['media_file_id'] ?? json['primary_media_file_id'] ?? json['catalog_media_file_id']),
      mediaLargeFileId: _nullableString(json['media_large_file_id'] ?? json['large_media_file_id']),
      mediaKind: _nullableString(json['media_kind']),
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
  final String? mediaFileId;
  final String? mediaLargeFileId;
  final String? mediaKind;
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
    this.imageLargeFileId,
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
      imageLargeFileId: _nullableString(json['image_large_file_id'] ?? json['large_image_file_id']),
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
  final String? imageLargeFileId;
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
      label: _string(json['label']).isEmpty ? 'Module 1' : _string(json['label']),
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

  int? geometryInt(String key) => _intOrNull(geometryKey[key]);

  String get moduleRole => _nullableString(geometryKey['role']) ?? '';
  int? get moduleWidthMm => geometryInt('width_mm');
  int? get moduleDepthMm => geometryInt('depth_mm');

  // Backward-compatible getters kept for Set contents and older saved quotes.
  int? get blockWidthMm => moduleWidthMm;
  int? get blockDepthMm => moduleDepthMm;
  int? get blockHeightMm => geometryInt('height_mm');

  CalculatorSetContentTab duplicateAs(int index) {
    return CalculatorSetContentTab(
      id: 'part-$index',
      label: 'Module $index',
      geometryKey: geometryKey,
      items: items.map((entry) => entry.copyWith()).toList(),
    );
  }

  CalculatorSetContentTab withGeometryValue(String key, int? value) {
    final nextGeometry = <String, dynamic>{...geometryKey};
    if (value == null || value <= 0) {
      nextGeometry.remove(key);
    } else {
      nextGeometry[key] = value;
    }
    return copyWith(geometryKey: nextGeometry);
  }


  CalculatorSetContentTab withGeometryRole(String role) {
    final normalizedRole = role.trim();
    final nextGeometry = <String, dynamic>{...geometryKey};
    if (normalizedRole.isEmpty) {
      nextGeometry.remove('role');
    } else {
      nextGeometry['role'] = normalizedRole;
    }
    return copyWith(geometryKey: nextGeometry);
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
    final sourceComponent = _map(json['source_component']);
    String? metaString(String snakeKey, [String? camelKey]) {
      return _nullableString(json[snakeKey]) ?? _nullableString(sourceComponent[snakeKey]) ?? (camelKey == null ? null : _nullableString(sourceComponent[camelKey]));
    }

    final itemTypeCode = metaString('item_type_code', 'itemTypeCode');
    final lengthMm = _intOrNull(json['length_mm'] ?? sourceComponent['length_mm'] ?? sourceComponent['lengthMm']);
    final editable = json['editable_length'] == true
        || sourceComponent['editable_length'] == true
        || sourceComponent['editableLength'] == true
        || (itemTypeCode ?? '').toLowerCase().contains('profile')
        || (lengthMm != null && lengthMm > 1);
    return CalculatorSetContentItem(
      catalogItemId: _string(json['catalog_item_id']),
      catalogVariantId: _nullableString(json['catalog_variant_id']),
      quantity: _numOrDefault(json['quantity'], 1),
      salesUnitCode: _nullableString(json['sales_unit_code']),
      lengthMm: lengthMm,
      name: metaString('name') ?? metaString('component_name', 'componentName'),
      itemTypeCode: itemTypeCode,
      baseCode: metaString('base_code', 'baseCode'),
      profileNo: metaString('profile_no', 'profileNo'),
      articleNo: metaString('article_no', 'articleNo'),
      variantSku: metaString('variant_sku', 'variantSku'),
      unitCode: metaString('unit_code', 'unitCode'),
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

  bool get isProfile => editableLength || (itemTypeCode ?? '').toLowerCase().contains('profile') || (lengthMm != null && lengthMm! > 1);

  bool get isAccessory => (itemTypeCode ?? '').toLowerCase().contains('accessory');

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
    final sourceComponent = {
      ..._map(raw['source_component']),
      if (name != null && name!.isNotEmpty) 'name': name,
      if (itemTypeCode != null && itemTypeCode!.isNotEmpty) 'item_type_code': itemTypeCode,
      if (baseCode != null && baseCode!.isNotEmpty) 'base_code': baseCode,
      if (profileNo != null && profileNo!.isNotEmpty) 'profile_no': profileNo,
      if (articleNo != null && articleNo!.isNotEmpty) 'article_no': articleNo,
      if (variantSku != null && variantSku!.isNotEmpty) 'variant_sku': variantSku,
      if (unitCode != null && unitCode!.isNotEmpty) 'unit_code': unitCode,
      if (editableLength) 'editable_length': true,
    };

    return {
      'catalog_item_id': catalogItemId,
      if (catalogVariantId != null && catalogVariantId!.isNotEmpty) 'catalog_variant_id': catalogVariantId,
      'quantity': quantity,
      if (salesUnitCode != null && salesUnitCode!.isNotEmpty) 'sales_unit_code': salesUnitCode,
      if (lengthMm != null && lengthMm! > 0) 'length_mm': lengthMm,
      if (sourceComponent.isNotEmpty) 'source_component': sourceComponent,
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
    this.roofAngleDeg,
    this.roofRearHeightMm,
    this.roofFrontHeightMm,
    this.forceOddBeams = true,
    this.maxGlassFieldWidthMm,
    this.coveringCode,
    this.colorCode,
    this.handoverTypeCode,
    this.quoteNoExternal,
    this.externalNotes,
    this.relatedCustomerId,
    this.branding = const {},
    this.options = const [],
    this.setContents = const [],
  });

  factory CalculatorDraft.fromCalculationJson(Map<String, dynamic> json, {String? productFamilyId}) {
    final dimensions = _map(json['dimensions']);
    final roof = _map(json['roof']);
    final options = json['options'] is List
        ? (json['options'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSelectedOption.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <CalculatorSelectedOption>[];
    final savedSetContents = json['set_contents'] is List
        ? (json['set_contents'] as List)
            .whereType<Map>()
            .map((entry) => CalculatorSetContentTab.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <CalculatorSetContentTab>[];
    final roofModules = _list(roof['modules']);
    final setContents = _restoreRoofModuleGeometry(savedSetContents, roofModules);

    return CalculatorDraft(
      organizationId: _nullableString(json['organization_id']),
      productFamilyId: productFamilyId,
      templateId: _nullableString(json['template_id']),
      priceMode: _string(json['price_mode']).isEmpty ? 'dealer_sales' : _string(json['price_mode']),
      modelCode: _nullableString(json['model_code']),
      widthMm: _intOrNull(dimensions['width_mm']),
      depthMm: _intOrNull(dimensions['depth_mm']),
      heightMm: _intOrNull(dimensions['height_mm']),
      roofAngleDeg: _intOrNull(roof['angle_deg']),
      roofRearHeightMm: _intOrNull(roof['rear_height_mm']),
      roofFrontHeightMm: _intOrNull(roof['front_height_mm']),
      forceOddBeams: roof['force_odd_beams'] is bool ? roof['force_odd_beams'] as bool : true,
      maxGlassFieldWidthMm: _intOrNull(roof['max_glass_field_width_mm']),
      coveringCode: _nullableString(json['covering_code']),
      colorCode: _nullableString(json['color_code']),
      handoverTypeCode: _nullableString(json['handover_type_code']),
      quoteNoExternal: _nullableString(json['quote_no_external'] ?? json['quoteNoExternal']),
      externalNotes: _nullableString(json['external_notes'] ?? json['externalNotes']),
      relatedCustomerId: _nullableString(json['related_customer_id'] ?? json['relatedCustomerId']),
      branding: _map(json['branding']),
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
  final int? roofAngleDeg;
  final int? roofRearHeightMm;
  final int? roofFrontHeightMm;
  final bool forceOddBeams;
  final int? maxGlassFieldWidthMm;
  final String? coveringCode;
  final String? colorCode;
  final String? handoverTypeCode;
  final String? quoteNoExternal;
  final String? externalNotes;
  final String? relatedCustomerId;
  final Map<String, dynamic> branding;
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
    int? roofAngleDeg,
    bool clearRoofAngle = false,
    int? roofRearHeightMm,
    bool clearRoofRearHeight = false,
    int? roofFrontHeightMm,
    bool clearRoofFrontHeight = false,
    bool? forceOddBeams,
    int? maxGlassFieldWidthMm,
    bool clearMaxGlassFieldWidth = false,
    String? coveringCode,
    bool clearCovering = false,
    String? colorCode,
    bool clearColor = false,
    String? handoverTypeCode,
    bool clearHandover = false,
    String? quoteNoExternal,
    bool clearQuoteNoExternal = false,
    String? externalNotes,
    bool clearExternalNotes = false,
    String? relatedCustomerId,
    bool clearRelatedCustomer = false,
    Map<String, dynamic>? branding,
    bool clearBranding = false,
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
      roofAngleDeg: clearRoofAngle ? null : roofAngleDeg ?? this.roofAngleDeg,
      roofRearHeightMm: clearRoofRearHeight ? null : roofRearHeightMm ?? this.roofRearHeightMm,
      roofFrontHeightMm: clearRoofFrontHeight ? null : roofFrontHeightMm ?? this.roofFrontHeightMm,
      forceOddBeams: forceOddBeams ?? this.forceOddBeams,
      maxGlassFieldWidthMm: clearMaxGlassFieldWidth ? null : maxGlassFieldWidthMm ?? this.maxGlassFieldWidthMm,
      coveringCode: clearCovering ? null : coveringCode ?? this.coveringCode,
      colorCode: clearColor ? null : colorCode ?? this.colorCode,
      handoverTypeCode: clearHandover ? null : handoverTypeCode ?? this.handoverTypeCode,
      quoteNoExternal: clearQuoteNoExternal ? null : quoteNoExternal ?? this.quoteNoExternal,
      externalNotes: clearExternalNotes ? null : externalNotes ?? this.externalNotes,
      relatedCustomerId: clearRelatedCustomer ? null : relatedCustomerId ?? this.relatedCustomerId,
      branding: clearBranding ? const {} : branding ?? this.branding,
      options: options ?? this.options,
      setContents: setContents ?? this.setContents,
    );
  }


  Map<String, dynamic> _roofJson() {
    final moduleJson = <Map<String, dynamic>>[];
    for (final tab in setContents) {
      final role = tab.moduleRole.trim();
      final width = tab.moduleWidthMm;
      final depth = tab.moduleDepthMm;
      if (role.isEmpty && width == null && depth == null) continue;
      moduleJson.add({
        'role': role.isEmpty ? 'main' : role,
        if (width != null) 'width_mm': width,
        if (depth != null) 'depth_mm': depth,
        if (coveringCode != null && coveringCode!.isNotEmpty) 'covering_code': coveringCode,
      });
    }

    final hasRoofData = (modelCode != null && modelCode!.isNotEmpty) ||
        roofAngleDeg != null ||
        roofRearHeightMm != null ||
        roofFrontHeightMm != null ||
        moduleJson.isNotEmpty;
    if (!hasRoofData) return const {};

    return {
      if (modelCode != null && modelCode!.isNotEmpty) 'model_code': modelCode,
      if (roofAngleDeg != null) 'angle_deg': roofAngleDeg,
      if (roofRearHeightMm != null) 'rear_height_mm': roofRearHeightMm,
      if (roofFrontHeightMm != null) 'front_height_mm': roofFrontHeightMm,
      'force_odd_beams': forceOddBeams,
      if (maxGlassFieldWidthMm != null) 'max_glass_field_width_mm': maxGlassFieldWidthMm,
      if (moduleJson.isNotEmpty) 'modules': moduleJson,
    };
  }

  Map<String, dynamic> _baseJson({required List<Map<String, dynamic>> setContentsJson}) {
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
      if (_roofJson().isNotEmpty) 'roof': _roofJson(),
      if (coveringCode != null && coveringCode!.isNotEmpty) 'covering_code': coveringCode,
      if (colorCode != null && colorCode!.isNotEmpty) 'color_code': colorCode,
      if (handoverTypeCode != null && handoverTypeCode!.isNotEmpty) 'handover_type_code': handoverTypeCode,
      if (quoteNoExternal != null && quoteNoExternal!.isNotEmpty) 'quote_no_external': quoteNoExternal,
      if (externalNotes != null && externalNotes!.isNotEmpty) 'external_notes': externalNotes,
      if (relatedCustomerId != null && relatedCustomerId!.isNotEmpty) 'related_customer_id': relatedCustomerId,
      if (branding.isNotEmpty) 'branding': branding,
      'options': options.map((entry) => entry.toJson()).toList(),
      'set_contents': setContentsJson,
      'language_code': 'de',
    };
  }

  Map<String, dynamic> toCalculationJson() {
    final activeSetContents = setContents
        .map((entry) => entry.toCalculationJson())
        .where((entry) => (entry['items'] as List).isNotEmpty)
        .toList();

    return _baseJson(setContentsJson: activeSetContents);
  }

  Map<String, dynamic> toWorkspaceJson() {
    return _baseJson(
      setContentsJson: setContents.map((entry) => entry.toJson()).toList(),
    );
  }

  bool differsFromLoadedQuote(LoadedQuote quote) {
    return _stableJson(toWorkspaceJson()) != _stableJson(quote.normalizedInput);
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
    this.quoteNoExternal,
    this.externalNotes,
  });

  factory LoadedQuote.fromJson(Map<String, dynamic> json) {
    final quote = _map(json['quote']);
    final quoteNoExternal = _nullableString(quote['quote_no_external'] ?? json['quote_no_external']);
    final externalNotes = _nullableString(quote['external_notes'] ?? json['external_notes']);
    final input = Map<String, dynamic>.from(_map(json['input'] ?? quote['input_json']));
    if (quoteNoExternal != null && quoteNoExternal.isNotEmpty) input['quote_no_external'] = quoteNoExternal;
    if (externalNotes != null && externalNotes.isNotEmpty) input['external_notes'] = externalNotes;
    return LoadedQuote(
      id: _string(quote['id'] ?? json['id']),
      quoteNo: _string(quote['quote_no'] ?? quote['quoteNo'] ?? json['quote_no'] ?? json['quoteNo']),
      statusCode: _string(quote['status_code'] ?? quote['statusCode'] ?? json['status_code'] ?? json['statusCode']),
      input: input,
      productFamilyId: _nullableString(quote['product_family_id'] ?? json['product_family_id']),
      resultJson: (json['result'] ?? quote['result_json']) is Map
          ? Map<String, dynamic>.from(json['result'] ?? quote['result_json'])
          : null,
      sellerOrganizationId: _nullableString(quote['seller_organization_id'] ?? json['seller_organization_id']),
      buyerOrganizationId: _nullableString(quote['buyer_organization_id'] ?? json['buyer_organization_id']),
      shipToOrganizationId: _nullableString(quote['ship_to_organization_id'] ?? json['ship_to_organization_id']),
      quoteNoExternal: quoteNoExternal,
      externalNotes: externalNotes,
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
  final String? quoteNoExternal;
  final String? externalNotes;

  Map<String, dynamic> get normalizedInput => CalculatorDraft.fromCalculationJson(
        input,
        productFamilyId: productFamilyId,
      ).toWorkspaceJson();
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

List<CalculatorSetContentTab> _restoreRoofModuleGeometry(
  List<CalculatorSetContentTab> savedTabs,
  List<Map<String, dynamic>> roofModules,
) {
  if (roofModules.isEmpty) return savedTabs;

  if (savedTabs.isEmpty) {
    return [
      for (var index = 0; index < roofModules.length; index++)
        CalculatorSetContentTab(
          id: 'part-${index + 1}',
          label: 'Module ${index + 1}',
          geometryKey: _roofModuleGeometry(roofModules[index]),
          items: const [],
        ),
    ];
  }

  return [
    for (var index = 0; index < savedTabs.length; index++)
      if (index < roofModules.length)
        savedTabs[index].copyWith(
          geometryKey: {
            ..._roofModuleGeometry(roofModules[index]),
            ...savedTabs[index].geometryKey,
          },
        )
      else
        savedTabs[index],
  ];
}

Map<String, dynamic> _roofModuleGeometry(Map<String, dynamic> module) {
  final role = _nullableString(module['role']);
  final width = _intOrNull(module['width_mm']);
  final depth = _intOrNull(module['depth_mm']);
  return {
    if (role != null) 'role': role,
    if (width != null && width > 0) 'width_mm': width,
    if (depth != null && depth > 0) 'depth_mm': depth,
  };
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
